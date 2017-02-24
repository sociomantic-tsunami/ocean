/*******************************************************************************

    Timer event which can be registered with the EpollSelectDispatcher.

    Note that the unittest in this module requires linking with librt.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.client.TimerEvent;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.io.select.client.model.ISelectClient: ISelectClient;

import ocean.sys.TimerFD;
import ocean.core.Traits;

import ocean.transition;
import ocean.io.model.IConduit: ISelectable;

import core.sys.posix.time: time_t, timespec, itimerspec;

/*******************************************************************************

    TimerEvent class, calls the provided delegate when the timer fires and is
    handled in epoll.

    Usage example:
        See documented unittest after class

*******************************************************************************/

class TimerEvent : ITimerEvent
{
    /***************************************************************************

        Alias for event handler delegate.

        Returns:
            true to stay registered in epoll or false to unregister.

    ***************************************************************************/

    public alias bool delegate ( ) Handler;

    /***************************************************************************

        Event handler delegate.

    ***************************************************************************/

    private Handler handler;

    /***********************************************************************

        Constructor. Creates a file descriptor to manage the event.

        Constructor. Creates a custom event and hooks it up to the provided
        event handler.

        Params:
            handler = event handler

    ***********************************************************************/

    public this ( Handler handler, bool realtime = false )
    {
        super(realtime);

        this.handler = handler;
    }

    /***************************************************************************

        Called from the select dispatcher when the event fires. Calls the user-
        provided event handler.

        Params:
            event = select event which fired, must be Read

        Returns:
            forwards return value of event handler -- false indicates that the
            event should be unregistered with the selector, true indicates that
            it should remain registered and able to fire again

    ***************************************************************************/

    protected override bool handle_ ( ulong n )
    in
    {
        assert(this.handler);
    }
    body
    {
        return this.handler();
    }

    /***********************************************************************

        Set a new handler

        Params:
            handler = event handler

    ***********************************************************************/

    public void setHandler ( Handler handler )
    {
        this.handler = handler;
    }
}

version ( UnitTest )
{
    import ocean.io.select.EpollSelectDispatcher;
}

/// TimerEvent usage example
unittest
{
    // Delegate which will be called each time the timer fires and is handled in
    // epoll
    bool my_timer_dg ( )
    {
        return true; // to keep timer registered (false to unregister)
    }

    auto epoll = new EpollSelectDispatcher;
    auto timer = new TimerEvent(&my_timer_dg);
    timer.set(1, 0, 1, 0); // repeating timer, fires every 1s
    epoll.register(timer);

    // TODO: epoll.eventLoop();
    // (The timer event may fire but will not be handled until the event loop is
    // running.)
}


/*******************************************************************************

    ITimerEvent base class with abstract handle method.

*******************************************************************************/

abstract class ITimerEvent : ISelectClient, ISelectable
{
    /***************************************************************************

        Convenience and compatibility alias.

    ***************************************************************************/

    public alias TimerFD.TimerException TimerException;

    /***************************************************************************

        Integer file descriptor provided by the operating system and used to
        manage the custom event.

    ***************************************************************************/

    private TimerFD fd;

    /***********************************************************************

        Constructor. Creates a file descriptor to manage the event.

        Params:
            realtime = true:  use a settable system-wide clock.
                       false: use a non-settable clock that is not affected by
                       discontinuous changes in the system clock (e.g., manual
                       changes to system time).

    ***********************************************************************/

    protected this ( bool realtime = false )
    {
        this.fd = new TimerFD(realtime);
    }

    /***************************************************************************

        Returns:
            the epoll events to register for.

    ***************************************************************************/

    public override Event events ( )
    {
        return Event.EPOLLIN;
    }

    /***************************************************************************

        Returns:
            the value of the TimerFD's absolute flag (true = absolute timer,
            false = relative timer)

    ***************************************************************************/

    public bool absolute ( )
    {
        return this.fd.absolute;
    }

    /***************************************************************************

        Sets the timer to absolute or relative mode.

        Params:
            abs = the value of the TimerFD's absolute flag (true = absolute
                timer, false = relative timer)

    ***************************************************************************/

    public void absolute ( bool abs )
    {
        this.fd.absolute = abs;
    }

    /***************************************************************************

        Timer expiration event handler.

        Params:
            n =  number of  expirations that have occurred

        Returns:
            true to stay registered in epoll or false to unregister.

    ***************************************************************************/

    abstract protected bool handle_ ( ulong n );

    /***********************************************************************

        Returns the next expiration time.

        Returns:
            itimerspec instance containing the next expiration time.
            - it_value: the amount of time until the timer will next expire. If
                 both fields are zero, then the timer is currently disarmed.
                 Contains always a relative value.
            - it_interval: the interval of the timer. If both fields are zero,
                 then the timer is set to expire just once, at the time
                 specified by it_value.

     ***********************************************************************/

    public itimerspec time ( )
    {
        return this.fd.time;
    }

    /***************************************************************************

        Sets next expiration time of interval timer.

        Params:
            first =    Specifies the initial expiration of the timer. Setting
                       either field to a non-zero value arms the timer. Setting
                       both fields to zero disarms the timer.

            interval = Setting one or both fields to non-zero values specifies
                       the period for repeated timer expirations after the
                       initial expiration. If both fields are zero, the timer
                       expires just once, at the time specified by it_value.

        Returns:
            the previous expiration time as time().

     **************************************************************************/

    public itimerspec set ( timespec first, timespec interval = timespec.init )
    {
        return this.fd.set(first, interval);
    }

    /***************************************************************************

        Sets next expiration time of interval timer.

        Setting first_s or first_ms to a non-zero value arms the timer. Setting
        both to zero disarms the timer.
        If both interval_s and interval_,s are zero, the timer expires just
        once, at the time specified by first_s and first_ms.


        Params:
            first_s     = Specifies the number of seconds of the initial
                          expiration of the timer.

            first_ms    = Specifies an amount of milliseconds that will be added
                          to first_s.

            interval_s = Specifies the number of seconds of the period for
                          repeated timer expirations after the initial
                          expiration.

            interval_ms = Specifies an amount of milliseconds that will be added
                          to interval_ms.

        Returns:
            the previous expiration time as time().

     **************************************************************************/

    public itimerspec set ( time_t first_s,        uint first_ms,
                            time_t interval_s = 0, uint interval_ms = 0 )
    {
        return this.fd.set(first_s, first_ms, interval_s, interval_ms);
    }

    /***************************************************************************

        Resets/disarms the timer.

        Returns:
            Returns the previous expiration time as time().

     **************************************************************************/

    public itimerspec reset ( )
    {
        return this.fd.reset();
    }

    /***********************************************************************

        Required by ISelectable interface.

        Returns:
            file descriptor used to manage custom event

    ***********************************************************************/

    public override Handle fileHandle ( )
    {
        return this.fd.fileHandle;
    }

    /***************************************************************************

        Event handler, invoked by the epoll select dispatcher.

        Params:
            event = event(s) reported by epoll

        Returns:
            true to stay registered in epoll or false to unregister.

    ***************************************************************************/

    final override bool handle ( Event event )
    {
        return this.handle_(this.fd.handle());
    }

    /***************************************************************************

        Returns an identifier string for this instance

        Returns:
            identifier string for this instance

    ***************************************************************************/

    debug
    {
        import ocean.core.Array : copy;
        import ocean.text.convert.Formatter;

        private mstring time_buffer;

        public override cstring id ( )
        {
            this.time_buffer.copy(super.id());
            auto time = this.time();

            sformat(this.time_buffer, ": {}s {}ns",
                time.it_value.tv_sec, time.it_value.tv_nsec);
            return this.time_buffer;
        }
    }
}


version ( UnitTest )
{
    import ocean.core.Test;
    import core.sys.posix.time;

    extern ( C )
    {
        alias int clockid_t;
        int clock_gettime(clockid_t, timespec*);
    }

    class TestTimerEvent : ITimerEvent
    {
        override protected bool handle_ ( ulong n )
        {
            assert(false);
        }
    }
}


/*******************************************************************************

    Test for setting absolute timers

*******************************************************************************/

unittest
{
    timespec now;
    clock_gettime(ocean.sys.TimerFD.CLOCK_MONOTONIC, &now);

    auto timer = new TestTimerEvent;
    timer.absolute = true;

    auto set_time = now;
    set_time.tv_sec += 10;
    timer.set(set_time);

    auto get_time = timer.time();
    ulong nsec = (get_time.it_value.tv_sec * 1_000_000_000)
        + get_time.it_value.tv_nsec;

    test!("<=")(nsec, 10_000_000_000);
}
