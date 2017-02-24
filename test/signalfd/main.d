/*******************************************************************************

    Copyright:      Copyright (c) 2014 sociomantic labs. All rights reserved

    Unittests for SignalFD. The tests involve signals (obviously) and forking
    processes, so are placed in this slowtest module.

    FLAKY: the unittests in this module are very flaky, as they rely on making
    various system calls (fork(), waitpid(), epoll_wait(), epoll_ctl(), etc)
    which could, under certain environmental conditions, fail.

*******************************************************************************/

module test.signalfd.main;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.sys.SignalFD;

import ocean.core.Test;

import ocean.sys.Epoll;
import ocean.sys.SignalMask;

import ocean.transition;
import ocean.core.Array : contains;

import core.sys.posix.signal : kill, pid_t, sigaction, sigaction_t,
    SIGHUP, SIGINT, SIGQUIT, SIGILL, SIGABRT, SIGBUS;
import core.sys.posix.stdlib : exit;
import core.sys.posix.unistd : fork;
import ocean.stdc.posix.sys.wait : waitpid;



/*******************************************************************************

    Class to perform a single test on SignalFD.

*******************************************************************************/

private class SignalFDTest
{
    /***************************************************************************

        Maximum signal which can be handled during tests. This is due to the
        need to use a fixed-length array (see SigHandler.handled()).

    ***************************************************************************/

    private const max_signal = 32;


    /***************************************************************************

        SignalFD instance being tested. The test does not modify it, only uses
        it.

    ***************************************************************************/

    private SignalFD signal_fd;


    /***************************************************************************

        List of signals to be tested but which the SignalFD does *not* handle.

    ***************************************************************************/

    private int[] non_handled_signals;


    /***************************************************************************

        Child process' id. Set when the process is forked, in run().

    ***************************************************************************/

    private pid_t pid;


    /***************************************************************************

        Constructor. Sets this.non_handled_signals and runs the test.

        Params:
            signal_fd = SignalFD instance to test
            signals = list of signals to send during test

    ***************************************************************************/

    public this ( SignalFD signal_fd, int[] signals )
    {
        this.signal_fd = signal_fd;

        foreach ( signal; signals )
        {
            if ( !signal_fd.isRegistered(signal) )
            {
                this.non_handled_signals ~= signal;
            }
        }

        this.run();
    }


    /***************************************************************************

        Returns:
            the list of signals handled by this.signal_fd

    ***************************************************************************/

    private int[] handled_signals ( )
    {
        return this.signal_fd.registered_signals;
    }


    /***************************************************************************

        Non-fd signal handler. Required in order to confirm that the SignalFD is
        not handling signals which it is not supposed to handle.

    ***************************************************************************/

    private static class SigHandler
    {
        /***********************************************************************

            Signal to be handled.

        ***********************************************************************/

        private int signal;


        /***********************************************************************

            Previous handler for this signal. Can be restored by the restore()
            method.

        ***********************************************************************/

        private sigaction_t old_handler;


        /***********************************************************************

            Constructor. Registers a new signal handler for the specified
            signal. The handler, when it fires, simply registers the fact that
            the signal has been fired, in the static fired_signals array.

            Params:
                signal = signal to handle

        ***********************************************************************/

        public this ( int signal )
        {
            this.signal = signal;
            sigaction_t handler;
            handler.sa_handler = &typeof(this).handler;
            auto sigaction_res = sigaction(this.signal, &handler, &this.old_handler);

            // Reset the static list of fired signals, so that it is clear at
            // the beginning of each test
            foreach ( ref fired; typeof(this).fired_signals )
            {
                fired = false;
            }
        }


        /***********************************************************************

            Restores the previous handler for this signal.

        ***********************************************************************/

        public void restore ( )
        {
            sigaction(this.signal, &this.old_handler, null);
        }


        /***********************************************************************

            List of flags, set to true when the signal corresponding to the
            array index has fired and been handled by this class (see
            handler(), below).

            Note that the array is static (and fixed-length) because it is
            accessed from an interrupt handler, thus could be called in the
            middle of GC activity.

        ***********************************************************************/

        private static bool[max_signal] fired_signals;


        /***********************************************************************

            Signal handler. Adds the specified signal to the static list of
            signals which have fired.

            Params:
                signal = signal which fired

        ***********************************************************************/

        extern ( C ) private static void handler ( int signal )
        {
            if ( signal < max_signal )
            {
                typeof(this).fired_signals[signal] = true;
            }
        }


        /***********************************************************************

            Tells whether the specified signal has fired.

            Params:
                signal = signal to check

            Returns:
                true if the signal has fired

        ***********************************************************************/

        public static bool fired ( int signal )
        in
        {
            assert(signal < max_signal);
        }
        body
        {
            return typeof(this).fired_signals[signal];
        }
    }


    /***************************************************************************

        Runs the test, setting up normal (i.e. non-fd) signal handlers for all
        signals which are to be tested but which are not handled by
        this.signal_fd, and then forking the process in order to be able to send
        signals to the child process.

    ***************************************************************************/

    private void run ( )
    {
        SigHandler[] handlers;
        auto sigset = SignalSet.getCurrent();

        scope ( exit )
        {
            foreach ( handler; handlers )
            {
                handler.restore();
            }

            sigset.remove(this.handled_signals);
            sigset.mask();
        }

        // Set up normal (i.e. non-fd) handler for non-handled signals.
        foreach ( signal; this.non_handled_signals )
        {
            handlers ~= new SigHandler(signal);
        }

        // Prevent signal handler from handling SIGHUP.
        // (This is necessary because the parent process sends this signal to
        // the child immediately after forking. The child has, however, not
        // immediately set up its signalfd and epoll instances, meaning that the
        // signal will be handled by the default signal handler, breaking the
        // unittest. Masking the signal handler first means that the signal will
        // fire immediately when the child process' signalfd is set up and
        // registered with epoll.)
        // The signals are unmasked again when the test is over (see
        // scope(exit), above), in order to not affect subsequent tests.
        sigset.add(this.handled_signals);
        sigset.block();
        this.pid = fork();
        // FLAKY: call to fork() may fail
        test!(">=")(this.pid, 0); // fork() error

        if ( this.pid == 0 )
        {
            this.child();
        }
        else
        {
            this.parent();
        }
    }


    /***************************************************************************

        Parent process' behaviour. Sends all specified signals to the child then
        waits for the child process to exit and checks its exit status. A
        non-zero exit status indicates that the child process exited with an
        exception, meaning that the test failed.

    ***************************************************************************/

    private void parent ( )
    {
        // Send specified signals to child.
        foreach ( signal;
            this.handled_signals ~ this.non_handled_signals )
        {
            kill(this.pid, signal);
        }

        // Wait for the child process to exit. The exit status should be 0,
        // otherwise an exception has been thrown in the child process.
        int child_exit_status;
        auto wait_pid_res = waitpid(this.pid, &child_exit_status, 0);
        // FLAKY: call to waitpid() may fail or return an invalid pid
        test!("!=")(wait_pid_res, -1); // waitpid() error
        test!("==")(wait_pid_res, this.pid); // waitpid() returned wrong pid
        test!("==")(child_exit_status, 0);
    }


    /***************************************************************************

        Child process' behaviour. Sets up an epoll instance and registers the
        SignalFD instance with it, ready to receive notifications of signals
        which have fired. When the fd fires, tests are performed to check that
        the correct set of signals have been handled in the expected way. If all
        tests succeed, the child process is exited with status code 0.
        Otherwise, an exception is thrown, which will cause the child process to
        exit with a non-zero status.

    ***************************************************************************/

    private void child ( )
    {
        // Register this.signal_fd with epoll
        Epoll epoll;
        epoll.create();
        epoll.ctl(Epoll.CtlOp.EPOLL_CTL_ADD,
            this.signal_fd.fileHandle(),
            Epoll.Event.EPOLLIN, this.signal_fd);

        // Start the epoll event loop, in order to be notified when the signals
        // have fired
        epoll_event_t[1] fired_events;
        const int timeout_ms = 100; // just in case
        auto epoll_res = epoll.wait(fired_events, timeout_ms);
        // FLAKY: call to epoll_wait() may fail or return wrong number of events
        test!("!=")(epoll_res, -1); // epoll_wait() error
        test!("==")(epoll_res, 1); // one event fired
        assert(fired_events[0].data.obj is signal_fd, "unexpected event data");

        // Allow this.signal_fd to handle the signals which have fired
        SignalFD.SignalInfo[] siginfos;
        this.signal_fd.handle(siginfos);
        assert(siginfos.length == this.handled_signals.length, "handled signals "
            "count wrong");

        // Create a list of the signals which were handled
        int[] fired_signals;
        foreach ( siginfo; siginfos )
        {
            fired_signals ~= siginfo.ssi_signo;
        }

        // Check that all signals which the fd was expected to handle have been
        // handled, and that all signals which the fd was not expected to handle
        // have been handled by the normal signal handler.
        foreach ( signal; this.handled_signals )
        {
            test(fired_signals.contains(signal),
                "fd-handled signal not caught by fd");
            test(!SigHandler.fired(signal),
                "fd-handled signal caught by normal handler function");
        }

        // Check that all signals which the fd was not expected to handle have
        // been handled by the normal signal handler, and that all signals which
        // the fd was expected to handle have not been handled by the normal
        // signal handler.
        foreach ( signal; this.non_handled_signals )
        {
            test(!fired_signals.contains(signal), "signal caught by fd");
            test(SigHandler.fired(signal),
                "signal not caught by normal handler function");
        }

        exit(0);
    }
}



/*******************************************************************************

    Dummy main (required by compiler).

*******************************************************************************/

void main ( )
{
}


/*******************************************************************************

    unittests where the set of signals being handled by the SignalFD is set in
    the ctor.

*******************************************************************************/

unittest
{
    // Test a single signal handled by a signalfd
    new SignalFDTest(new SignalFD([SIGHUP]), [SIGHUP]);

    // Test multiple signals handled by a signalfd
    new SignalFDTest(new SignalFD([SIGHUP, SIGINT, SIGQUIT]),
        [SIGHUP, SIGINT, SIGQUIT]);

    // Test a single signal handled by a signalfd and a single signal which is
    // not handled
    new SignalFDTest(new SignalFD([SIGHUP]), [SIGHUP, SIGINT]);

    // Test multiple signals handled by a signalfd and multiple signals which
    // are not handled
    new SignalFDTest(new SignalFD([SIGHUP, SIGINT, SIGQUIT]),
        [SIGHUP, SIGINT, SIGQUIT, SIGILL, SIGABRT, SIGBUS]);
}


/*******************************************************************************

    unittests where the set of signals being handled by the SignalFD is set
    after construction.

*******************************************************************************/

unittest
{
    // Test a single signal handled by a signalfd
    {
        auto signalfd = new SignalFD([]);
        signalfd.register(SIGHUP);
        new SignalFDTest(signalfd, [SIGHUP]);
    }

    // Test multiple signals handled by a signalfd
    {
        auto signalfd = new SignalFD([]);
        signalfd.register(SIGHUP).register(SIGINT).register(SIGQUIT);
        new SignalFDTest(signalfd, [SIGHUP, SIGINT, SIGQUIT]);
    }

    // Test a single signal handled by a signalfd and a single signal which is
    // not handled
    {
        auto signalfd = new SignalFD([]);
        signalfd.register(SIGHUP);
        new SignalFDTest(signalfd, [SIGHUP, SIGINT]);
    }

    // Test multiple signals handled by a signalfd and multiple signals which
    // are not handled
    {
        auto signalfd = new SignalFD([]);
        signalfd.register(SIGHUP).register(SIGINT).register(SIGQUIT);
        new SignalFDTest(signalfd, [SIGHUP, SIGINT, SIGQUIT, SIGILL, SIGABRT,
            SIGBUS]);
    }

    // Test extending the set of handled signals after an initial test
    {
        auto signalfd = new SignalFD([]);
        signalfd.register(SIGHUP).register(SIGINT).register(SIGQUIT);
        new SignalFDTest(signalfd, [SIGHUP, SIGINT, SIGQUIT]);

        signalfd.register(SIGILL).register(SIGABRT).register(SIGBUS);
        new SignalFDTest(signalfd, [SIGHUP, SIGINT, SIGQUIT, SIGILL, SIGABRT,
            SIGBUS]);
    }
}
