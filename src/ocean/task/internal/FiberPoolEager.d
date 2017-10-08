/*******************************************************************************

    Extends reusable fiber pool with ability to run tasks using
    available fibers. Used in the scheduler when custom handling of specific
    task types is configured. Eager fiber pool instances never have item count
    limit.

    Copyright:
        Copyright (c) 2017 sociomantic Labs GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.internal.FiberPoolEager;

import core.thread : Fiber;

import ocean.meta.types.Qualifiers;
import ocean.core.Enforce;
import ocean.task.internal.FiberPool;
import ocean.task.Task;

debug (TaskScheduler)
    import ocean.io.Stdout;

/// Ditto
class FiberPoolEager : FiberPool
{
    /**************************************************************************

        Constructor

        Params:
            stack_size = fiber stack size to use in this poll

    **************************************************************************/

    this ( size_t stack_size )
    {
        super(stack_size, 0);
    }

    /***************************************************************************

        Method used to execute a task.

        Task is always executed immediately and this method will only return
        when that task first calls `suspend`.

        Params:
            task = derivative from `ocean.task.Task` defining some application
                task to execute

    ***************************************************************************/

    public void run ( Task task )
    {
        auto fiber = this.get();
        debug_trace("running task <{}> via worker fiber <{}>",
            cast(void*) task, cast(void*) fiber);
        task.assignTo(fiber);
        task.terminationHook({
            auto fiber = cast(WorkerFiber) Fiber.getThis();
            auto task = fiber.activeTask();
            this.recycle(fiber);
            task.fiber = null;
        });
        task.resume();
    }
}

private void debug_trace ( T... ) ( cstring format, T args )
{
    debug ( TaskScheduler )
    {
        Stdout.formatln( "[ocean.task.internal.FiberPoolEager] "
            ~ format, args ).flush();
    }
}
