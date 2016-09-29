/******************************************************************************

    Provides all task extensions at once and tests they work together

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

******************************************************************************/

module ocean.task.extensions.package_;

public import ocean.task.extensions.ExceptionForwarding;
public import ocean.task.extensions.SelectFiberSupport;

version (UnitTest)
{
    import core.thread;
    import ocean.core.Test;
    import ocean.task.Task;
    import ocean.task.Scheduler;
}

unittest
{
    initScheduler(SchedulerConfiguration.init);

    class TestTask : TaskWith!(
        ExceptionForwarding, SelectFiberSupport)
    {
        override void run ( )
        {
            try
                this.suspend();
            catch (Exception) { }

            this.suspend();
        }
    }

    auto task = new TestTask;
    task.assignTo(new WorkerFiber(10240));
    task.resume();

    task.extensions.exception_forwarding.to_throw = new Exception("whatever");
    task.resume();
    test!("==")(task.fiber.state, Fiber.State.HOLD);

    task.kill();
    test!("==")(task.fiber.state, Fiber.State.TERM);

    test(task.extensions.select_fiber_support.get() !is null);
}
