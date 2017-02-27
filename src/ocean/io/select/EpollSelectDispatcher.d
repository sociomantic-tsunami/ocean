/*******************************************************************************

    Manages an I/O event loop with automatic handler invocation and
    unregistration.

    The EpollSelectDispatcher class wraps a Tango EpollSelector and uses
    ISelectClient instances for Select I/O event registration, unregistration
    and event handler invocation. An I/O event loop is provided that runs while
    there are select event registrations. This loop automatically invokes the
    registered handlers; via the return value each handler may indicate that it
    wishes to be unregistered. After the ISelectClient instance has been
    unregistered, its finalize() method is invoked.

    If a handler throws an Exception, it is caught, the ISelectClient containing
    that handler is unregistered immediately and finalize() is invoked.
    Exceptions thrown by the ISelectClient's finalize() methods are also caught.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.EpollSelectDispatcher;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.io.select.selector.IEpollSelectDispatcherInfo;
import ocean.io.select.client.model.ISelectClient;

import ocean.io.select.selector.model.ISelectedKeysHandler;

import ocean.io.select.selector.SelectedKeysHandler,
       ocean.io.select.selector.TimeoutSelectedKeysHandler,
       ocean.io.select.selector.EpollException;

import ocean.util.ReusableException;

import ocean.io.select.client.SelectEvent;

import ocean.io.select.selector.RegisteredClients;

import ocean.core.Array : copy;

import ocean.util.container.AppendBuffer;

import ocean.time.timeout.model.ITimeoutManager;

import ocean.sys.Epoll;

import core.stdc.stdlib: bsearch, qsort;

import core.stdc.errno: errno, EINTR, ENOENT, EEXIST, ENOMEM, EINVAL;

debug ( ISelectClient ) import ocean.io.Stdout;

/*******************************************************************************

    EpollSelectDispatcher

*******************************************************************************/

public class EpollSelectDispatcher : IEpollSelectDispatcherInfo
{
    /***************************************************************************

        Event alias used internally

     **************************************************************************/

    alias ISelectClient.Event Event;

    /***************************************************************************

        Set of registered clients.

     **************************************************************************/

    private IRegisteredClients registered_clients;

    /**************************************************************************

         Default maximum number of file descriptors for which events can be
         reported with one epoll_wait() call.

     **************************************************************************/

    public const uint DefaultMaxEvents = 16;

    /**************************************************************************

         true if the timeout feature is enabled.

     **************************************************************************/

    public bool timeout_enabled ( )
    {
        return this._timeout_enabled;
    }

    private bool _timeout_enabled;

    /***************************************************************************

        Wrapped Epoll file handle

     **************************************************************************/

    private Epoll epoll;

    /***************************************************************************

        Reused list of events.

     **************************************************************************/

    private epoll_event_t[] events;

    /***************************************************************************

        Re-usable errno exception

     **************************************************************************/

    private EpollException    e;

    /***************************************************************************

        Optional hook to be called on unhandled exceptions from events

    ***************************************************************************/

    private void delegate (Exception) unhandled_exception_hook;

    /***************************************************************************

        Timeout manager instance; null disables the timeout feature.

     **************************************************************************/

    private ITimeoutManager timeout_manager;

    /***************************************************************************

        Event which is triggered when the shutdown() method is called.

     **************************************************************************/

    private SelectEvent shutdown_event;

    /***************************************************************************

        Flag which the eventLoop checks for exit status. Set to true when the
        shutdown event fires (via calling the shutdown() method).

     **************************************************************************/

    private bool shutdown_triggered;

    /***************************************************************************

        Flag set to true when the eventLoop() method is called, and to false
        when it exits. Used to assert that the event loop is not started from
        within itself.

     **************************************************************************/

    private bool in_event_loop;

    version ( EpollCounters )
    {
        /***********************************************************************

            Struct containing counters to track stats about the selector.

        ***********************************************************************/

        private struct Counters
        {
            ulong selects;
            ulong timeouts;
        }

        private Counters counters;
    }

    /***************************************************************************

        Client handler.

     **************************************************************************/

    private ISelectedKeysHandler handle;

    /***************************************************************************

        Constructor

        Params:
            timeout_manager = timeout manager instance (null disables the
                              timeout feature)
            max_events      = sets the maximum number of events that will be
                              returned in the selection set per call to select.

        Throws:
            EpollException on error obtaining a new epoll instance.

     **************************************************************************/

    public this ( ITimeoutManager timeout_manager = null, uint max_events = DefaultMaxEvents )
    {
        debug ( ISelectClient )
        {
            this.registered_clients = new ClientSet;
        }
        else
        {
            this.registered_clients = new ClientCount;
        }

        this.e = new EpollException;

        this.e.enforce(
            this.epoll.create() >= 0,
            "error creating epoll object",
            "epoll_create"
        );

        this.timeout_manager = timeout_manager;

        this._timeout_enabled = timeout_manager !is null;

        this.shutdown_event = new SelectEvent(&this.shutdownTrigger);

        this.events            = new epoll_event_t[max_events];

        this.handle = this.timeout_enabled?
            new TimeoutSelectedKeysHandler(&this.unregister, this.e, this.timeout_manager, max_events) :
            new SelectedKeysHandler(&this.unregister, this.e);
    }

    /***************************************************************************

        Constructor; disables the timeout feature.

        Params:
            max_events      = sets the maximum number of events that will be
                              returned in the selection set per call to select.

     **************************************************************************/

    public this ( uint max_events )
    {
        this(null, max_events);
    }

    /***************************************************************************

        Destructor.

     **************************************************************************/

    ~this ( )
    {
        with (this.epoll) if (fd >= 0)
        {
            close();
        }
    }

    /***************************************************************************

        Adds or modifies a client registration.

        To change the client of a currently registered conduit when several
        clients share the same conduit, use changeClient().

        Important note: client is stored in a memory location not managed by the
        D runtime memory manager (aka Garbage Collector). Therefore it is
        important that the caller makes sure client is stored somewhere visible
        to the GC (in a class variable, for example) so it won't get garbage
        collected and deleted.

        Params:
            client = client to register, please make sure it is stored somewhere
                     visible to the garbage collector

        Returns:
            true if everything worked as expected or false if the client was
            unexpectedly unregistered as it happens when its file descriptor is
            closed.

        Throws:
            EpollException on error.

     **************************************************************************/

    public bool register ( ISelectClient client )
    {
        try if (client.is_registered)
        {
            scope (failure)
            {
                this.registered_clients -= client;
            }

            return this.modify(client);
        }
        else
        {
            this.e.enforce(
                this.epoll.ctl(epoll.CtlOp.EPOLL_CTL_ADD, client.fileHandle,
                    client.events, client) == 0,
                "error adding epoll registration",
                "epoll_ctl"
            );

            this.registered_clients += client;

            return true;
        }
        catch (Exception e)
        {
            debug ( ISelectClient )
            {
                Stderr.formatln("{} :: Error during register: '{}' @{}:{}",
                    client, getMsg(e), e.file, e.line).flush();
            }
            throw e;
        }
    }

    /***************************************************************************

       Removes a client registration. Does not fail/throw if the client is not
       registered.

       Params:
            client = client to unregister

       Returns:
            0 if everything worked as expected or the error code (errno) as a
            warning on minor errors, that is, everything except ENOMEM (out of
            memory) and EINVAL (invalid epoll file descriptor or epoll_ctl()
            opcode).
            ENOENT is a minor error that happens regularly when the client was
            unexpectedly unregistered as it happens when its file descriptor is
            closed.

        Throws:
            EpollException on the fatal errors ENOMEM and EINVAL.

     **************************************************************************/

    public int unregister ( ISelectClient client )
    {
        try if (client.is_registered)
        {
            scope (success)
            {
                this.registered_clients -= client;
            }

            if (!this.epoll.ctl(epoll.CtlOp.EPOLL_CTL_DEL, client.fileHandle,
                client.events, client))
            {
                return 0;
            }
            else
            {
                int errnum = .errno;

                switch (errnum)
                {
                    default:
                        return errnum;

                    case ENOMEM, EINVAL:
                        throw this.e.set(errnum)
                            .addMessage("error removing epoll client");
                }
            }
        }
        else
        {
            return false;
        }
        catch (Exception e)
        {
            debug ( ISelectClient )
            {
                Stderr.formatln("{} :: Error during unregister: '{}' @{}:{}",
                    client, getMsg(e), e.file, e.line).flush();
            }
            throw e;
        }
    }

    /**************************************************************************

        Changes the clients of a registered conduit from current to next.

        - current and next are expected to share the the same file descriptor
          (conduit file handle),
        - current is expected to be registered while next is expected not to be
          registered. It is tolerated if current is unexpectedly unregistered
          as it happens when its file descriptor is closed.

       Important note: next is stored in a memory location not managed by the
       D runtime memory manager (aka Garbage Collector). Therefore it is
       important that the caller makes sure next is stored somewhere visible
       to the GC (in a class variable, for example) so it won't get garbage
       collected and deleted.

       Params:
            current = currently registered client to be unregistered
            next    = currently unregistered client to be registered, please
                      make sure it is stored somewhere visible to the garbage
                      collector

       Returns:
            true if everything worked as expected or false if current is
            unexpectedly unregistered as it happens when its file descriptor is
            closed.

        Throws:
            EpollException on error.

        In:
            - current and next must have the the same file descriptor,
            - current.is_registered must be true,
            - next.is_registered must be false.

     **************************************************************************/

    public bool changeClient ( ISelectClient current, ISelectClient next )
    in
    {
        debug ( ISelectClient )
        {
            if (current.fileHandle != next.fileHandle)
            {
                Stderr.formatln("Error during changeClient: current.fileHandle != next.fileHandle").flush();
            }

            if (!current.is_registered)
            {
                Stderr.formatln("Error during changeClient: !current.is_registered").flush();
            }

            if (next.is_registered)
            {
                Stderr.formatln("Error during changeClient: next.is_registered").flush();
            }
        }

        assert (current.fileHandle == next.fileHandle,
                typeof (this).stringof ~ ".changeClient: clients are expected to share the same file descriptor");
        assert (current.is_registered,
                typeof (this).stringof ~ ".changeClient: current client is expected to be registered");
        assert (!next.is_registered,
                typeof (this).stringof ~ ".changeClient: next client is expected not to be registered");
    }
    body
    {
        assert (current !is next); // should be impossible since current.is_registered != next.is_registered

        try
        {
            scope (success)
            {
                debug ( ISelectClient )
                {
                    Stderr.formatln("Changed clients for fd:").flush();
                    Stderr.formatln("  Replaced {}", current).flush();
                    Stderr.formatln("  with     {}", next).flush();
                }

                this.registered_clients -= current;
                this.registered_clients += next;
            }

            return this.modify(next);
        }
        catch (Exception e)
        {
            debug ( ISelectClient )
            {
                Stderr.formatln("Error during changeClient: '{}' @{}:{}",
                    getMsg(e), e.file, e.line).flush();
            }
            throw e;
        }
    }

    /**************************************************************************

        IEpollSelectDispatcherInfo interface method.

        Returns:
            the number of clients registered with the select dispatcher

     **************************************************************************/

    public size_t num_registered ( )
    {
        return this.registered_clients.length;
    }

    version ( EpollCounters )
    {
        /***********************************************************************

            Returns:
                the number of select calls (epoll_wait()) since the instance was
                created (or since the ulong counter wrapped)

        ***********************************************************************/

        public ulong selects ( )
        {
            return this.counters.selects;
        }


        /***********************************************************************

            Returns:
                the number of select calls (epoll_wait()) which exited due to a
                timeout (as opposed to a client firing) since the instance was
                created (or since the ulong counter wrapped)

        ***********************************************************************/

        public ulong timeouts ( )
        {
            return this.counters.timeouts;
        }


        /***********************************************************************

            Resets the counters returned by selects() and timeouts().

        ***********************************************************************/

        public void resetCounters ( )
        {
            this.counters = this.counters.init;
        }
    }

    /**************************************************************************

        Modifies the registration of client using EPOLL_CTL_MOD.
        More precisely, the events of the current registration of
        client.fileHandle are set to client.events and the registration
        attachment is set to client.

        If this fails with ENOENT, which means, client.fileHandle turned
        out not to be registered, a new registration of the client is created
        using EPOLL_CTL_ADD. This fallback is intended only to be used when a
        file descriptor is unexpectedly unregistered as it happens when it is
        closed.

        Params:
            client = client to set the conduit registration to

       Returns:
            true if everything worked as expected or false if
            client.fileHandle turned out not to be registered so that
            a new registration was added.

        Throws:
            EpollException on error.

     **************************************************************************/

    public bool modify ( ISelectClient client )
    {
        if (!this.epoll.ctl(epoll.CtlOp.EPOLL_CTL_MOD, client.fileHandle,
            client.events, client))
        {
            return false;
        }
        else
        {
            int errnum = .errno;

            if (errnum == ENOENT)
            {
                if (!this.epoll.ctl(epoll.CtlOp.EPOLL_CTL_ADD, client.fileHandle,
                    client.events, client))
                {
                    return true;
                }
                else
                {
                    throw this.e.useGlobalErrno().addMessage(
                        "error adding epoll registration "
                            ~ "after modification resulted in ENOENT"
                    );
                }
            }
            else
            {
                throw this.e.useGlobalErrno().addMessage(
                    "error modifying epoll registration");
            }
        }
    }

    /**************************************************************************

        Sets a timeout manager expiry registration to client if the timeout
        feature is enabled. This must be done exactly once for each select
        client that should be able to time out.
        If the timeout feature is disabled, nothing is done.

        Params:
            client = client to set timeout manager expiry registration

        Returns:
            true on success or false if the timeout feature is disabled.

     **************************************************************************/

    public bool setExpiryRegistration ( ISelectClient client )
    {
        if (this._timeout_enabled)
        {
            client.expiry_registration = this.timeout_manager.getRegistration(client);
            return true;
        }
        else
        {
            return false;
        }
    }

    /***************************************************************************

        Causes the event loop to exit before entering the next wait cycle.

        Note that after calling shutdown() the select dispatcher is left in an
        invalid state, where register() and unregister() calls will cause seg
        faults and further calls to eventLoop() will exit immediately.
        (See TODO in eventLoop().)

     **************************************************************************/

    public void shutdown ( )
    {
        this.register(this.shutdown_event);
        this.shutdown_event.trigger();
    }

    /**************************************************************************/

    deprecated("cycle hook delegate must return bool")
    public void eventLoop ( void delegate ( ) select_cycle_hook )
    {
        this.eventLoop({ select_cycle_hook(); return false; });
    }

    /***************************************************************************

        While there are clients registered, repeatedly waits for registered
        events to happen, invokes the corresponding event handlers of the
        registered clients and unregisters the clients if they desire so.

        Params:
            select_cycle_hook = if not null, will be called each time select
                cycle finished before waiting for more events. Also called
                once before the first select. If returns `true`, epoll will
                return immediately if there are no active events.
            unhandled_exception_hook = if not null, will be called each time
                select cycle results in unhandled exception. May either rethrow
                or consume (ignore) exception instance after processing it.

     **************************************************************************/

    public void eventLoop ( bool delegate ( ) select_cycle_hook = null,
        void delegate (Exception) unhandled_exception_hook  = null )
    in
    {
        assert (!this.in_event_loop, "Event loop has already been started.");
    }
    body
    {
        this.in_event_loop = true;
        scope ( exit ) this.in_event_loop = false;

        this.unhandled_exception_hook = unhandled_exception_hook;

        bool caller_work_pending = false;

        if (select_cycle_hook !is null)
            caller_work_pending = select_cycle_hook();

        while ( this.registered_clients.length && !this.shutdown_triggered )
        {
            try
            {
                this.select(caller_work_pending);
            }
            catch (Exception e)
            {
                if (unhandled_exception_hook !is null)
                    unhandled_exception_hook(e);
                else
                    throw e;              
            }

            if (select_cycle_hook !is null)
                caller_work_pending = select_cycle_hook();
        }
    }

    /***************************************************************************

        Executes an epoll select.

        Params:
            exit_asap = if set to 'true', epoll will exit immediately
                if there are no events to trigger. Otherwise epoll will wait
                indefinitely until any event fires.

        Returns:
            the number of epoll keys for which an event was reported.

     **************************************************************************/

    protected uint select ( bool exit_asap )
    {
        debug ( ISelectClient )
        {
            Stderr.formatln("{}.select ({} clients registered):",
                typeof(this).stringof, this.registered_clients.length).flush();
            size_t i;
            foreach ( client; cast(ClientSet)this.registered_clients )
            {
                Stderr.formatln("   {,3}: {}", i++, client).flush();
            }
        }

        while (true /* actually while epoll_wait is interrupted by a signal */)
        {
            ulong us_left = (this.timeout_manager !is null)
                            ? timeout_manager.us_left
                            : ulong.max;

            // Note that timeout_manager.us_left can be ulong.max, too.

            bool have_timeout = us_left < us_left.max;

            // have_timeout is true if a timeout is specified, no matter if
            // epoll_wait actually timed out or not (this is indicated by
            // n == 0).

            int epoll_wait_time;

            if (exit_asap)
                epoll_wait_time = 0;
            else
            {
                if (have_timeout)
                    epoll_wait_time = cast (int) this.usToMs(us_left);
                else
                    epoll_wait_time = -1;
            }

            int n = this.epoll.wait(this.events, epoll_wait_time);

            version ( EpollCounters ) this.counters.selects++;

            if (n >= 0)
            {
                debug ( ISelectClient ) if ( !n )
                {
                    Stderr.formatln("{}.select: timed out after {}microsec",
                            typeof(this).stringof, us_left).flush();
                }

                version ( EpollCounters ) if ( n == 0 ) this.counters.timeouts++;

                auto selected_set = events[0 .. n];

                this.handle(selected_set, this.unhandled_exception_hook);

                return n;
            }
            else
            {
                int errnum = .errno;

                if (errnum != EINTR)
                {
                    throw this.e.useGlobalErrno().addMessage(
                        "error waiting for epoll events");
                }
            }
        }
    }

    /***************************************************************************

        Called when the shutdown event fires (via a call to the shutdown()
        method). Sets the shutdown flag, ensuring that the event loop will exit,
        regardless of whether there are any clients still registered.

        Returns:
            true to stay registered in the selector

     **************************************************************************/

    private bool shutdownTrigger ( )
    {
        this.shutdown_triggered = true;

        return true;
    }

    /***************************************************************************

        Converts a microseconds value to milliseconds for use in select().
        It is crucial that this conversion always rounds up. Otherwise the
        timeout manager might not find a timed out client after select() has
        reported a timeout.

        Params:
            us = time value in microseconds

        Returns:
            nearest time value in milliseconds that is not less than us.

     **************************************************************************/

    private static ulong usToMs ( ulong us )
    {
        ulong ms = us / 1000;

        return ms + ((us - ms * 1000) != 0);
    }
}

