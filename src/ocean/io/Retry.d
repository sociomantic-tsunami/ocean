/*******************************************************************************

    I/O wait and retry callback manager

    Provides a simple means for trying a block of code and retrying it if
    specified conditions occur. The default condition for retrying is if any
    exceptions are thrown in the code block. Custom success conditions can be
    easily provided as a delegate to the class' constructor.

    Usage example:

    ---

        import ocean.io.Retry;

        // Create retry object.
        auto retry = new Retry;

        // Code to execute / retry.
        void doSomething ( )
        {
            // whatever
        }

        // Maximum number of times to retry code block before giving up.
        const max_retries = 10;

        // Execute / retry code block
        retry(max_retries, doSomething());

    ---

    Example using a custom delegate to determine success:

    ---

        import ocean.io.Retry;

        // Function to determine success of executed code block
        bool decide_success ( lazy void dg )
        {
            try
            {
                dg();
            }
            // Only retries on io exceptions
            catch ( IOException e )
            {
                return false;
            }

            return true;
        }

        // Create retry object.
        auto retry = new Retry(&decide_success);

        // Code to execute / retry.
        void doSomething ( )
        {
            // whatever
        }

        // Maximum number of times to retry code block before giving up.
        const max_retries = 10;

        // Execute / retry code block
        retry(max_retries, doSomething());

    ---

    An extended class, WaitRetry, implements a retryer which pauses for a
    specified length of time before each retry.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.Retry;



/*******************************************************************************

    Imports

*******************************************************************************/

import Ctime = core.sys.posix.time : nanosleep, timespec;

import core.stdc.time : time_t;



/*******************************************************************************

    Basic retrying class. Retries a specified block of code a specified number
    of times before giving up. The 'code block' is passed as a lazy bool
    parameter to the loop() / opCall() method.

    The failure condition for the block of code can be set by passing a delegate
    to the constructor. The default failure condition is that any exception
    thrown while executing the code block indicates failure.

    The behaviour of the class can be easily modified by inherting and
    overriding the following methods:

        retry_decide: decides whether to keep retrying or to give up

        on_retry: called every time a retry occurs (does nothing by default)

*******************************************************************************/

class Retry
{
    /***************************************************************************

        Alias for a delegate which executes a code block and decides if it has
        succeeded or failed.

    ***************************************************************************/

    public alias bool delegate ( lazy void ) SuccessDecider;


    /***************************************************************************

        Number of times the current code block has been retried.

    ***************************************************************************/

    private uint num_retries;


    /***************************************************************************

        Maximum number of retries before giving up on a code block. Note that 0
        represents unlimited retries.

    ***************************************************************************/

    private uint max_retries;


    /***************************************************************************

        Delegate to execute a code block and decide whether it's succeeded.

    ***************************************************************************/

    private SuccessDecider success_decide;


    /***************************************************************************

        Constructor.

        Params:
            success_decide = delegate to execute a code block and decide whether
                it's succeeded (default to null, in which case the member
                default_success_decider is used)

    ***************************************************************************/

    public this ( SuccessDecider success_decide = null )
    {
        this.success_decide = success_decide ? success_decide : &this.default_success_decide;
    }


    /***************************************************************************

        Initiates the execution and possible retrying of a block of code.

        This method is also aliased as opCall.

        Note: if max_retries == 0, then no limit to the number of retries is set

        Params:
            max_retries = maximum number of times to retry this code block
                before giving up
            dg = code block to execute / retry

    ***************************************************************************/

    public void loop ( uint max_retries, lazy void dg )
    {
        this.max_retries = max_retries;
        this.num_retries = 0;

        bool again;
        do
        {
            auto success = this.success_decide(dg);
            if ( success )
            {
                again = false;
            }
            else
            {
                this.num_retries++;
                again = this.retry_decide();

                if ( again )
                {
                    this.on_retry();
                }
            }
        }
        while ( again );
    }

    public alias loop opCall;


    /***************************************************************************

        Decides whether to keep retrying or to give up.

        Returns:
            true to continue retrying, false to give up

    ***************************************************************************/

    protected bool retry_decide ( )
    {
        return this.max_retries == 0 || this.num_retries <= this.max_retries;
    }


    /***************************************************************************

        Called before a retry is commenced. The base class behaviour does
        nothing, but it can be overridden by derived classes to implement
        special behaviour on retry.

    ***************************************************************************/

    protected void on_retry ( )
    {
    }


    /***************************************************************************

        Default success decider delegate.

        Executes the provided code block and catches any exceptions thrown.
        Success is defined as the catching of no exceptions.

        Params:
            dg = code block to execute

        Returns:
            true on success of code block, false on failure

    ***************************************************************************/

    private bool default_success_decide ( lazy void dg )
    {
        try
        {
            dg();
            return true;
        }
        catch ( Exception e )
        {
            return false;
        }
    }
}



/*******************************************************************************

    Retrying class which waits for a specified amount of time before each retry.

*******************************************************************************/

class WaitRetry : Retry
{
    /***************************************************************************

        Number of milliseconds to wait before each retry.

    ***************************************************************************/

    private uint retry_wait_ms;


    /***************************************************************************

        Constructor.

        Params:
            retry_wait_ms = time (in ms) to wait before each retry
            success_decide = delegate to execute a code block and decide whether
                it's succeeded (default to null, in which case the member
                default_success_decider is used)

    ***************************************************************************/

    public this ( uint retry_wait_ms, SuccessDecider success_decide = null )
    {
        this.retry_wait_ms = retry_wait_ms;

        super(success_decide);
    }


    /***************************************************************************

        Wait on retry.

    ***************************************************************************/

    override protected void on_retry ( )
    {
        sleep(this.retry_wait_ms);
    }


    /***************************************************************************

        Sleep in a multi-thread compatible way.
        sleep() in multiple threads is not trivial because when several threads
        simultaneously sleep and the first wakes up, the others will instantly
        wake up, too. See nanosleep() man page

        http://www.kernel.org/doc/man-pages/online/pages/man2/nanosleep.2.html

        or

        http://www.opengroup.org/onlinepubs/007908799/xsh/nanosleep.html

        Params:
            ms = milliseconds to sleep

    ***************************************************************************/

    public static void sleep ( time_t ms )
    {
        auto ts = Ctime.timespec(ms / 1_000, (ms % 1_000) * 1_000_000);

        while (Ctime.nanosleep(&ts, &ts)) {}
    }
}

