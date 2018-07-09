/*******************************************************************************

    Copyright:
        Copyright (c) 2017 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.util.Event_test;

import ocean.task.util.Event;
import ocean.task.Task;
import ocean.task.util.Timer;
import ocean.task.Scheduler;
import ocean.core.Test;

unittest
{
    TaskEvent event;
    int state = 0;

    class Task1 : Task
    {
        override public void run ( )
        {
            state = 1;
            event.wait();
            state = 3;
        }
    }

    class Task2 : Task
    {
        override public void run ( )
        {
            state = 2;
            .wait(100);
            event.trigger();
        }
    }

    initScheduler(SchedulerConfiguration.init);
    theScheduler.schedule(new Task1);
    test!("==")(state, 1);
    theScheduler.schedule(new Task2);
    test!("==")(state, 2);
    theScheduler.eventLoop();
    test!("==")(state, 3);
}

unittest
{
    TaskEvent event;
    int state = 0;

    class Task1 : Task
    {
        override public void run ( )
        {
            state = 1;
            event.wait();
            state = 3;
        }
    }

    class Task2 : Task
    {
        override public void run ( )
        {
            state = 2;
            event.trigger();
        }
    }

    initScheduler(SchedulerConfiguration.init);
    theScheduler.schedule(new Task2);
    test!("==")(state, 2);
    theScheduler.schedule(new Task1);
    test!("==")(state, 3);
    theScheduler.eventLoop();
}


