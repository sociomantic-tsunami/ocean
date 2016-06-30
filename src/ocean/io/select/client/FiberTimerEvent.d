/*******************************************************************************

    Fiber-suspending timer event. Allows a fiber to be suspended for a fixed
    time period.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.client.FiberTimerEvent;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.MessageFiber;

import ocean.sys.TimerFD;

import ocean.io.select.client.model.IFiberSelectClient;

import ocean.transition;
import ocean.stdc.math: modf;



/*******************************************************************************

    Fiber-suspending timer event. Allows a fiber to be suspended for a fixed
    time period.

*******************************************************************************/

public class FiberTimerEvent : IFiberSelectClient
{
    /***************************************************************************

        Token used when suspending / resuming fiber.

    ***************************************************************************/

    static private MessageFiber.Token TimerFired;


    /***************************************************************************

        Static ctor. Initialises fiber token.

    ***************************************************************************/

    static this ( )
    {
        TimerFired = MessageFiber.Token("timer_fired");
    }


    /***************************************************************************

        Timer fd.

    ***************************************************************************/

    private TimerFD timer;


    /***************************************************************************

        Constructor. Initialises (but does not register) the timer fd.

        Params:
            fiber = fiber instance to be suspended/resumed by the timer
            realtime = true:  use a settable system-wide clock.
                       false: use a non-settable clock that is not affected by
                       discontinuous changes in the system clock (e.g., manual
                       changes to system time).

    ***************************************************************************/

    public this ( SelectFiber fiber, bool realtime = false )
    {
        super(fiber);

        this.timer = new TimerFD(realtime);
    }


    /***************************************************************************

        Returs:
            the epoll events to register for.

    ***************************************************************************/

    public override Event events ( )
    {
        return Event.EPOLLIN;
    }


    /***************************************************************************

        Required by ISelectable interface.

        Returns:
            file descriptor used to manage custom event

    ***************************************************************************/

    public override Handle fileHandle ( )
    {
        return this.timer.fileHandle;
    }


    /***************************************************************************

        Sets the timer to a number of seconds and milliseconds approximating the
        floating point value specified, registers it, and suspends the fiber
        until it fires.

        Params:
            s = number of seconds to suspend fiber for

        In:
            s must be at least 0, which implies it must not be NaN. +∞ is
            tolerated and uses the highest possible timer value.

    ***************************************************************************/

    public void wait ( double s )
    in
    {
        assert(s >= 0); // tolerate +∞
    }
    body
    {
        double int_s;
        auto ms = cast(uint)(modf(s, &int_s) * 1000);
        this.wait(cast(uint)int_s, ms);
    }

    /***************************************************************************

        Sets the timer to the specified number of seconds and milliseconds,
        registers it, and suspends the fiber until it fires. If both seconds and
        milliseconds are 0, the fiber is not suspended and the event is not
        registered with epoll -- no pause occurs.

        Params:
            s = number of seconds to suspend fiber for
            ms = number of additional milliseconds to suspend fiber for

    ***************************************************************************/

    public void wait ( uint s, uint ms = 0 )
    {
        if ( s == 0 && ms == 0 ) return;

        this.timer.set(s, ms, 0, 0);
        this.fiber.register(this);
        this.fiber.suspend(TimerFired, this, this.fiber.Message(true));
    }


    /***************************************************************************

        Handles events which occurred for the timer event fd. Resumes the fiber.

        (Implements an abstract super class method.)

        Params:
            events = events which occurred for the fd

        Returns:
            false if the fiber is finished or true if it keeps going

    ***************************************************************************/

    public override bool handle ( Event events )
    in
    {
        assert (this.fiber.waiting);
    }
    body
    {
        this.timer.handle();

        SelectFiber.Message message = this.fiber.resume(TimerFired, this);

        // FIXME: this should actually always return false, as we always want
        // the timer to be one-shot. However, there is a fundamental bug with
        // the way the messages are handled. The problem is that
        // IFiberSelectClient.finalize() does not know whether the fiber is
        // still in use (suspended with no client registered) or whether it
        // should be killed. This will need to be revisited and fixed.
        return (message.active == message.active.num)? message.num != 0 : false;
    }


    /***************************************************************************

        Returns:
            identifier string for this instance, including the remaining time

    ***************************************************************************/

    debug
    {
        private mstring time_buffer;
        import ocean.core.Array : copy;
        import ocean.text.convert.Format;

        public override cstring id ( )
        {
            this.time_buffer.copy(super.id());
            auto time = this.timer.time();

            Format.format(this.time_buffer, ": {}s {}ns",
                time.it_value.tv_sec, time.it_value.tv_nsec);
            return this.time_buffer;
        }
    }

}
