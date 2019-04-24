/*******************************************************************************

    Epoll-based signal handlers.

    Note that the signals will be handled with a delay of up to single epoll
    cycle. This is because the signal extension is synced with the
    EpollSelectDispatcher. This makes it unsuitable to handle critical signals
    (like `SIGABRT` or `SIGSEGV`) where the application shouldn't be allowed to
    proceed in the general case; for these cases setup an asynchronous signal
    handler using `sigaction` instead.

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.application.components.Signals;

import ocean.transition;

/// ditto
public class Signals
{
    import ocean.core.Verify;
    import ocean.io.device.Conduit: ISelectable;
    import ocean.io.device.Device;
    import ocean.io.device.IODevice;
    import ocean.io.select.client.model.ISelectClient;
    import ocean.io.select.protocol.SelectReader;
    import ocean.sys.Pipe;
    import ocean.sys.SignalFD;

    import core.sys.posix.signal;

    /***************************************************************************

        SignalErrnoException.

    ***************************************************************************/

    alias SignalFD.SignalErrnoException SignalErrnoException;

    /***************************************************************************

        SelectReader instance used to read the data from pipe written by
        signal handler.

    ***************************************************************************/

    private SelectReader reader;

    /***************************************************************************

        Associative array of old signal handlers, addressed by the signal
        number.

    ***************************************************************************/

    private sigaction_t[int] old_signals;

    /***************************************************************************

        Helper class wrapping Device to InputDevice. Used to read from Pipe
        via SelectReader.

    ***************************************************************************/

    private static class InputDeviceWrapper: InputDevice, ISelectable
    {
        /***********************************************************************

            Device instance to read from.

        ***********************************************************************/

        private Device device;

        /***********************************************************************

            Constructor.

            Params:
                device = device instance to read from.

        ***********************************************************************/

        public this (Device device)
        {
            this.device = device;
        }

        /***********************************************************************

            Returns:
                file handle of the underlying device.

        ***********************************************************************/

        override Handle fileHandle()
        {
            return this.device.fileHandle();
        }
    }

    /***************************************************************************

        InputDevice reading data from the file.

    ***************************************************************************/

    private InputDeviceWrapper pipe_source;

    /***************************************************************************

        Pipe used to tranfser the data from the signal handler back to the
        application. Static as used from the static signal handler

    ***************************************************************************/

    private static Pipe signal_pipe;

    /// Signal handler delegate type.
    private alias void delegate ( int[] ) HandlerDg;

    /// Delegate to call when the signal handler fires in epoll.
    private HandlerDg handler_dg;

    /***************************************************************************

        Signal handler. Needs to be static method as it is registered as
        C callback.

        Params:
            signum = signal being handled

    ***************************************************************************/

    private static extern(C) void signalHandler (int signum)
    {
        typeof(this).signal_pipe.sink.write(cast(ubyte[])(&signum)[0..1]);
    }

    /***************************************************************************

        Static constructor. Initialises signal_pipe static member.

    ***************************************************************************/

    static this ( )
    {
        // Setup a pipe for transferring the signal info. Unbuffered,
        // as we want these to be available as soon as possible.
        typeof(this).signal_pipe = new Pipe(0);
    }

    /***************************************************************************

        Constructor. Creates the internal signal event. The event (accessible
        via the selectClient() method) must be registered with epoll.

        Params:
            handler_dg = delegate to call when the signal handler fires in epoll

    ***************************************************************************/

    public this ( scope HandlerDg handler_dg )
    {
        verify(handler_dg !is null);
        this.handler_dg = handler_dg;

        typeof(this).signal_pipe.source.setNonBlock();
        this.pipe_source =
            new InputDeviceWrapper(typeof(this).signal_pipe.source);
        this.reader = new SelectReader(this.pipe_source, int.sizeof);

        // Make the intention to read 4 bytes (the signal number). This will
        // read it from the pipe in one of the epoll cycles, after the data
        // is written into the pipe from signal handler.
        this.reader.read(&this.handleSignals);
    }

    /***************************************************************************

        Ignores the specified signals.

        Params:
            signals = list of signals to ignore

        Throws:
            SignalErrnoException if setting up the signal fails

    ***************************************************************************/

    public void ignore ( in int[] signals )
    {
        this.installSignalHandlers(signals, SIG_IGN);
    }

    /***************************************************************************

        Handles the specified signals.

        Params:
            signals = list of signals to handle

        Throws:
            SignalErrnoException if setting up the signal fails

    ***************************************************************************/

    public void handle ( in int[] signals )
    {
        this.installSignalHandlers(signals);
    }

    /***************************************************************************

        Restores the original signal handlers.

        Throws:
            SignalErrnoException if resetting up the signal fails

    ***************************************************************************/

    public void clear ( )
    {
        foreach (signal, sa; this.old_signals)
        {
            if (sigaction(signal, &sa, null) == -1)
            {
                throw (new SignalErrnoException).useGlobalErrno("sigaction");
            }
        }
    }

    /***************************************************************************

        Returns:
            ISelectClient interface to register with epoll

    ***************************************************************************/

    public ISelectClient selectClient ( )
    {
        return this.reader;
    }

    /***************************************************************************

        Signal handler delegate, called from epoll when a signal has fired. In
        turn notifies all registered extensions about the signal.

        Params:
            signals = info about signals which have fired

    ***************************************************************************/

    private void handleSignals ( void[] signals_read )
    {
        auto signals = cast(int[])signals_read;
        this.handler_dg(signals);
    }

    /***************************************************************************

        Installs the signal handlers.

        Params:
            signals = list of signals to handle
            signal_handler = signal handler to install

        Throws:
            SignalErrnoException if setting up the signal fails

    ***************************************************************************/

    private void installSignalHandlers ( in int[] signals,
            in typeof(sigaction_t.sa_handler) signal_handler = &this.signalHandler)
    {
        sigaction_t sa;

        sa.sa_handler = signal_handler;

        if (sigemptyset(&sa.sa_mask) == -1)
        {
            throw (new SignalErrnoException).useGlobalErrno("sigemptyset");
        }

        foreach (signal; signals)
        {
            this.old_signals[signal] = sigaction_t.init;
            sigaction_t* old_handler = signal in this.old_signals;
            verify(old_handler !is null);

            if (sigaction(signal, &sa, old_handler) == -1)
            {
                throw (new SignalErrnoException).useGlobalErrno("sigaction");
            }
        }
    }
}
