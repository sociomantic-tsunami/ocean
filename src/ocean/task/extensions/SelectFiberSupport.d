/******************************************************************************

    Task extension which makes it possible to convert an existing, currently
    executed task instance to a `SelectFiber` instance, for compatibility with
    old ocean/swarm utils.

    Usage example:
        See the documented unittest of the SelectFiberSupport struct

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

******************************************************************************/

module ocean.task.extensions.SelectFiberSupport;


import ocean.task.Task;
import ocean.io.select.fiber.SelectFiber;

version (UnitTest)
{
    import ocean.core.Test;
    import ocean.task.Scheduler;
    import ocean.io.select.client.FiberTimerEvent;
}

/******************************************************************************

    Task extension to be used with the `TaskWith` class.

******************************************************************************/

deprecated("Use task facilities directly or contact the core team")
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
