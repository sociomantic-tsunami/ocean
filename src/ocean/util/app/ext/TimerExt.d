/*******************************************************************************

    Application extension for handling user-defined timed or repeating events.

    Internally, the extension uses a timer set to manage the set of timed
    events. The internal timer set's TimerEvent instance is registered with
    epoll when one or more timed events are registered. When no timed events are
    registered, the TimerEvent is not registered.

    Due to its internal use of epoll, this extension requires an epoll instance
    to be passed to its constructor. This is unlike the SignalExt, which the
    user must manually register with epoll.

    Usage example:
        See documented unittest below.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.ext.TimerExt;


/*******************************************************************************

    Example of using the TimerExt in an application class.

*******************************************************************************/

version ( UnitTest )
{
    import ocean.util.app.Application;
}

///
unittest
{
    class App : Application
    {
        import ocean.io.select.EpollSelectDispatcher;
        import ocean.transition;

        private EpollSelectDispatcher epoll;
        private TimerExt timers;

        public this ( )
        {
            super("", "");

            this.epoll = new EpollSelectDispatcher;
            this.timers = new TimerExt(this.epoll);
            this.registerExtension(this.timers);
        }

        override protected int run ( istring[] args )
        {
            // Register some timed events
            this.timers.register(&this.first, 0.0001);
            this.timers.register(&this.second, 0.0002);
            this.timers.register(&this.third, 0.0003);

            this.epoll.eventLoop();

            return 0;
        }

        private bool first ( )
        {
            return false; // false means that the event will not be reregistered
        }

        private bool second ( )
        {
            return false;
        }

        private bool third ( )
        {
            return false;
        }
    }

    new App;
}


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;
import ocean.util.app.model.IApplicationExtension;


public class TimerExt : IApplicationExtension
{
    import ocean.util.app.Application;

    import ocean.io.select.EpollSelectDispatcher;
    import ocean.io.select.client.TimerSet;

    /***************************************************************************

        Type of delegate called when an event fires. The delegate's return value
        indicates whether the timed event should remain registered (true) or be
        unregistered (false).

    ***************************************************************************/

    public alias bool delegate ( ) EventDg;

    /***************************************************************************

        Data stored for each event registered with the internal timer set (see
        below).

    ***************************************************************************/

    private struct EventData
    {

        /***********************************************************************

            Delegate to call when event fires.

        ***********************************************************************/

        public EventDg dg;

        /***********************************************************************

            Period after which event should fire again. (Note that we need to
            store this because timer set events are one-off, unlike
            TimerEvents.)

        ***********************************************************************/

        public ulong repeat_microsec;
    }

    /***************************************************************************

        Internal timer set used to track the set of timed events. A timer set
        is used to avoid the need for managing a set of TimerEvents, one per
        registered event.

    ***************************************************************************/

    private TimerSet!(EventData) timer_set;

    /***************************************************************************

        Constructor. Creates the internal event timer set.

        Params:
            epoll = select dispatcher with which to register the timer set

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll )
    {
        this.timer_set = new TimerSet!(EventData)(epoll);
    }

    /***************************************************************************

        Registers a timer with the extension. The provided delegate will be
        called repeatedly according to the specified period, as long as it
        returns true.

        Params:
            dg = delegate to call periodically
            period_s = seconds between calls of the delegate

    ***************************************************************************/

    public void register ( EventDg dg, double period_s )
    {
        assert(dg);
        assert(period_s >= 0.0);
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

    public void register ( EventDg dg, double init_s, double period_s )
    {
        assert(dg);
        assert(init_s >= 0.0);
        assert(period_s >= 0.0);

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

    public void registerMicrosec ( EventDg dg, ulong init_microsec, ulong period_microsec )
    {
        assert(dg);

        this.timer_set.schedule(
            ( ref EventData event )
            {
                event.dg = dg;
                event.repeat_microsec = period_microsec;
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
        delegate and re-schedules the event after the specified period.

        Params:
            event = data attached to the event which fired

    ***************************************************************************/

    private void eventFired ( ref EventData event )
    {
        auto reregister = event.dg();
        if ( reregister )
        {
            this.registerMicrosec(event.dg, event.repeat_microsec, event.repeat_microsec);
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

    /***************************************************************************

        Returns:
            the extension order

    ***************************************************************************/

    public override int order ( )
    {
        return 0;
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


version ( UnitTest )
{
    import ocean.util.app.Application;

    import ocean.core.Test;
}


/*******************************************************************************

    Test that scheduled events are called in the correct order.

*******************************************************************************/

version(none) // current test is flakey and needs to be reworked
unittest
{
    class App
    {
        import ocean.io.select.EpollSelectDispatcher;

        private EpollSelectDispatcher epoll;

        private uint counter;

        this ( )
        {
            this.epoll = new EpollSelectDispatcher;
            auto timers = new TimerExt(this.epoll);

            // Register some events
            timers.register(&this.first, 0.0001, 10);
            timers.register(&this.second, 0.0002, 10);
            timers.register(&this.third, 0.0003, 10);

            // Run timers until all are unregistered
            this.epoll.eventLoop();

            // When the event loop exits, all three should have fired
            test!("==")(this.counter, 3);
        }

        private bool first ( )
        {
            test!("==")(this.counter, 0);
            this.counter++;
            return false;
        }

        private bool second ( )
        {
            test!("==")(this.counter, 1);
            this.counter++;
            return false;
        }

        private bool third ( )
        {
            test!("==")(this.counter, 2);
            this.counter++;
            return false;
        }
    }

    new App;
}

/*******************************************************************************

    Test clearing registered events.

*******************************************************************************/

version(none) // current test is flakey and needs to be reworked
unittest
{
    class App
    {
        import ocean.io.select.EpollSelectDispatcher;

        private EpollSelectDispatcher epoll;

        private TimerExt timers;

        private uint counter;

        this ( )
        {
            this.epoll = new EpollSelectDispatcher;
            this.timers = new TimerExt(this.epoll);

            // Register some events
            this.timers.register(&this.first, 0.0001, 10);
            this.timers.register(&this.second, 0.0002, 10);

            // Run timers until first() clears them all
            this.epoll.eventLoop();

            // When the event loop exits, only the first should have fired
            test!("==")(this.counter, 1);
        }

        private bool first ( )
        {
            test!("==")(this.counter, 0);
            this.counter++;

            test!("==")(this.timers.timer_set.length, 1);
            this.timers.clear();
            test!("==")(this.timers.timer_set.length, 0);

            return false;
        }

        private bool second ( )
        {
            test(false);
            return false;
        }
    }

    new App;
}

/*******************************************************************************

    Test for unregistering a repeated timer.

*******************************************************************************/

version(none) // current test is flakey and needs to be reworked
unittest
{
    class App
    {
        import ocean.io.select.EpollSelectDispatcher;

        private EpollSelectDispatcher epoll;

        private uint counter;

        this ( )
        {
            this.epoll = new EpollSelectDispatcher;
            auto timers = new TimerExt(this.epoll);

            // Register an event
            timers.register(&this.dg, 0.0001);

            // Run timers until dg() returns false
            this.epoll.eventLoop();

            // When the event loop exits, dg() should have fired three times
            test!("==")(this.counter, 3);
        }

        private bool dg ( )
        {
            this.counter++;
            test!("<=")(this.counter, 3);
            return this.counter < 3;
        }
    }

    new App;
}
