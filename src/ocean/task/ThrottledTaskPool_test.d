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
import ocean.io.select.client.TimerEvent;

import ocean.core.Test;
import ocean.core.Verify;

static import core.thread;

/*******************************************************************************

    Example of processing task, one which is managed by StreamProcessor and
    gets scheduled for each new record arriving from Generator

*******************************************************************************/

class ProcessingTask : Task
{
    int x;

    static int total;
    static size_t recycle_count;

    void copyArguments ( int x )
    {
        this.x = x;
    }

    override public void recycle ( )
    {
        recycle_count++;
    }

    override void run ( )
    {
        test!("==")(theScheduler.getStats.worker_fiber_busy, 0);

        ++total;
        .wait(100);

        if (this.x == 1000)
            theScheduler.shutdown();
    }
}

/*******************************************************************************

    "stream" or "generator" class, one which keeps producing new records for
    processing at throttled rate

*******************************************************************************/

class Generator : ISuspendable
{
    TimerEvent timer;
    ThrottledTaskPool!(ProcessingTask) pool;
    int counter;

    this ( )
    {
        this.timer = new TimerEvent(&this.generate);
        this.pool = new ThrottledTaskPool!(ProcessingTask)(10, 0);
        this.pool.throttler.addSuspendable(this);
    }

    void start ( )
    {
        this.timer.set(0, 1, 0, 1);
        this.resume();
    }

    override void resume ( )
    {
        theScheduler.epoll.register(this.timer);
    }

    override void suspend ( )
    {
        theScheduler.epoll.unregister(this.timer);
    }

    override bool suspended ( )
    {
        return this.timer.is_registered;
    }

    bool generate ( )
    {
        this.pool.start(this.counter);
        ++this.counter;
        return true;
    }
}

unittest
{
    SchedulerConfiguration config;
    with (config)
    {
        worker_fiber_limit = 10;
        task_queue_limit = 30;
        specialized_pools = [
            PoolDescription(ProcessingTask.classinfo.name, 10240)
        ];
    }
    initScheduler(config);

    auto generator = new Generator;

    generator.start();
    theScheduler.eventLoop();

    test!("==")(ProcessingTask.recycle_count, ProcessingTask.total);
    test!("==")(generator.pool.num_busy(), 0);

    // exact number of tasks that will be processed before the shutdown
    // may vary but it must always be at most 1000 + task_queue_limit
    test!(">=")(ProcessingTask.total, 1000);
    test!("<=")(ProcessingTask.total, 1000 + config.task_queue_limit);
}
