/******************************************************************************

    Base class for registrable client objects for the SelectDispatcher

    Contains the three things that the SelectDispatcher needs:
        1. the I/O device instance
        2. the I/O events to register the device for
        3. the event handler to invocate when an event occured for the device

    In addition a subclass may override finalize(). When handle() returns false
    or throws an Exception, the ISelectClient instance is unregistered from the
    SelectDispatcher and finalize() is invoked.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.io.select.client.model.ISelectClient;



/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.transition;

import ocean.io.select.client.model.ISelectClientInfo;

import ocean.sys.Epoll;

import ocean.io.model.IConduit: ISelectable;

import ocean.time.timeout.model.ITimeoutClient,
       ocean.time.timeout.model.IExpiryRegistration: IExpiryRegistration;

import ocean.core.Array: concat, append;

import ocean.text.util.ClassName;

debug import ocean.io.Stdout;

import ocean.text.convert.Format;

/******************************************************************************

    ISelectClient abstract class

 ******************************************************************************/

public abstract class ISelectClient : ITimeoutClient, ISelectable, ISelectClientInfo
{
    /**************************************************************************

        Convenience alias to avoid public imports

     **************************************************************************/

    public alias .ISelectable ISelectable;

    /**************************************************************************

        Enum of event types

     **************************************************************************/

    alias Epoll.Event Event;

    /**************************************************************************

        Enum of the status when finalize() is called.

     **************************************************************************/

    enum FinalizeStatus : uint
    {
        Success = 0,
        Error,
        Timeout
    }

    /**************************************************************************

        I/O device instance

        Note: Conforming to the name convention used in ocean.io.selector, the
        ISelectable instance is named "conduit" although ISelectable and
        IConduit are distinct from each other. However, in most application
        cases the provided instance will originally implement both ISelectable
        and IConduit (as, for example, ocean.io.device.Device and
        ocean.net.device.Socket).

     **************************************************************************/

    public abstract Handle fileHandle ( );

    /**************************************************************************

        Events to register the conduit for.

     **************************************************************************/

    public abstract Event events ( );

    /**************************************************************************

        Connection time out in microseconds. Effective only when used with an
        EpollSelectDispatcher which has timeouts enabled. A value of 0 has no
        effect.

     **************************************************************************/

    public ulong timeout_us = 0;

    /**************************************************************************

        Timeout expiry registration instance

     **************************************************************************/

    private IExpiryRegistration expiry_registration_;

    /**************************************************************************

        The "my conduit is registered with epoll with my events and me as
        attachment" flag, set by registered() and cleared by unregistered().

        Notes:
            1. The system can automatically unregister the conduit when its
               file descriptor is closed; when this happens this flag is true by
               mistake. The EpollSelectDispatcher is aware of that. However,
               this flag can never be false by mistake.
            2. There are use cases where several instances of this class share
               the same conduit. Exactly one instance is associated to the
               conduit registration and has is_registered_ = true. For the other
               instances is_registered_ is false although their conduit is in
               fact registered with epoll.

     **************************************************************************/

    private bool is_registered_;

    /**************************************************************************

        Sets the timeout manager expiry registration.

        Params:
            expiry_registration_ = timeout manager expiry registration

        Returns:
            timeout manager expiry registration

     **************************************************************************/

    public IExpiryRegistration expiry_registration ( IExpiryRegistration expiry_registration_ )
    {
        return this.expiry_registration_ = expiry_registration_;
    }

    /***************************************************************************

        Returns:
            true if this client has timed out or false otherwise.

    ***************************************************************************/

    public bool timed_out ( )
    {
        return (this.expiry_registration_ !is null)?
                    this.expiry_registration_.timed_out : false;
    }

    /**************************************************************************

        I/O event handler

        Params:
             event   = identifier of I/O event that just occured on the device

        Returns:
            true if the handler should be called again on next event occurrence
            or false if this instance should be unregistered from the
            SelectDispatcher.

     **************************************************************************/

    abstract public bool handle ( Event event );

    /**************************************************************************

        Timeout method, called after a timeout occurs in the SelectDispatcher
        eventLoop. Intended to be overridden by a subclass if required.

     **************************************************************************/

    public void timeout ( ) { }

    /**************************************************************************

        Finalize method, called after this instance has been unregistered from
        the Dispatcher. Intended to be overridden by a subclass if required.

        Params:
            status = status why this method is called

     **************************************************************************/

    public void finalize ( FinalizeStatus status ) { }

    /**************************************************************************

        Error reporting method, called when an Exception is caught from
        handle(). Calls the error_() method, which should be overridden by a
        subclass if required.

        Note that this method will catch all exceptions thrown by the error_()
        method. This is to prevent unhandled exceptions flying out of the select
        dispatcher and bringing down the event loop.

        Params:
            exception = Exception thrown by handle()
            event     = Selector event while exception was caught

     **************************************************************************/

    final public void error ( Exception exception, Event event = Event.None )
    {
        try
        {
            this.error_(exception, event);
        }
        catch ( Exception e )
        {
            // Note: this should *never* happen! In case it ever does, here's
            // a helpful printout to notify the application programmer.
            debug Stderr.formatln(
                "Very bad: Exception thrown from inside ISelectClient.error() delegate! -- {} ({}:{})",
                getMsg(e), e.file, e.line
            );
        }
    }

    protected void error_ ( Exception exception, Event event ) { }


    /**************************************************************************

        Obtains the current error code of the underlying I/O device.

        To be overridden by a subclass for I/O devices that support querying a
        device specific error status (e.g. sockets with getsockopt()).

        Returns:
            the current error code of the underlying I/O device.

     **************************************************************************/

    public int error_code ( )
    {
        return 0;
    }

    /**************************************************************************

        Register method, called after this client is registered with the
        SelectDispatcher. Intended to be overridden by a subclass if required.

     **************************************************************************/

    final public void registered ( )
    in
    {
        assert (!this.is_registered_, classname(this) ~ ".registered(): already registered");
    }
    body
    {
        this.is_registered_ = true;

        try if (this.expiry_registration_ !is null)
        {
            this.expiry_registration_.register(this.timeout_us);
        }
        finally
        {
            this.registered_();
        }
    }

    /**************************************************************************

        Unregister method, called after this client is unregistered from the
        SelectDispatcher. Intended to be overridden by a subclass if required.

     **************************************************************************/

    final public void unregistered ( )
    in
    {
        assert (this.is_registered_, classname(this) ~ ".unregistered(): not registered");
    }
    body
    {
        this.is_registered_ = false;

        try if (this.expiry_registration_ !is null)
        {
            this.expiry_registration_.unregister();
        }
        finally
        {
            this.unregistered_();
        }
    }

    /**************************************************************************

        Returns true if this.conduit is currently registered for this.events
        with this as attachment. Returns false if this.conduit is not registered
        with epoll or, when multiple instances of this class share the same
        conduit, if it is registered with another instance.

        Note that the returned value can be true by mistake when epoll
        unexpectedly unregistered the conduit file descriptor as it happens when
        the file descriptor is closed (e.g. on error). However, the returned
        value cannot be true by mistake.

        Returns:
            true if this.conduit is currently registered for this.events with
            this as attachment or false otherwise.

     **************************************************************************/

    public bool is_registered ( )
    {
        return this.is_registered_;
    }

    /***************************************************************************

        ISelectClientInfo method.

        Returns:
            I/O timeout value of client in microseconds. A value of 0 means that
            no timeout is set for this client

    ***************************************************************************/

    public ulong timeout_value_us ( )
    {
        return this.timeout_us;
    }

    /**************************************************************************

        Called by registered(); may be overridden by a subclass.

     **************************************************************************/

    protected void registered_ ( ) { }

    /**************************************************************************

        Called by unregistered(); may be overridden by a subclass.

     **************************************************************************/

    protected void unregistered_ ( ) { }

    /**************************************************************************

        Returns an identifier string of this instance. Defaults to the name of
        the class, but may be overridden if more detailed information is
        required.

        Note that this method is only ever called in cases where one or more
        debug compile flags are switched on (ISelectClient, for example). Hence
        the loop to extract the class name from the full module/class name
        string is not considered a performance problem.

        Returns:
             identifier string of this instance

     **************************************************************************/

    public cstring id ( )
    {
        return classname(this);
    }

    /***************************************************************************

        Returns a string describing this client, for use in debug messages.

        Returns:
            string describing client

    ***************************************************************************/

    debug public override istring toString ( )
    {
        mstring to_string_buf;
        this.fmtInfo((cstring chunk) {to_string_buf ~= chunk;});
        return assumeUnique(to_string_buf);
    }

    /***************************************************************************

        Produces a string containing information about this instance: Dynamic
        type, file descriptor and events.

        Params:
            sink = `Layout.convert()`-style sink of string chunks

    ***************************************************************************/

    public void fmtInfo ( void delegate ( cstring chunk ) sink )
    {
        Format.convert(
            (cstring chunk) {sink(chunk); return chunk.length;},
            "{} fd={} events=", this.id, this.fileHandle
        );
        foreach ( event, name; epoll_event_t.event_to_name )
        {
            if ( this.events & event )
            {
                sink(name);
            }
        }
    }
}

/******************************************************************************

    IAdvancedSelectClient abstract class

    Provides a set of interfaces which can be implemented by classes which
    desire notification of various events in the select client, and a set of
    corresponding methods which allow the user to pass an instance of these
    interfaces to an instance of this class:
        * IFinalizer interface, set by the finalizer() method, called when a
          select client is unregistered.
        * IErrorReporter interface, set by the error_reporter() method, called
          when an error occurs while handling a select client.
        * ITimeoutReporter interface, set by the timeout_reporter() method,
          called when a timeout occurs while handling a select client.
        * IConnectionInfo interface, set by the connection_info() method, called
          in debug(ISelectClient) mode when the selector wishes to get a string
          containing information about the connection a select client is using.

 ******************************************************************************/

abstract class IAdvancedSelectClient : ISelectClient
{
    /**************************************************************************/

    interface IFinalizer
    {
        alias IAdvancedSelectClient.FinalizeStatus FinalizeStatus;

        void finalize ( FinalizeStatus status );
    }

    /**************************************************************************/

    interface IErrorReporter
    {
        void error ( Exception exception, Event event = Event.None );
    }

    /**************************************************************************/

    interface ITimeoutReporter
    {
        void timeout ( );
    }

    /**************************************************************************

        Interface instances

     **************************************************************************/

    private IFinalizer       finalizer_        = null;
    private IErrorReporter   error_reporter_   = null;
    private ITimeoutReporter timeout_reporter_ = null;

    /**************************************************************************

        Sets the Finalizer. May be set to null to disable finalizing.

        Params:
            finalizer_ = IFinalizer instance

     **************************************************************************/

    public void finalizer ( IFinalizer finalizer_ )
    {
        this.finalizer_ = finalizer_;
    }

    /**************************************************************************

        Sets the TimeoutReporter. May be set to null to disable timeout
        reporting.

        Params:
            timeout_reporter_ = ITimeoutReporter instance

     **************************************************************************/

    public void timeout_reporter ( ITimeoutReporter timeout_reporter_ )
    {
        this.timeout_reporter_ = timeout_reporter_;
    }

    /**************************************************************************

        Sets the Error Reporter. May be set to null to disable error reporting.

        Params:
            error_reporter_ = IErrorReporter instance

     **************************************************************************/

    public void error_reporter ( IErrorReporter error_reporter_ )
    {
        this.error_reporter_ = error_reporter_;
    }

    /**************************************************************************

        Finalize method, called after this instance has been unregistered from
        the Dispatcher.

     **************************************************************************/

    public override void finalize ( FinalizeStatus status )
    {
        if (this.finalizer_ !is null)
        {
            this.finalizer_.finalize(status);
        }
    }

    /**************************************************************************

        Error reporting method, called when an Exception is caught from
        super.handle().

        Params:
            exception = Exception thrown by handle()
            event     = Selector event while exception was caught

     **************************************************************************/

    override protected void error_ ( Exception exception, Event event )
    {
        if (this.error_reporter_)
        {
            this.error_reporter_.error(exception, event);
        }
    }

    /**************************************************************************

        Timeout method, called after this a timeout has occurred in the
        SelectDispatcher.

     **************************************************************************/

    override public void timeout ( )
    {
        if (this.timeout_reporter_)
        {
            this.timeout_reporter_.timeout();
        }
    }
}
