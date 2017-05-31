/*******************************************************************************

    Extended unit tests for the Scheduler module

    Copyright:
        Copyright (c) 2017 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.Scheduler_test;

import ocean.task.Scheduler;
import ocean.task.Task;
import ocean.task.util.Timer;
import ocean.core.Test;
import ocean.core.Enforce;

unittest
{
    // ensure that `theScheduler.exception_handler catches unhandled exceptions

    static class ThrowingTask1 : Task
    {
        // throws straight from `schedule`

        override public void run ( )
        {
            enforce(false, "scheduler");
        }
    }

    static class ThrowingTask2 : Task
    {
        // throws from `select_cycle_hook`

        override public void run ( )
        {
            theScheduler.processEvents();
            enforce(false, "scheduler");
        }
    }

    static class ThrowingTask3 : Task
    {
        // throws from inside the epoll

        override public void run ( )
        {
            .wait(1);
            enforce(false, "epoll");
        }
    }

    SchedulerConfiguration config;
    config.worker_fiber_limit = 1; // make sure tasks run 1 by 1
    initScheduler(config);

    int caught = 0;
    theScheduler.exception_handler = (Task t, Exception e) {
        test(e !is null);
        if (t is null)
            test!("==")(e.msg, "epoll");
        else
            test!("==")(e.msg, "scheduler");
        caught++;
        Task.continueAfterThrow();
    };

    for (int i = 0; i < 3; ++i)
    {
        theScheduler.schedule(new ThrowingTask1);
        theScheduler.schedule(new ThrowingTask2);
        theScheduler.schedule(new ThrowingTask3);
    }

    theScheduler.eventLoop();

    test!("==")(caught, 9);
}

unittest
{
    static class SubTask : Task
    {
        int result;

        override void run ( )
        {
            result = 41;
            .wait(1);
            result = 42;
        }

        override void recycle ( )
        {
            result = 43;
        }
    }

    static class MainTask : Task
    {
        override void run ( )
        {
            // suspend once because `await` safeguards against being run
            // before the scheduler starts
            theScheduler.processEvents();

            // block on result of other tasks:
            auto r1 = theScheduler.awaitResult(new SubTask);
            auto r2 = theScheduler.awaitResult(new SubTask);
            test!("==")(r1, 42);
            test!("==")(r2, 42);
        }
    }

    initScheduler(SchedulerConfiguration.init);
    theScheduler.schedule(new MainTask);
    theScheduler.eventLoop();
}

unittest
{
    static class DummyTask : Task
    {
        override void run ( )
        {
            theScheduler.processEvents();
        }
    }

    SchedulerConfiguration config;
    config.suspended_task_limit = 1;
    initScheduler(config);
    theScheduler.schedule(new DummyTask);
    testThrown!(SuspendQueueFullException)(
        theScheduler.schedule(new DummyTask));
}
