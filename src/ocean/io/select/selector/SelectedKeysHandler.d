/*******************************************************************************

    Handles a set of selected epoll keys. A selected epoll key is an event
    reported by epoll bundled with its context; the context is the ISelectClient
    object that contains the file descriptor and the event handler method.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.selector.SelectedKeysHandler;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.io.select.selector.model.ISelectedKeysHandler;

import ocean.io.select.client.model.ISelectClient;

import ocean.sys.Epoll;

import ocean.io.select.selector.EpollException;

debug (ISelectClient) import ocean.io.Stdout;

/******************************************************************************/

class SelectedKeysHandler: ISelectedKeysHandler
{
    /***************************************************************************

       Type alias of a callback delegate to remove a client registration. Does
       not fail/throw if the client is not registered.

       Params:
            client = client to unregister

       Should return:
            0 if everything worked as expected or the error code (errno) as a
            warning on minor errors, that is, everything except ENOMEM (out of
            memory) and EINVAL (invalid epoll file descriptor or epoll_ctl()
            opcode).
            ENOENT is a minor error that happens regularly when the client was
            unexpectedly unregistered as it happens when its file descriptor is
            closed.

        Should throw:
            EpollException on the fatal errors ENOMEM and EINVAL.

    ***************************************************************************/

    public alias int delegate ( ISelectClient client ) UnregisterDg;

    /***************************************************************************

       Callback delegate to remove a client registration, see the description
       for the type alias above.

    ***************************************************************************/

    protected UnregisterDg unregister;

    /***************************************************************************

        Exception to throw if an error event was reported for a selected key.

    ***************************************************************************/

    private EpollException e;

    /***************************************************************************

        Constructor.

        Params:
            unregister = callback delegate to remove a client registration, must
                be available during the lifetime of this instance
            e = exception to keep and throw if an error event was reported for
                a selected key

    ***************************************************************************/

    public this ( UnregisterDg unregister, EpollException e )
    {
        this.unregister = unregister;
        this.e = e;
    }

    /***************************************************************************

        Handles the clients in selected_set.

        Params:
            selected_set = the result list of epoll_wait()
            unhandled_exception_hook = if not null, will be called each time
                event call results in unhandled exception. May both rethrow
                and consume exception instance after processing it.

    ***************************************************************************/

    override public void opCall ( epoll_event_t[] selected_set,
        void delegate (Exception) unhandled_exception_hook )
    {
        foreach (key; selected_set)
        {
            this.handleSelectedKey(key, unhandled_exception_hook);
        }
    }

    /***************************************************************************

        Handles key by calling its handle() method and unregisters it if the
        handle() call either returns false or throws an exception. In the latter
        case the exception thrown is reported to the client by calling its
        error() method.

        Params:
            key = an epoll key which contains a client to be handled and the
                  reported event
            unhandled_exception_hook = if not null, will be called each time
                event call results in unhandled exception. May both rethrow
                and consume exception instance after processing it.

     **************************************************************************/

    final protected void handleSelectedKey ( epoll_event_t key,
        void delegate (Exception) unhandled_exception_hook )
    {
        ISelectClient client = cast (ISelectClient) key.data.ptr;

        debug ( ISelectClient ) this.logEvents(client, key.events);

        // Only handle clients which are registered. Clients may have
        // already been unregistered (presumably deliberately), as a side-
        // effect of handling previous clients, so we don't unregister them
        // again or call their finalizers.
        if ( client.is_registered )
        {
            bool unregister_key = true,
                 error          = false;

            try
            {
                this.checkKeyError(client, key.events);

                unregister_key = !client.handle(key.events);

                debug (ISelectClient) this.logHandled( client, unregister_key);
            }
            catch (Exception e)
            {
                debug (ISelectClient) this.logException(client, e);

                this.clientError(client, key.events, e);
                error = true;

                if (unhandled_exception_hook !is null)
                {
                    unhandled_exception_hook(e);
                }
            }

            if (unregister_key)
            {
                this.unregisterAndFinalize(client,
                                           error? client.FinalizeStatus.Error :
                                                  client.FinalizeStatus.Success);
            }
        }
    }

    /***************************************************************************

        Checks if a selection key error has occurred by checking events and
        querying a socket error.

        Hangup states are not checked here, for the following reasons:
            1. The hangup event is not an error on its own and may be expected
               to happen, e.g. when short term connections are used. In that
               case it is also possible and expected that hangup combined with
               the read event when the remote closed the connection after having
               data sent, and that data have not been read from the socket yet.
            2. Experience shows that, when epoll reports a combination of read
               and hangup event, it will keep reporting that combination even if
               there are actually no data pending to read from the socket. In
               that case the only way of determining whether there are data
               pending is calling read() and comparing the return value against
               EOF. An application that relies on an exception thrown here will
               then run into an endless turbo event loop.
            3. Only the application knows whether hangup events are expected or
               exceptions. If it expects them, it may want its handler to be
               invoked which will not happen if checkKeyError() throws an
               exception. If it treats hangup events as exceptions, it will want
               an exception to be thrown even if it was combined with a read or
               write event.

        Params:
            client = client for which an event was reported
            events = reported events

        Throws:
            EpollException if events contains an error code. The exception
            thrown, which is an ErrnoIOException and an IOException, contains
            the errno code as reported by client.error_code.

     **************************************************************************/

    private void checkKeyError ( ISelectClient client, Epoll.Event events )
    {
        if (events & events.EPOLLERR)
        {
            this.e.set(client.error_code).append(" -- error event reported for ");
            client.fmtInfo((cstring chunk) {this.e.append(chunk);});
            throw this.e;
        }
    }

    /***************************************************************************

        Unregisters and finalizes a select client. Any errors which occur while
        calling the client's finalizer are caught and reported to the client's
        error() method (see clientError(), below).

        Params:
            client = client to finalize
            status = finalize status to report to the client (e.g. success or
                     error)

    ***************************************************************************/

    final protected void unregisterAndFinalize ( ISelectClient client,
                                           ISelectClient.FinalizeStatus status )
    {
        this.unregister(client);

        try
        {
            client.finalize(status);
        }
        catch ( Exception e )
        {
            debug (ISelectClient)
            {
                Stderr.format("{} :: Error while finalizing client: '{}'",
                    client, getMsg(e)).flush();
                if ( e.line )
                {
                    Stderr.format("@ {}:{}", e.file, e.line);
                }
                Stderr.formatln("");
            }
            this.clientError(client, Epoll.Event.None, e);
        }
    }

    /***************************************************************************

        Called when an exception is thrown while handling a client (either the
        handle() or finalize() method).

        Calls the client's error() method, and in debug builds ouputs a message.

        Params:
            client = client which threw e
            events = epoll events which fired for client
            e      = exception thrown by client.handle() or client.finalize()

      **************************************************************************/

    private void clientError ( ISelectClient client, Epoll.Event events, Exception e )
    {
        debug (ISelectClient)
        {
            // FIXME: printing on separate lines for now as a workaround for a
            // dmd bug with varargs
            Stderr.formatln("{} :: Error during handle:", client);
            Stderr.formatln("    '{}'", getMsg(e)).flush();
            if ( e.line )
            {
                Stderr.formatln("    @ {}:{}", e.file, e.line).flush();
            }
        }

        client.error(e, events);
    }

    /***************************************************************************

        Debug console output functions.

    ***************************************************************************/

    debug (ISelectClient):

    /***************************************************************************

        Logs that events were reported for client.

        Params:
            client = select client for which events were reported
            events = events reported for client

    ***************************************************************************/

    private static void logEvents ( ISelectClient client, epoll_event_t.Event events )
    {
        Stderr.format("{} :: Epoll firing with events ", client);
        foreach ( event, name; epoll_event_t.event_to_name )
        {
            if ( events & event )
            {
                Stderr.format("{}", name);
            }
        }
        Stderr.formatln("").flush();
    }

    /***************************************************************************

        Logs that client was handled.

        Params:
            client         = handled client
            unregister_key = true if the client is unregistered or false if it
                             stays registered

    ***************************************************************************/

    private static void logHandled ( ISelectClient client, bool unregister_key )
    {
        if ( unregister_key )
        {
            Stderr.formatln("{} :: Handled, unregistering fd", client);
        }
        else
        {
            Stderr.formatln("{} :: Handled, leaving fd registered", client);
        }
        Stderr.flush();
    }

    /***************************************************************************

        Logs that an exception was thrown while handing client. This includes
        an error event reported by epoll.

        Params:
            client = client that caused an error
            e      = caught exception

    ***************************************************************************/

    private static void logException ( ISelectClient client, Exception e )
    {
        // FIXME: printing on separate lines for now as a workaround
        // for a dmd bug with varargs

        version (none)
        {
             Stderr.formatln("{} :: ISelectClient handle exception: '{}' @{}:{}",
                 client, getMsg(e), e.file, e.line);
        }
        else
        {
            Stderr.formatln("{} :: ISelectClient handle exception:", client);
            Stderr.formatln("    '{}'", getMsg(e));
            Stderr.formatln("    @{}:{}", e.file, e.line);
        }
        Stderr.flush();
    }
}
