/*******************************************************************************

    FiberSelectEvent suspend/resume interface for suspendable jobs waiting
    for AsyncIO to finish.

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

*******************************************************************************/

module ocean.util.aio.EventFDJobNotification;

import ocean.io.select.client.FiberSelectEvent;
import ocean.io.select.fiber.SelectFiber;
import ocean.util.aio.DelegateJobNotification;

/// ditto
class EventFDJobNotification: DelegateJobNotification
{
    /***************************************************************************

        Constructor.

        Params:
            event = FiberSelectEvent to synchronise on.

    ***************************************************************************/

    this (FiberSelectEvent event)
    {
        this.event = event;
        super(&this.trigger, &this.wait);
    }

    /***************************************************************************

        Constructor.

        Params:
            fiber = Fiber to create FiberSelectEvent to synchronise on.

    ***************************************************************************/

    this (SelectFiber fiber)
    {
        this.event = new FiberSelectEvent(fiber);
        super(&this.trigger, &this.wait);
    }

    /***************************************************************************

        Changes the SelectFiber this handler is suspending

        Params:
            fiber = new SelectFiber to suspend

    ***************************************************************************/

    public void setFiber (SelectFiber fiber)
    {
        this.event.fiber = fiber;
    }

    /**************************************************************************

        Triggers the event.

    **************************************************************************/

    private void trigger ()
    {
        this.event.trigger();
    }

    /**************************************************************************

        Waits on the event.

    **************************************************************************/

    private void wait ()
    {
        this.event.wait();
    }

    /***************************************************************************

        FiberSelectEvent synchronise object.

    ***************************************************************************/

    private FiberSelectEvent event;

}
