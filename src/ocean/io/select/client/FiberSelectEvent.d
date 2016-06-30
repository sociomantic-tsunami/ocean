/*******************************************************************************

    Custom event for use with fibers and epoll, allowing a process to be
    suspended until the event is triggered.

    Usage example:

    ---

        import ocean.io.select.client.FiberSelectEvent;
        import ocean.io.select.EpollSelectDispatcher;

        auto fiber = new MessageFiber(&coroutine);

        auto epoll = new EpollSelectDispatcher;
        auto event = new FiberSelectEvent(fiber, epoll);

        // Fiber method
        void coroutine ( )
        {
            // Do something.

            // Wait on the event, suspends the fiber.
            event.wait();

            // When event.trigger is called (from elsewhere), the fiber is
            // resumed.
        }

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.client.FiberSelectEvent;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.MessageFiber;

import ocean.sys.EventFD;

import ocean.io.select.client.model.IFiberSelectClient;


/*******************************************************************************

    Fiber select event class

*******************************************************************************/

public class FiberSelectEvent : IFiberSelectClient
{
    /***************************************************************************

        Token used when suspending / resuming fiber.

    ***************************************************************************/

    static private MessageFiber.Token EventFired;


    /***************************************************************************

        Static ctor. Initialises fiber token.

    ***************************************************************************/

    static this ( )
    {
        EventFired = MessageFiber.Token("event_fired");
    }


    /***************************************************************************

        Custom event.

    ***************************************************************************/

    private EventFD event;


    /***************************************************************************

        Constructor.

        Params:
            fiber = fiber to suspend / resume with event wait / trigger

    ***************************************************************************/

    public this ( SelectFiber fiber )
    {
        super(fiber);

        this.event = new EventFD;
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
        return this.event.fileHandle;
    }


    /***************************************************************************

        Triggers the event.

    ***************************************************************************/

    public void trigger ( )
    {
        this.event.trigger();
    }


    /***************************************************************************

        Suspends the fiber until the event is triggered.

    ***************************************************************************/

    public void wait ( )
    {
        super.fiber.register(this);
        super.fiber.suspend(EventFired, this, fiber.Message(true));
    }


    /***************************************************************************

        Combining trigger() then wait(), this method causes the epoll event loop
        to be resumed, giving other select clients a chance to do something.

    ***************************************************************************/

    public void cede ( )
    {
        this.trigger;
        this.wait;
    }


    /***************************************************************************

        Handles events which occurred for the custom event fd.

        (Implements an abstract super class method.)

        Returns:
            false if the fiber is finished or true if it keeps going

    ***************************************************************************/

    public override bool handle ( Event events )
    in
    {
        assert (super.fiber.waiting);
    }
    body
    {
        this.event.handle();

        SelectFiber.Message message = super.fiber.resume(EventFired, this);

        return (message.active == message.active.num)? message.num != 0 : false;
    }
}

