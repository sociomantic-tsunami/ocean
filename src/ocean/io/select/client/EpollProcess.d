/*******************************************************************************

    Posix process with epoll integration of output streams (stdout & stderr).

    Usage example:

    ---

        import ocean.io.Stdout;
        import ocean.io.select.client.EpollProcess;
        import ocean.io.select.EpollSelectDispatcher;

        // Simple epoll process class which uses curl to download data from a
        // url
        class CurlProcess : EpollProcess
        {
            this ( EpollSelectDispatcher epoll )
            {
                super(epoll);
            }

            // Starts the process downloading a url
            public void start ( char[] url )
            {
                super.start("curl", [url]);
            }

            // Called by the super class when the process sends data to stdout.
            // (In the case of curl this is data downloaded from the url.)
            protected void stdout ( ubyte[] data )
            {
                Stdout.formatln("Received: '{}'", data);
            }

            // Called by the super class when the process sends data to stderr.
            // (In the case of curl this is progress & error messages, which we
            // just ignore in this example.)
            protected void stderr ( ubyte[] data )
            {
            }

            // Called by the super class when the process is finished.
            protected void finished ( bool exited_ok, int exit_code )
            {
                if ( exited_ok )
                {
                    Stdout.formatln("Process exited with code {}", exit_code);
                }
                else
                {
                    Stdout.formatln("Process terminated abnormally");
                }
            }
        }

        // Create epoll selector instance.
        auto epoll = new EpollSelectDispatcher;

        // Create a curl process instance.
        auto process = new CurlProcess(epoll);

        // Start the process running, executing a curl command to download data
        // from a url.
        process.start("http://www.google.com");

        // Handle arriving data.
        epoll.eventLoop;

    ---

    It is sometimes desirable to use more than one
    EpollSelectDispatcher instance with various EpollProcess instances.
    One example of such usage is when an application needs to create
    short-lived EpollProcess instance(s) in a unittest block. In this case
    one EpollSelectDispatcher instance would be needed in the unittest
    block, and a different one in the application's main logic.

    This will work provided that all processes created during the test have
    terminated before the main application starts.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.client.EpollProcess;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.util.container.map.Map;

import ocean.io.select.client.model.ISelectClient;

import ocean.io.select.client.SelectEvent;

import ocean.io.select.EpollSelectDispatcher;

import ocean.io.model.IConduit;

import ocean.stdc.posix.sys.wait;

import ocean.sys.Process;

debug import ocean.io.Stdout;

import core.stdc.errno;

import ocean.util.log.Log;

import core.sys.posix.signal : SIGCHLD;



/*******************************************************************************

    Static module logger

*******************************************************************************/

static private Logger log;
static this ( )
{
    log = Log.lookup("ocean.io.select.client.EpollProcess");
}


/*******************************************************************************

    Posix process with epoll integration of output streams (stdout & stderr).

*******************************************************************************/

public abstract class EpollProcess
{
    /***************************************************************************

        Class to monitor and handle inter-process signals via a signal event
        registered with epoll.

        SIGCHLD event handling is an intrinsically global operation, so this
        class exists only as a singleton.

    ***************************************************************************/

    private static class GlobalProcessMonitor
    {
        /***********************************************************************

            Select event instance which is triggered when a SIGCHLD signal is
            generated, indicating that a child process has terminated.
            Registered with epoll when one or more EpollProcesses are running.

        ***********************************************************************/

        private SelectEvent sigchild_event;


        /***********************************************************************

            Mapping from a process id to an EpollProcess instance.

        ***********************************************************************/

        private StandardKeyHashingMap!(EpollProcess, int) processes;


        /***********************************************************************

            Constructor.

        ***********************************************************************/

        public this ( )
        {
            this.processes = new StandardKeyHashingMap!(EpollProcess, int)(20);

            this.sigchild_event = new SelectEvent(&this.selectEventHandler);

        }


        /***********************************************************************

            Enables or disables the SIGCHLD signal handler.

            If the handler is enabled, then when a SIGCHLD event occurs, the
            sigchild_event will be triggered.

            Params:
                enable = true to enable the handler, false to restore default
                    signal handling

        ***********************************************************************/

        private void enableSigChildHander ( bool enable )
        {

            sigaction_t sa;

            // SA_RESTART must be specified, to avoid problems with
            // poorly-written code that does not handle EINTR correctly.

            sa.sa_flags = SA_RESTART;
            sa.sa_handler = enable ? &this.sigchld_handler : SIG_DFL;

            sigaction(SIGCHLD, &sa, null);
        }


        /***********************************************************************

            Signal handler for SIGCHLD.
            Triggers the sigchild_event select event when a SIGCHLD signal
            was received.

            Params:
                sig = the signal which has happened (always SIGCHLD)

        ***********************************************************************/

        static extern(C) void sigchld_handler ( int sig )
        {
            // It is legal to call SignalEvent.trigger() from inside a signal
            // handler. This is because it is implemented using write(), which
            // is included in the POSIX,1 2004 list of "safe functions" for
            // signal handlers.

            if ( EpollProcess.process_monitor.sigchild_event )
            {
                EpollProcess.process_monitor.sigchild_event.trigger();
            }
        }


        /***********************************************************************

            Adds an EpollProcess instance to the set of running processes. The
            SIGCHLD event handler is registered with the epoll instance used
            by the EpollProcess, and will call the signalHandler() method when
            a child process terminates.

            Params:
                process = process which has just started

        ***********************************************************************/

        public void add ( EpollProcess process )
        {
            this.processes[process.process.pid] = process;

            process.epoll.register(this.sigchild_event);

            this.enableSigChildHander(true);
        }


        /***********************************************************************

            Event handler for the SIGCHILD SelectEvent.

            Fired by the signal handler when a SIGCHLD signal occurs. Calls
            waitpid to find out which child process caused the signal to fire,
            informs the corresponding EpollProcess instance that the process has
            exited, and removes that process from the set of running signals.
            If there are no further running processes, the event is unregistered
            from epoll and the signal handler is disabled.

            Returns:
                true if the event should fire again, false if it should be
                unregistered from epoll

        ***********************************************************************/

        private bool selectEventHandler ( )
        {
            debug ( EpollProcess ) Stdout.formatln("Sigchild fired in epoll: ");

            pid_t pid;
            do
            {
                int status;
                pid = waitpid(-1, &status, WNOHANG);

                // waitpid returns -1 and error ECHILD if the calling process
                // has no children

                if (pid == -1)
                {
                    assert( errno() == ECHILD );
                    assert( this.processes.length == 0 );
                    return false;
                }

                // waitpid returns 0 in the case where it would hang (if no
                // pid has changed state).
                if ( pid )
                {
                    debug ( EpollProcess )
                        Stdout.formatln("Signal fired in epoll: pid = {}", pid);

                    auto exited_ok = WIFEXITED(status);
                    int exit_code = exited_ok ? WEXITSTATUS(status) : 0;

                    auto process = pid in this.processes;
                    if ( process )
                    {
                        debug ( EpollProcess )
                            Stdout.formatln("pid {} finished, ok = {}, code = {}",
                                            pid, exited_ok, exit_code);

                        auto epoll = process.epoll;

                        process.exit(exited_ok, exit_code);

                        this.processes.remove(pid);

                        this.unregisterEpollIfFinished(epoll);
                    }

                }
            }
            while ( pid );

            return true;
        }

        /***********************************************************************

            Unregister the SIGCHLD event with epoll, if there are no more
            processes using this epoll instance

            Params:
                epoll = epoll instance to use for unregistering

        ***********************************************************************/

        private void unregisterEpollIfFinished ( EpollSelectDispatcher epoll )
        {
            foreach ( pid, process ; this.processes )
            {
                if ( process.epoll == epoll )
                {
                    return;
                }
            }

            // There are no remaining processes using this epoll instance, so
            // unregister the event.

            epoll.unregister(this.sigchild_event);

            // If there are no more processes using _any_ epoll instance,
            // disconnect the signal handler.

            if ( !this.processes.length )
            {
                this.enableSigChildHander(false);
            }
        }
    }


    /***************************************************************************

        ISelectClient implementation of an output stream. Enables a stdout or
        stderr stream to be registered with an EpollSelectDispatcher.

    ***************************************************************************/

    abstract private static class OutputStreamHandler : ISelectClient
    {
        /***********************************************************************

            Stream buffer. Receives data from stream.

        ***********************************************************************/

        private ubyte[1024] buf;


        /***********************************************************************

            Events to register for

        ***********************************************************************/

        public override Event events ( )
        {
            return Event.EPOLLIN;
        }


        /***********************************************************************

            Catches exceptions thrown by the handle() method.

            Params:
                exception = Exception thrown by handle()
                event     = Selector event while exception was caught

        ***********************************************************************/

        protected override void error_ ( Exception exception, Event event )
        {
            log.error("EPOLL error {} at {} {} event = {}", exception.toString(),
                           exception.file, exception.line, event);
        }


        /***********************************************************************

            ISelectClient handle method. Called by epoll when a read event fires
            for this stream. The stream is provided by the abstract stream()
            method.

            Data is read from the stream into this.buf and the abstract
            handle_() method is called to process the received data. The client
            is left registered with epoll unless a Hangup event occurs. Hangup
            occurs in all cases when the process which owns the stream being
            read from exits (both error and success).

            Params:
                event = event which fired in epoll

            Returns:
                true to stay registered with epoll and be called again when a
                read event fires for this stream, false to unregister.

        ***********************************************************************/

        public override bool handle ( Event event )
        {
            /* It is possible to get Event.Read _and_ Hangup
             * simultaneously. If this happens, just deal with the
             * Read. We will be called again with the Hangup.
             */

            size_t received = ( event & event.EPOLLIN ) ?
                    this.stream.read(this.buf) : 0;


            if ( received > 0 && received != InputStream.Eof )
            {
                this.handle_(this.buf[0..received]);
            }
            else
            {
                if ( event & Event.EPOLLHUP )
                {
                    return false;
                }
            }

            return true;
        }


        /***********************************************************************

            Returns:
                the stream being read from

        ***********************************************************************/

        abstract protected InputStream stream ( );


        /***********************************************************************

            Handles data received from the stream.

            Params:
                data = data received from stream

        ***********************************************************************/

        abstract protected void handle_ ( ubyte[] data );
    }


    /***************************************************************************

        Epoll stdout handler for the process being executed by the outer class.

    ***************************************************************************/

    private class StdoutHandler : OutputStreamHandler
    {
        /***********************************************************************

            Returns:
                file descriptor to register with epoll

        ***********************************************************************/

        public override Handle fileHandle ( )
        {
            return this.outer.process.stdout.fileHandle;
        }


        /***********************************************************************

            ISelectClient finalizer. Called from the epoll selector when a
            client finishes (due to being unregistered or an error).

            Calls the outer class' finalize() method.

        ***********************************************************************/

        override public void finalize ( FinalizeStatus status )
        {
            this.outer.stdoutFinalize();
        }


        /***********************************************************************

            Returns:
                the stream being read from

        ***********************************************************************/

        protected override InputStream stream ( )
        {
            return this.outer.process.stdout;
        }


        /***********************************************************************

            Handles data received from the stream, passing it to the stdout()
            method of the outer class.

            Params:
                data = data received from stream

        ***********************************************************************/

        protected override void handle_ ( ubyte[] data )
        {
            assert(!this.outer.stdout_finalized);
            this.outer.stdout(data);
        }
    }


    /***************************************************************************

        Epoll stderr handler for the process being executed by the outer class.

    ***************************************************************************/

    private class StderrHandler : OutputStreamHandler
    {
        /***********************************************************************

            Returns:
                file descriptor to register with epoll

        ***********************************************************************/

        public override Handle fileHandle ( )
        {
            return this.outer.process.stderr.fileHandle;
        }


        /***********************************************************************

            ISelectClient finalizer. Called from the epoll selector when a
            client finishes (due to being unregistered or an error).

            Calls the outer class' finalize() method.

        ***********************************************************************/

        override public void finalize ( FinalizeStatus status )
        {
            this.outer.stderrFinalize();
        }


        /***********************************************************************

            Returns:
                the stream being read from

        ***********************************************************************/

        protected override InputStream stream ( )
        {
            return this.outer.process.stderr;
        }


        /***********************************************************************

            Handles data received from the stream, passing it to the stderr()
            method of the outer class.

            Params:
                data = data received from stream

        ***********************************************************************/

        protected override void handle_ ( ubyte[] data )
        {
            assert(!this.outer.stderr_finalized);
            this.outer.stderr(data);
        }
    }


    /***************************************************************************

        Singleton instance of GlobalProcessMonitor

    ***************************************************************************/

    private mixin(global("static GlobalProcessMonitor process_monitor"));


    /***************************************************************************

        Handlers integrating the stdout & stderr of the executing process with
        epoll.

    ***************************************************************************/

    private StdoutHandler stdout_handler;

    private StderrHandler stderr_handler;


    /***************************************************************************

        Flag indicating whether the exit() method has been called.

    ***************************************************************************/

    private bool exited;


    /***************************************************************************

        Flag indicating whether the process exited normally, in which case the
        exit_code member is valid. If the process did not exit normally,
        exit_code will be 0 and invalid.

        Set by the exit() method.

    ***************************************************************************/

    private bool exited_ok;


    /***************************************************************************

        Process exit code. Set by the exit() method.

    ***************************************************************************/

    private int exit_code;


    /***************************************************************************

        Flag indicating whether the finalize() method has been called.

    ***************************************************************************/

    private bool stdout_finalized;

    private bool stderr_finalized;


    /***************************************************************************

        Epoll selector instance. Passed as a reference into the constructor.

    ***************************************************************************/

    private EpollSelectDispatcher epoll;


    /***************************************************************************

        Process state.

    ***************************************************************************/

    private enum State
    {
        None,
        Running,
        Suspended
    }

    private State state;


    /***************************************************************************

        Process being executed.

    ***************************************************************************/

    protected Process process;



    /***************************************************************************

        Constructor.

        Note: the constructor does not actually start a process, the start()
        method does that.

        Params:
            epoll = epoll selector to use

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll )
    {
        this.epoll = epoll;

        this.process = new Process;
        this.stdout_handler = new StdoutHandler;
        this.stderr_handler = new StderrHandler;

        if ( this.process_monitor is null )
        {
            debug ( EpollProcess )
                Stdout.formatln("Creating the implicit singleton process monitor");

            this.process_monitor = new GlobalProcessMonitor();
        }
    }


    /***************************************************************************

        Starts the process with the specified command and arguments. Registers
        the handlers for the process' stdout and stderr streams with epoll, so
        that notifications will be triggered when the process generates output.
        The command to execute is args_with_command[0].

        Params:
            args_with_command = command followed by arguments

    ***************************************************************************/

    public void start ( Const!(mstring)[] args_with_command )
    {
        assert(this.state == State.None); // TODO: error notification?

        this.stdout_finalized = false;
        this.stderr_finalized = false;
        this.exited = false;

        this.process.argsWithCommand(args_with_command);
        this.process.execute();

        debug ( EpollProcess )
            Stdout.formatln("Starting process pid {}, {}",
                            this.process.pid, args_with_command);

        this.epoll.register(this.stdout_handler);
        this.epoll.register(this.stderr_handler);

        this.state = State.Running;

        assert(this.process_monitor !is null,
               "Implicit singleton process monitor not initialised");
        this.process_monitor.add(this);
    }


    /***************************************************************************

        Suspends the output of a process. This is achieved simply by
        unregistering its stdout handler from epoll. This will have the effect
        that the process will, at some point, reach the capacity of its stdout
        buffer, and will then pause until the buffer has been emptied.

    ***************************************************************************/

    public void suspend ( )
    {
        if ( this.state == State.Running )
        {
            this.state = State.Suspended;

            if ( !this.stdout_finalized )
            {
                this.epoll.unregister(this.stdout_handler);
            }

            if ( !this.stderr_finalized )
            {
                this.epoll.unregister(this.stderr_handler);
            }
        }
    }


    /***************************************************************************

        Returns:
            true if the process has been suspended using the suspend() method.

    ***************************************************************************/

    public bool suspended ( )
    {
        return this.state == State.Suspended;
    }


    /***************************************************************************

        Resumes the process if it has been suspended using the suspend() method.
        The stdout handler is reregistered with epoll.

    ***************************************************************************/

    public void resume ( )
    {
        if ( this.state == State.Suspended )
        {
            this.state = State.Running;

            if ( !this.stdout_finalized )
            {
                this.epoll.register(this.stdout_handler);
            }

            if ( !this.stderr_finalized )
            {
                this.epoll.register(this.stderr_handler);
            }
        }
    }


    /***************************************************************************

        Abstract method called when data is received from the process' stdout
        stream.

        Params:
            data = data read from stdout

    ***************************************************************************/

    abstract protected void stdout ( ubyte[] data );


    /***************************************************************************

        Abstract method called when data is received from the process' stderr
        stream.

        Params:
            data = data read from stderr

    ***************************************************************************/

    abstract protected void stderr ( ubyte[] data );


    /***************************************************************************

        Abstract method called when the process has finished. Once this method
        has been called, it is guaraneteed that stdout() will not be called
        again.

        Params:
            exited_ok = if true, the process exited normally and the exit_code
                parameter is valid. Otherwise the process exited abnormally, and
                exit_code will be 0.
            exit_code = the process' exit code, if exited_ok is true. Otherwise
                0.

    ***************************************************************************/

    abstract protected void finished ( bool exited_ok, int exit_code );


    /***************************************************************************

        Called when the process' stdout handler is finalized by epoll. This
        occurs when the process terminates and all data from its stdout buffer
        has been read.

        The checkFinished() method is called once the stdoutFinished(),
        stderrFinished() and exit() methods have been called, ensuring that no
        more data will be received after this point.

    ***************************************************************************/

    private void stdoutFinalize ( )
    {
        debug ( EpollProcess ) Stdout.formatln("Finalized stdout pid {}",
                                               this.process.pid);
        this.stdout_finalized = true;
        this.checkFinished();
    }


    /***************************************************************************

        Called when the process' stderr handler is finalized by epoll. This
        occurs when the process terminates and all data from its stderr buffer
        has been read.

        The checkFinished() method is called once the stdoutFinished(),
        stderrFinished() and exit() methods have been called, ensuring that no
        more data will be received after this point.

    ***************************************************************************/

    private void stderrFinalize ( )
    {
        debug ( EpollProcess ) Stdout.formatln("Finalized stderr pid {}",
                                               this.process.pid);
        this.stderr_finalized = true;
        this.checkFinished();
    }


    /***************************************************************************

        Called when the process exits, by the process monitor that is
        responsible for this process. The process monitor, in turn, was notified
        of this via a SIGCHLD signal.

        The checkFinished() method is called once the stdoutFinished(),
        stderrFinished() and exit() methods have been called, ensuring that no
        more data will be received after this point.

        Params:
            exited_ok = if true, the process exited normally and the exit_code
                parameter is valid. Otherwise the process exited abnormally, and
                exit_code will be 0.
            exit_code = the process' exit code, if exited_ok is true. Otherwise
                0.

    ***************************************************************************/

    private void exit ( bool exited_ok, int exit_code )
    {
        debug ( EpollProcess ) Stdout.formatln("Set exit status pid {}",
                                               this.process.pid);
        this.exited_ok = exited_ok;
        this.exit_code = exit_code;
        this.exited = true;

        // We know the process has already exited, as we have explicitly been
        // notified about this by the SIGCHLD signal (handled by the
        // signalHandler() method of ProcessMonitor, above). However the
        // Process instance contains a flag (running_) which needs to be reset.
        // This can be achieved by calling wait(), which internally calls
        // waitpid() again. In this case waitpid() will return immediately with
        // an error code (as the child process no longer exists).
        this.process.wait();

        this.checkFinished();
    }


    /***************************************************************************

        Calls the protected finished() method once both the finalize() and
        exit() methods have been called, ensuring that no more data will be
        received after this point.

    ***************************************************************************/

    private void checkFinished ( )
    {
        if ( this.stdout_finalized && this.stderr_finalized && this.exited )
        {
            this.state = State.None;

            debug ( EpollProcess )
                Stdout.formatln("Streams finalised & process exited");
            this.finished(this.exited_ok, this.exit_code);
        }
    }


    /***************************************************************************

        This class exists only for backwards compatibility. It has no effect.

    ***************************************************************************/


    deprecated ("This class has no effect. All instances of this class should be removed")
    public static class ProcessMonitor
    {
        /***********************************************************************

            Constructor.

            Params:
                epoll = Not used

        ***********************************************************************/

        public this ( EpollSelectDispatcher epoll )
        {
        }

        /***********************************************************************

            This function exists only for backwards compatibility.

            Params:
                process = Not used

        ***********************************************************************/

        public void add ( EpollProcess process )
        {
        }

    }


    /***************************************************************************

        Constructor.

        Note: the constructor does not actually start a process, the start()
        method does that.

        Params:
            epoll = epoll selector to use
            process_monitor = this parameter is ignored

    ***************************************************************************/

    deprecated("Remove the unused ProcessMonitor parameter from this call")
    public this ( EpollSelectDispatcher epoll,
                  ProcessMonitor unused )
    {
        this(epoll);
    }


    /***************************************************************************

        Starts the process with the specified command and arguments. Registers
        the handlers for the process' stdout and stderr streams with epoll, so
        that notifications will be triggered when the process generates output.
        The command to execute is args_with_command[0].

        Params:
            args_with_command = command followed by arguments
            process_monitor = this parameter is ignored

    ***************************************************************************/

    deprecated("Remove the unused ProcessMonitor parameter from this call")
    public void start ( Const!(mstring)[] args_with_command,
                        ProcessMonitor process_monitor )
    {
        this.start(args_with_command);
    }

}



/*******************************************************************************

    Unit tests

*******************************************************************************/

version ( UnitTest )
{
    import ocean.core.Test;
}

unittest
{
    class MyProcess : EpollProcess
    {
        public this ( EpollSelectDispatcher epoll )
        {
            super(epoll);
        }
        protected override void stdout ( ubyte[] data ) { }
        protected override void stderr ( ubyte[] data ) { }
        protected override void finished ( bool exited_ok, int exit_code ) { }
    }

    scope epoll1 = new EpollSelectDispatcher;
    scope epoll2 = new EpollSelectDispatcher;

    // It is ok to have two different epoll instances.

    scope proc1 = new MyProcess(epoll1);

    scope proc2 = new MyProcess(epoll2);
}

