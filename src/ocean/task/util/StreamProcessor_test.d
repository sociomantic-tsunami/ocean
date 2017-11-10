/*******************************************************************************

    Copyright:
        Copyright (c) 20017 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.util.StreamProcessor_test;


import ocean.task.Task;
import ocean.task.Scheduler;
import ocean.task.util.StreamProcessor;
import ocean.task.util.Timer;

import ocean.io.model.ISuspendable;
import ocean.io.Stdout;
import ocean.core.Test;

static import core.thread;

/*******************************************************************************

    "stream" or "generator" class, one which keeps producing new records for
    processing at throttled rate

*******************************************************************************/

class Generator : Task
{
    void delegate(int) process_dg;

    this ( typeof(this.process_dg) dg )
    {
        this.process_dg = dg;
    }

    override void run ( )
    {
        int i;
        while (++i)
            process_dg(i);
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

    auto throttler_config = ThrottlerConfig(10, 1);
    auto stream_processor = new StreamProcessor!(ProcessingTask)(throttler_config);
    auto generator = new Generator(&stream_processor.process);
    stream_processor.addStream(generator);

    theScheduler.schedule(generator);
    theScheduler.eventLoop();

    // exact number of tasks that will be processed before the shutdown
    // may vary but it must always be at most 1000 + task_queue_limit
    test!(">=")(ProcessingTask.total, 1000);
    test!("<=")(ProcessingTask.total, 1000 + config.task_queue_limit);
}

unittest
{
    SchedulerConfiguration config;
    initScheduler(config);

    static class DummyTask : Task
    {
        override public void run ( ) { }
        public void copyArguments ( ) { }
    }

    {
        // suspend point >= task queue
        auto throttler_config = ThrottlerConfig(config.task_queue_limit, 1);
        testThrown!(ThrottlerFailureException)(new StreamProcessor!(DummyTask)(
            throttler_config));
    }

    {
        // resume point >= task queue
        auto throttler_config = ThrottlerConfig(1, config.task_queue_limit);
        testThrown!(ThrottlerFailureException)(new StreamProcessor!(DummyTask)(
            throttler_config));
    }

    {
        // works
        auto throttler_config = ThrottlerConfig(config.task_queue_limit - 1, 1);
        auto processor = new StreamProcessor!(DummyTask)(throttler_config);
    }
}

