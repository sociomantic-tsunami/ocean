/*******************************************************************************

    Support for app-level timers.

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.application.components.Timers;

/// ditto
public class Timers
{
    import ocean.core.Verify;
    import ocean.io.select.EpollSelectDispatcher;
    import ocean.io.select.client.TimerSet;
    import ocean.task.Scheduler;
    import ocean.time.MicrosecondsClock;
    import ocean.time.timeout.TimeoutManager;
    import BucketElementFreeList = ocean.util.container.map.model.BucketElementFreeList;
    import ocean.util.log.Logger;

    /// Static logger.
    static private Logger log;

    /***************************************************************************

        Static constructor.

    ***************************************************************************/

    static this ( )
    {
        log = Log.lookup("ocean.application.components.Timers");
    }

    /// Type of delegate called when an event fires. The delegate's return value
    /// indicates whether the timed event should remain registered (true) or be
    /// unregistered (false).
    public alias bool delegate ( ) EventDg;

    /// Data stored for each event registered with the internal timer set (see
    /// below).
    private struct EventData
    {

        /// Delegate to call when event fires.
        public EventDg dg;

        /// Period after which event should fire again. (Note that we need to
        /// store this because timer set events are one-off, unlike
        /// TimerEvents.)
        public ulong repeat_microsec;

        /// The expected time of the next call for the timer.
        public ulong next_call;
    }

    /***************************************************************************

        Internal timer set used to track the set of timed events. A timer set
        is used to avoid the need for managing a set of TimerEvents, one per
        registered event.

    ***************************************************************************/

    private TimerSet!(EventData) timer_set;

    /***************************************************************************

        Constructor. Creates the internal event timer set.

    ***************************************************************************/

    public this ( )
    {
        this(theScheduler.epoll);
    }

    /***************************************************************************

        Constructor. Creates the internal event timer set.

        Params:
            epoll = select dispatcher with which to register the timer set

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll )
    {
        this.timer_set = new TimerSet!(EventData)(epoll, 0,
            BucketElementFreeList.instantiateAllocator!(TimeoutManagerBase.ExpiryToClient));
    }

    /***************************************************************************

        Registers a timer with the extension. The provided delegate will be
        called repeatedly according to the specified period, as long as it
        returns true.

        Params:
            dg = delegate to call periodically
            period_s = seconds between calls of the delegate

    ***************************************************************************/

    public void register ( scope EventDg dg, double period_s )
    {
        verify(dg !is null);
        verify(period_s >= 0.0);
        this.registerMicrosec(dg, secToMicrosec(period_s), secToMicrosec(period_s));
    }

    /***************************************************************************

        Registers a timer with the extension. The provided delegate will be
        called once after the initial delay specified, then repeatedly according
        to the specified period, as long as it returns true.

        Params:
            dg = delegate to call periodically
            init_s = seconds before initial call of the delegate
            period_s = seconds between subsequent calls of the delegate

    ***************************************************************************/

    public void register ( scope EventDg dg, double init_s, double period_s )
    {
        verify(dg !is null);
        verify(init_s >= 0.0);
        verify(period_s >= 0.0);

        this.registerMicrosec(dg, secToMicrosec(init_s), secToMicrosec(period_s));
    }

    /***************************************************************************

        Registers a timer with the extension. The provided delegate will be
        called once after the initial delay specified, then repeatedly according
        to the specified period, as long as it returns true.

        Note that this internal method is called both from the public register()
        methods and the private eventFired().

        Params:
            dg = delegate to call periodically
            init_microsec = microseconds before initial call of the delegate
            period_microsec = microseconds between subsequent calls of the
                delegate

    ***************************************************************************/

    public void registerMicrosec ( scope EventDg dg, ulong init_microsec, ulong period_microsec )
    {
        verify(dg !is null);

        this.timer_set.schedule(
            ( ref EventData event )
            {
                event.dg = dg;
                event.repeat_microsec = period_microsec;
                event.next_call = MicrosecondsClock.now_us() + init_microsec;
            },
            &this.eventFired, init_microsec);
    }

    /***************************************************************************

        Unregisters all timed events (thus unregisters the internal TimerEvent
        from epoll).

    ***************************************************************************/

    public void clear ( )
    {
        this.timer_set.clear();
    }

    /***************************************************************************

        Internal delegate called when a scheduled event fires. Calls the user's
        delegate and re-schedules the event after the specified period. If the
        time spent in user's delegate is longer than the interval then delegate
        calls for those intervals will be skipped.

        Params:
            event = data attached to the event which fired

    ***************************************************************************/

    private void eventFired ( ref EventData event )
    {
        bool reregister = true; // by default, always stay registered

        try
        {
            reregister = event.dg();
        }
        catch (Exception e)
        {
            try
            {
                log.error("Unhnandled exception in TimerExt's callback: {}",
                        e.message());
            }
            catch (Exception)
            {
                // ignore the potential logger failure, keep the timerset running
            }
        }

        if ( reregister )
        {
            do
            {
                event.next_call += event.repeat_microsec;
            }
            while ( event.next_call < MicrosecondsClock.now_us() );

            auto ms_till = event.next_call - MicrosecondsClock.now_us();
            this.registerMicrosec(event.dg, ms_till, event.repeat_microsec);
        }
    }

    /***************************************************************************

        Converts the provided floating point time in seconds to an integer time
        in microseconds.

        Params:
            time_s = floating point time in seconds

        Returns:
            corresponding integer time in microseconds

    ***************************************************************************/

    private static ulong secToMicrosec ( double time_s )
    {
        return cast(ulong)(time_s * 1_000_000);
    }
}
