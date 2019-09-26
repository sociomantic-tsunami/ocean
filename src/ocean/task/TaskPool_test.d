/*******************************************************************************

    Copyright:
        Copyright (c) 2017 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.TaskPool_test;

import ocean.task.TaskPool;
import ocean.task.Task;
import ocean.task.Scheduler;
import ocean.core.Test;
import ocean.task.util.Timer;

unittest
{
    // Test that the recycle method of custom tasks is called
    static class RecycleTask : Task
    {
        static size_t recycle_count;

        public void copyArguments ( )
        {

        }

        override public void recycle ( )
        {
            recycle_count++;
        }

        override public void run ( )
        {

        }
    }

    auto pool = new TaskPool!(RecycleTask);
    initScheduler(SchedulerConfiguration.init);

    pool.start();
    pool.start();

    theScheduler.eventLoop();
    test!("==")(RecycleTask.recycle_count, 2,
        "RecycleTask.recycle was not called the correct number of times");
}

unittest
{
    // Test for waiting until all running tasks of a task pool finish executing.

    static class AwaitTask : Task
    {
        static int value;

        public void copyArguments ( )
        {
        }

        override public void run ( )
        {
            .wait(1); // so that the task gets suspended
            value++;
        }
    }

    class MainTask : Task
    {
        TaskPool!(AwaitTask) my_task_pool;

        public this ( )
        {
            this.my_task_pool = new TaskPool!(AwaitTask);
        }

        override protected void run ( )
        {
            static immutable NUM_START_CALLS = 6;

            for (uint i; i < NUM_START_CALLS; i++)
                this.my_task_pool.start();

            this.my_task_pool.awaitRunningTasks();

            test!("==")(AwaitTask.value, NUM_START_CALLS);
        }
    }

    initScheduler(SchedulerConfiguration.init);
    theScheduler.schedule(new MainTask);
    theScheduler.eventLoop();
}

unittest
{
    // Test that 'awaitRunningTasks()' cannot be called from a task that itself
    // belongs to the pool.

    static class AwaitTask : Task
    {
        void delegate () dg;

        public void copyArguments ( scope void delegate () dg )
        {
            this.dg = dg;
        }

        override public void run ( )
        {
            testThrown!(Exception)(this.dg());
        }
    }

    auto pool = new TaskPool!(AwaitTask);
    initScheduler(SchedulerConfiguration.init);

    pool.start(
        {
            // This delegate should throw as it will attempt to call the task
            // pool's awaitRunningTasks() method from within a task that itself
            // belongs to the pool.
            pool.awaitRunningTasks();
        }
    );
}
