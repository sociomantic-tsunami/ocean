/*******************************************************************************

    Reusable fiber pool implementation

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.internal.FiberPool;


import core.thread;

import ocean.task.Task;
import ocean.core.Verify;
import ocean.util.container.pool.ObjectPool;

debug (TaskScheduler)
{
    import ocean.io.Stdout;
}

/******************************************************************************

    Fiber pool class.

    Allows recycling finished fibers, reusing them to spawn new tasks without
    making new allocations.

******************************************************************************/

public class FiberPool : ObjectPool!(WorkerFiber)
{
    /**************************************************************************

        Fiber stack size defined for this pool

    **************************************************************************/

    private size_t stack_size;

    /**************************************************************************

        Constructor

        Params:
            stack_size = fiber stack size to use in this poll
            limit = limit to pool size. If set to 0 (default), there is no
                app limit and pool growth will be limited only by OS
                resources

    **************************************************************************/

    this ( size_t stack_size, size_t limit = 0 )
    {
        this.stack_size = stack_size;
        if (limit > 0)
            this.setLimit(limit);
    }

    /**************************************************************************

        This method should never be called, it is only overridden to conform
        to base class API. Other modules in `ocean.task` package only
        used other `get` overload.

        Params:
            if_missing = lazy expression that creates new fiber in case
                pool needs to be extended

        Returns:
            Fiber reference to use. Can be either reused or freshly created
            one. Null upon any failure.

    **************************************************************************/

    override public WorkerFiber get ( lazy WorkerFiber if_missing )
    {
        auto fiber = super.get(if_missing);
        if (fiber is null)
            return null;
        verify(fiber.state() == Fiber.State.TERM);
        return fiber;
    }

    /**************************************************************************

        The method to get a fiber from the pool.

        Returns:
            Fiber reference to use. Can be either reused or freshly created
            one. Null upon any failure.

    **************************************************************************/

    public WorkerFiber get ( )
    {
        return this.get(new WorkerFiber(this.stack_size));
    }

    /**************************************************************************

        Resets recycled item state to make it usable again.

        Doesn't actually do anything apart from checking fiber state to avoid
        fiber attempts to reset other running fiber. When scheduler gets an
        item from the pool, it will reset it to new task anyway.

        Params:
            item = item (fiber) to reset

    **************************************************************************/

    override protected void resetItem ( Item item )
    {
        auto fiber = this.fromItem(item);
        verify(
            fiber is Fiber.getThis()
                || fiber.state() == Fiber.State.TERM
        );
    }
}
