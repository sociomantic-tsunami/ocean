/*******************************************************************************

    Manages ITimeoutClient instances where each one has an individual timeout
    value. Uses a timer event as timeout notification mechanism.

    Objects that can time out, the so-called timeout clients, must implement
    ITimeoutClient. For each client create an ExpiryRegistration instance and
    pass the object to the ExpiryRegistration constructor.
    Call ExpiryRegistration.register() to set a timeout for the corresponding
    client. The timeout() method of each client is then called when it has
    timed out.
    To disable the timeout for a client that has not timed out yet, call
    ExpiryRegistration.unregister() .

    Initially the object returned by TimerEventTimeoutManager.select_client
    must be registered to an epoll select dispatcher.

    Link with:
        -Llibebtree.a

    Build flags:
        -debug=TimeoutManager = verbose output

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.timeout.TimerEventTimeoutManager;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.time.timeout.TimeoutManager;

import ocean.io.select.client.TimerEvent;

import ocean.io.select.client.model.ISelectClient;

import core.sys.posix.time: time_t, timespec;

debug
{
    import core.stdc.time: ctime;
    import ocean.io.Stdout_tango;
}

import ocean.util.log.Log;

/*******************************************************************************

    Static module logger

*******************************************************************************/

private Logger log;

static this ( )
{
    log = Log.lookup("ocean.io.select.timeout.TimerEventTimeoutManager");
}

/******************************************************************************/

class TimerEventTimeoutManager : TimeoutManager
{
    /***************************************************************************

        TimerEvent for absolute real-time that calls checkTimeouts() when fired.

    ***************************************************************************/

    private class TimerEvent : ITimerEvent
    {
        /***********************************************************************

            Constructor

        ***********************************************************************/

        this ( )
        {
            super(true); // use real-time
            super.absolute = true; // use absolute time
        }

        /***********************************************************************

            Called when the timer event fires; notifies and unregisters the
            timed out clients.

            Params:
                n = expiration counter (unused, mandatory)

            Returns:
                true to stay registered in the epoll select dispatcher.

        ***********************************************************************/

        protected override bool handle_ ( ulong n )
        {
            debug ( TimeoutManager ) Stderr("******** " ~ typeof (this.outer).stringof ~ " expired\n").flush();

            this.outer.checkTimeouts();
            return true;
        }
    }

    /***************************************************************************

        TimerEvent instance

    ***************************************************************************/

    private TimerEvent event;

    /***************************************************************************

        Constructor

    ***************************************************************************/

    public this ( )
    {
        this.event = this.new TimerEvent;
    }


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Called immediately when this instance is deleted.
            (Must be protected to prevent an invariant from failing.)

        ***********************************************************************/

        protected override void dispose ( )
        {
            delete this.event;
        }
    }


    /***************************************************************************

        Returns:
            the timer event instance to register in an epoll select dispatcher.

    ***************************************************************************/

    public ISelectClient select_client ( )
    {
        return this.event;
    }

    /***************************************************************************

        Enables or changes the timer event time.

        Params:
            next_expiration_us = wall clock time when the next client will time
                                 out as UNIX time in microseconds.

    ***************************************************************************/

    protected override void setTimeout ( ulong next_expiration_us )
    {
        timespec ts = timespec(cast (time_t) (next_expiration_us / 1_000_000),
                               cast (uint)   (next_expiration_us % 1_000_000) * 1000);

        this.event.set(ts);
    }

    /***************************************************************************

        Disables the timer event.

    ***************************************************************************/

    protected override void stopTimeout ( )
    {
        this.event.reset();
    }
}
