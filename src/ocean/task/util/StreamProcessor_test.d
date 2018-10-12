/*******************************************************************************

    Copyright:
        Copyright (c) 20017 dunnhumby Germany GmbH.
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
import ocean.io.select.client.TimerEvent;

import ocean.core.Test;
import ocean.core.Verify;

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

/*******************************************************************************

    "stream" or "generator" class, one which keeps producing new records for
    processing at throttled rate

*******************************************************************************/

class Generator : ISuspendable
{
    TimerEvent timer;
    StreamProcessor!(ProcessingTask) stream_processor;
    int counter;

    this ( )
    {
        this.timer = new TimerEvent(&this.generate);

        auto throttler_config = ThrottlerConfig(10, 1);
        this.stream_processor = new StreamProcessor!(ProcessingTask)(throttler_config);
        this.stream_processor.addStream(this);
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
        this.stream_processor.process(this.counter);
        ++this.counter;
        return true;
    }
}

unittest
{
    SchedulerConfiguration config;
    config.worker_fiber_limit = 10;
    config.task_queue_limit = 30;
    initScheduler(config);

    auto generator = new Generator;
    generator.start();
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

