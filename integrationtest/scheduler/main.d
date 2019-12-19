/*******************************************************************************

    Test project doing emulating scheduler based application different kind of
    concurrent task processing. Most useful when doing manual debugging with
    `-debug=TaskScheduler` trace enabled, as there won't be any extra noise from
    imported unittests.

    Copyright:
        Copyright (c) 2017 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module integrationtest.scheduler.main;

import ocean.task.Scheduler;
import ocean.task.Task;
import ocean.task.TaskPool;
import ocean.task.util.Timer;

import ocean.transition;
import ocean.core.Test;
import ocean.io.Stdout;

import core.stdc.stdlib;

/// Entry point task that starts up everything else
class MainTask : Task
{
    GeneratorTask[] generators;
    TaskPool!(RegularTask) pool;

    this ( )
    {
        this.pool = new typeof(this.pool);

        for (int i = 0; i < 5; ++i)
        {
            this.generators ~= new GeneratorTask;
            this.generators[$-1].root = this;
        }
    }

    override public void run ( )
    {
        foreach (task; this.generators)
            theScheduler.schedule(task);
    }
}

/// Task emulating some sort of priority / real-time computation
/// that must not ever wait in queue, but is known to have predictable
/// max concurrency factor. Spawns `RegularTask` as part of its work.
class GeneratorTask : Task
{
    MainTask root;

    override public void run ( )
    {
        for (int i = 0; i < 5; ++i)
            this.root.pool.start();
    }
}

/// Task doing some prolonged I/O wait after being queued
class RegularTask : Task
{
    static long completed_count;

    override public void run ( )
    {
        .wait(100_000);
        ++RegularTask.completed_count;
    }

    void copyArguments ( ) { }
}

version (unittest) {} else
void main ( )
{
    SchedulerConfiguration config;

    with (config)
    {
        worker_fiber_stack_size = 102400;
        worker_fiber_limit = 10;
        task_queue_limit = 100;

        specialized_pools = [
            PoolDescription(GeneratorTask.classinfo.name, 204800)
        ];
    }

    initScheduler(config);

    theScheduler.exception_handler = ( Task t, Exception e )
    {
        Stderr.formatln("{} [{}:{}] {}", e.classinfo.name,
            e.file, e.line, e.message());
        abort();
    };

    theScheduler.schedule(new MainTask);
    theScheduler.eventLoop();

    test!("==")(RegularTask.completed_count, 25);
}
