/******************************************************************************

    Test for integration between SelectFiberSupport extension and TaskPool

    Copyright: Copyright (c) 2016 sociomantic labs. All rights reserved

******************************************************************************/

module ocean.task.extensions.SelectFiberSupport_test;

import ocean.task.Scheduler;
import ocean.task.Task;
import ocean.task.extensions.SelectFiberSupport;;
import ocean.task.TaskPool;

import ocean.io.select.client.FiberTimerEvent;

unittest
{
    initScheduler(SchedulerConfiguration(10240, 10, 10, 10));

    // NB: static is crucial here becaue TaskPool will add own context
    // to this class - presence of another scope context will crash dmd1
    static class MyTask : TaskWith!(SelectFiberSupport)
    {
        public void copyArguments ( ) { }

        override protected void run ( )
        {
            auto select_fiber = this.extensions.select_fiber_support.get();
            auto timer = new FiberTimerEvent(select_fiber);
            timer.wait(0.01);
            select_fiber.unregister();
        }
    }

    auto pool = new TaskPool!(MyTask);
    pool.setLimit(2);

    class SpawnTask : Task
    {
        override public void run ( )
        {
            for (int i = 0; i < 10; ++i)
            {
                while (!pool.start())
                    theScheduler.processEvents();
            }
        }
    }

    theScheduler.schedule(new SpawnTask);
    theScheduler.eventLoop();
}
