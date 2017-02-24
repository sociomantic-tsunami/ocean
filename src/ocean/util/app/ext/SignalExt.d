/*******************************************************************************

    Application extension which handles signals to the process and calls the
    onSignal() method of all registered extensions (see ISignalExtExtension).
    The extension can handle any number of different signals -- depending solely
    on which signals are specified in the constructor.

    Note: not only must the extension be registered with the application but its
    internal SignalEvent (returned by the selectClient() method) must also be
    registered with an epoll instance! Until the event is registered with epoll
    and the event loop started, the signal handlers will not be called in
    response to signals which have occurred.

    Usage example:

    ---

        import ocean.util.app.Application;
        import ocean.util.app.ext.SignalExt;
        import ocean.io.select.EpollSelectDispatcher;
        import core.sys.posix.signal : SIGINT, SIGTERM;

        // Example application class which does two things:
        // 1. Owns an instance of SignalExtension and registers some signals
        //    with it.
        // 2. Implements ISignalExtExtension to be notified when registered
        //    signals occur.

        // It's important to understand that these two things are not connected.
        // It's perfectly possible for an application class to own a SignalExt
        // but for another class (indeed other classes) elsewhere to implement
        // ISignalExtExtension to receive the notification of signals occurring.
        class MyApp : Application, ISignalExtExtension
        {
            private SignalExt signal_ext;

            this ( )
            {
                super("name", "desc");

                // Construct a signal extension instance and tell it which
                // signals we're interested in. The list of signals can be
                // extended after construction via the register() method.
                auto signals = [SIGINT, SIGTERM];
                this.signal_ext = new SignalExt(signals);

                // Register the signal extension with the application class
                // (this).
                this.registerExtension(this.signal_ext);

                // Register this class with the signal extension so that it will
                // be notified (via its onSignal() method, below) when one of
                // the registered signals occurs.
                this.signal_ext.registerExtension(this);
            }

            // Signal handler callback required by ISignalExtExtension. Called
            // when a signal which has been registered with the signal extension
            // occurs.
            override void onSignal ( int signum )
            {
            }

            // Application main method required by Application.
            override int run ( char[][] args )
            {
                // Important: onSignal() will not be called until the signal
                // extension's event has been registered with epoll!
                auto epoll = new EpollSelectDispatcher;
                epoll.register(this.signal_ext.selectClient());
                epoll.eventLoop();

                return 0;
            }
        }

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.ext.SignalExt;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.util.app.model.IApplicationExtension;
import ocean.util.app.model.ExtensibleClassMixin;

import ocean.util.app.Application;

import ocean.util.app.ext.model.ISignalExtExtension;

import ocean.io.select.client.SignalEvent;



public class SignalExt : IApplicationExtension
{
    import ocean.io.select.client.model.ISelectClient;

    /***************************************************************************

        Adds a list of extensions (this.extensions) and methods to handle them.
        See ExtensibleClassMixin documentation for details.

    ***************************************************************************/

    mixin ExtensibleClassMixin!(ISignalExtExtension);


    /***************************************************************************

        Signal event which is registered with epoll to handle notifications of
        the occurrence of the signal.

    ***************************************************************************/

    private SignalEvent event_;


    /***************************************************************************

        Constructor. Creates the internal signal event, handling the specified
        signals. The event (accessible via the event() method) must be
        registered with epoll.

        The list of signals handled may be extended after construction by
        calling the register() method.

        Params:
            signals = list of signals to handle

        Throws:
            SignalErrnoException if the creation of the SignalEvent fails

    ***************************************************************************/

    public this ( int[] signals )
    {
        this.event_ = new SignalEvent(&this.handleSignal, signals);
    }


    /***************************************************************************

        Adds the specified signal to the set of signals handled by this
        extension.

        Params:
            signal = signal to handle

        Returns:
            this instance for chaining

        Throws:
            SignalErrnoException if the updating of the SignalEvent fails

    ***************************************************************************/

    public typeof(this) register ( int signal )
    {
        this.event_.register(signal);

        return this;
    }


    /***************************************************************************

        SignalEvent getter, for registering with epoll.

        Returns:
            internal SignalEvent member

    ***************************************************************************/

    deprecated("Please use SignalExt.selectClient() instead.")
    public SignalEvent event ( )
    {
        return this.event_;
    }


    /***************************************************************************

        ISelectClient getter, for registering with epoll.

        Returns:
            ISelectClient interface to register with epoll

    ***************************************************************************/

    public ISelectClient selectClient ( )
    {
        return this.event_;
    }


    /***************************************************************************

        Extension order. This extension uses -2_000 because it should be called
        before the LogExt and StatsExt.

        Returns:
            the extension order

    ***************************************************************************/

    public override int order ( )
    {
        return -2_000;
    }


    /***************************************************************************

        Signal handler delegate, called from epoll when a signal has fired. In
        turn notifies all registered extensions about the signal.

        Params:
            siginfo = info about signal which has fired

    ***************************************************************************/

    private void handleSignal ( SignalEvent.SignalInfo siginfo )
    {
        foreach ( ext; this.extensions )
        {
            ext.onSignal(siginfo.ssi_signo);
        }
    }


    /***************************************************************************

        Unused IApplicationExtension methods.

        We just need to provide an "empty" implementation to satisfy the
        interface.

    ***************************************************************************/

    public override void preRun ( IApplication app, istring[] args )
    {
    }

    /// ditto
    public override void postRun ( IApplication app, istring[] args, int status )
    {
    }

    /// ditto
    public override void atExit ( IApplication app, istring[] args, int status,
            ExitException exception )
    {
    }

    /// ditto
    public override ExitException onExitException ( IApplication app, istring[] args,
            ExitException exception )
    {
        return exception;
    }
}
