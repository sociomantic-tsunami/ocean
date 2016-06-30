/******************************************************************************

    Task extension which makes it possible to convert an existing, currently
    executed task instance to a `SelectFiber` instance, for compatibility with
    old ocean/swarm utils.

    Usage example:
        See the documented unittest of the SelectFiberSupport struct

    Copyright: Copyright (c) 2016 sociomantic labs. All rights reserved

******************************************************************************/

module ocean.task.extensions.SelectFiberSupport;

/******************************************************************************

    Imports

******************************************************************************/

import ocean.task.Task;
import ocean.task.Scheduler;
import ocean.io.select.fiber.SelectFiber;

version (UnitTest)
{
    import ocean.core.Test;
    import ocean.io.select.client.FiberTimerEvent;
}

/******************************************************************************

    Task extension to be used with the `TaskWith` class.

******************************************************************************/

struct SelectFiberSupport
{
    private SelectFiber matching_select_fiber;
    private Task host;

    public void reset ( Task host )
    {
        this.host = host;
        if (   (this.matching_select_fiber !is null)
            && (this.matching_select_fiber.getRawFiber() !is host.fiber))
        {
            this.matching_select_fiber.reset(host.fiber);
        }
    }

    /**************************************************************************

        Returns:
            reference to SelectFiber instance which wraps the very same
            worker fiber this task executes in. It can be passed to legacy API
            expecting SelectFiber but doing so will suspend/resume worker
            fiber bypassing any other task extensions.

    **************************************************************************/

    public SelectFiber get ( )
    {
        if (this.matching_select_fiber is null)
            this.matching_select_fiber = new SelectFiber(
                theScheduler.epoll(), this.host.fiber);
        return this.matching_select_fiber;
    }
}

///
unittest
{
    initScheduler(SchedulerConfiguration(10240, 10, 10, 10));

    class MyTask : TaskWith!(SelectFiberSupport)
    {
        override protected void run ( )
        {
            auto select_fiber = this.extensions.select_fiber_support.get();

            auto timer = new FiberTimerEvent(select_fiber);
            timer.wait(0.01);

            // the FiberTimerEvent always leaves itself registered, as
            // a workaround for a mis-design in our select fiber system.
            // See https://github.com/sociomantic/ocean/issues/27 for
            // more details
            select_fiber.unregister();
        }
    }

    auto task = new MyTask;
    theScheduler.schedule(task);
    theScheduler.eventLoop();
}
