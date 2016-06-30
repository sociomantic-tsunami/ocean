/*******************************************************************************

    SafeFork

    Offers some wrappers for the usage of fork to call expensive blocking
    functions without interrupting the main process and without the need to
    synchronize.

    Useful version switches:
        TimeFork = measures and displays the time taken by the linux fork() call

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.SafeFork;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.sys.ErrnoException;

import ocean.stdc.posix.stdlib : exit;

import ocean.stdc.posix.unistd : fork;

import ocean.stdc.posix.sys.wait;

import ocean.stdc.posix.signal;

import ocean.stdc.errno;

import ocean.stdc.string;



/*******************************************************************************

    Imports for TimeFork version

*******************************************************************************/

version ( TimeFork )
{
    import ocean.io.Stdout;

    import ocean.time.StopWatch;
}



/*******************************************************************************

    External C

    // TODO: forced to be public to be used with reflection, must be moved to
        C bindings

*******************************************************************************/

extern (C)
{
    enum idtype_t
    {
      P_ALL,        /* Wait for any child.  */
      P_PID,        /* Wait for specified process.  */
      P_PGID        /* Wait for members of process group.  */
    };

    int waitid(idtype_t, id_t, siginfo_t*, int);

    const WEXITED = 0x00000004;
    const WNOWAIT = 0x01000000;
}



/*******************************************************************************

    SafeFork

    Offers some wrappers for the usage of fork to call expensive blocking
    functions without interrupting the main process and without the need to
    synchronize.

    Usage Example:
    -----
    import ocean.sys.SafeFork;

    void main ( )
    {
        auto dont_block = new SafeFork(&blocking_function);

        dont_block.call(); // call blocking_function

        if ( !dont_block.call() )
        {
            Stdout("blocking function is currently running and not done yet!");
        }

        while ( dont_block.isRunning() )
        {
            Stdout("blocking function is still running!");
        }

        if ( !dont_block.call() )
        {
            Stdout("blocking function is currently running and not done yet!");
        }

        dont_block.call(true); // wait for a unfinished fork and then call
                               // blocking_function without forking
    }
    -----

*******************************************************************************/

public class SafeFork
{
    /***************************************************************************

        Exception, reusable

    ***************************************************************************/

    private ErrnoException exception;

    /***************************************************************************

        Pid of the forked child

    ***************************************************************************/

    private int child_pid = 0;

    /***************************************************************************

        Delegate to call

    ***************************************************************************/

    private void delegate () dg;

    /***************************************************************************

        Constructor

        Params:
            dg = delegate to call

    ***************************************************************************/

    public this ( void delegate () dg )
    {
        this.dg = dg;

        this.exception = new ErrnoException;
    }

    /***************************************************************************

        Find out whether the fork is still running or not

        Returns:
            true if the fork is still running, else false

    ***************************************************************************/

    public bool isRunning ( )
    {
        return this.child_pid == 0
            ? false
            : this.isRunning(false, false);
    }

    /***************************************************************************

        Call the delegate, possibly within a fork.
        Ensures that the delegate will only be called when there is not already
        a fork running. The fork exits after the delegate returned.

        Note that the host process is not informed about any errors in
        the forked process.

        Params:
            block = if true, wait for a currently running fork and don't fork
                             when calling the delegate
                    if false, don't do anything when a fork is currently running

        Returns:
            true when the delegate was called

        See_Also:
            SafeFork.isRunning

    ***************************************************************************/

    public bool call ( bool block = false )
    {
        if ( this.child_pid == 0 || !this.isRunning(block) )
        {
            if ( block )
            {
                version ( TimeFork )
                {
                    Stdout.formatln("Running task without forking...");
                }
                this.dg();

                this.child_pid = 0;

                return true;
            }
            else
            {
                version ( TimeFork )
                {
                    Stdout.formatln("Running task in fork...");
                    StopWatch sw;
                    sw.start;
                }

                this.child_pid = fork();

                version ( TimeFork )
                {
                    Stdout.formatln("Fork took {}s",
                        (cast(float)sw.microsec) / 1_000_000.0f);
                }

                this.exception.enforce(this.child_pid >= 0, "failed to fork");

                if ( this.child_pid == 0 )
                {
                    this.dg();
                    exit(0);
                }

                return true;
            }
        }
        else
        {
            return false;
        }
    }

    /***************************************************************************

        Checks whether the forked process is already running.

        Params:
            block = if true, wait for a currently running fork
                    if false, don't do anything when a fork is currently running
            clear = if true, the waiting status of the forked process is cleared

        Returns:
            true if the forked process is running

        See_Also:
            SafeFork.isRunning

    ***************************************************************************/

    private bool isRunning ( bool block, bool clear = true )
    {
        if ( this.child_pid < 0 )
            return false;

        siginfo_t siginfo;

        this.exception.enforceRetCode!(waitid)().call(
            idtype_t.P_PID, this.child_pid, &siginfo,
                 WEXITED | (block ? 0 : WNOHANG) | (clear ? 0 : WNOWAIT)
        );

        return siginfo._sifields._kill.si_pid == 0;
    }
}

