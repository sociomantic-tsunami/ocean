/*******************************************************************************

    Copyright:
        Copyright (c) 2017 sociomantic labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.util.Timer_test;

import ocean.task.util.Timer;
import ocean.task.Scheduler;
import ocean.task.Task;
import ocean.core.Test;
import core.thread;

unittest
{
    initScheduler(SchedulerConfiguration.init);

    class SimpleTask : Task
    {
        override public void run ( )
        {
            for (int i = 0; i < 10; ++i)
                .wait(10);
        }
    }

    auto task = new SimpleTask;
    theScheduler.schedule(task);
    theScheduler.eventLoop();
}

unittest
{
    // same as previous, but tests allocated event count inside `.timer` object

    initScheduler(SchedulerConfiguration.init);

    // re-create timer event pool to get rid of slots already allocated by other
    // test cases
    .timer = new typeof(.timer);

    class SimpleTask : Task
    {
        override public void run ( )
        {
            for (int i = 0; i < 10; ++i)
                .wait(10);
        }
    }

    auto task = new SimpleTask;
    theScheduler.schedule(task);
    theScheduler.eventLoop();

    test!("==")(.timer.scheduled_events(), 1);
}

unittest
{
    initScheduler(SchedulerConfiguration.init);

    static class InfiniteTask : Task
    {
        override public void run ( )
        {
            for (;;) .wait(100);
        }
    }

    static class RootTask : Task
    {
        Task to_wait_for;

        override public void run ( )
        {
            bool timeout = .awaitOrTimeout(this.to_wait_for, 200);
            test(timeout);

            // `awaitOrTimeout` itself won't terminate awaited task on timeout,
            // it will only "detach" it from the current context. If former is
            // desired, it can be trivially done at the call site:
            if (timeout)
                this.to_wait_for.kill();
        }
    }

    auto root = new RootTask;
    root.to_wait_for = new InfiniteTask;

    theScheduler.schedule(root);
    theScheduler.eventLoop();

    test(root.finished());
    test(root.to_wait_for.finished());
}

unittest
{
    initScheduler(SchedulerConfiguration.init);

    static class FiniteTask : Task
    {
        override public void run ( )
        {
            .wait(100);
        }
    }

    static class RootTask : Task
    {
        Task to_wait_for;

        override public void run ( )
        {
            bool timeout = .awaitOrTimeout(this.to_wait_for, 10000);
            test(!timeout);
            test(this.to_wait_for.finished());
        }
    }

    auto root = new RootTask;
    root.to_wait_for = new FiniteTask;

    theScheduler.schedule(root);
    theScheduler.eventLoop();

    test(root.finished());
    test(root.to_wait_for.finished());

}

