/*******************************************************************************

    Example implementation/usage of stream processor which does no I/O and thus
    can is also used as a unit test

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.ThrottledTaskPool_test;


import ocean.task.Task;
import ocean.task.Scheduler;
import ocean.task.ThrottledTaskPool;
import ocean.task.util.Timer;

import ocean.io.model.ISuspendable;
import ocean.io.Stdout;
import ocean.core.Test;
import ocean.core.Verify;

static import core.thread;

/*******************************************************************************

    "stream" or "generator" class, one which keeps producing new records for
    processing at throttled rate

*******************************************************************************/

class Generator : Task
{
    bool delegate(int) process_dg;

    this ( typeof(this.process_dg) dg )
    {
        this.process_dg = dg;
    }

    override void run ( )
    {
        int i;
        while (++i)
            verify(process_dg(i));
    }
}

/*******************************************************************************

    Example of processing task, one which is managed by StreamProcessor and
    gets scheduled for each new record arriving from Generator

*******************************************************************************/

class ProcessingTask : Task
{
    int x;

    static int total;

    void copyArguments ( int x )
    {
        this.x = x;
    }

    override void run ( )
    {
        .wait(100);
        ++total;

        if (this.x == 1000)
            theScheduler.shutdown();
    }
}

unittest
{
    SchedulerConfiguration config;
    config.worker_fiber_limit = 10;
    config.task_queue_limit = 30;
    initScheduler(config);

    auto task_pool = new ThrottledTaskPool!(ProcessingTask)(10, 0);
    auto generator = new Generator(&task_pool.start);
    task_pool.throttler.addSuspendable(generator);

    theScheduler.schedule(generator);
    theScheduler.eventLoop();

    // exact number of tasks that will be processed before the shutdown
    // may vary but it must always be at most 1000 + task_queue_limit
    test!(">=")(ProcessingTask.total, 1000);
    test!("<=")(ProcessingTask.total, 1000 + config.task_queue_limit);

}
