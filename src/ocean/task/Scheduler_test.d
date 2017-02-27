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
import ocean.core.Test;

unittest
{
    // ensure that `theScheduler.exception_handler catches unhandled exceptions

    static class ThrowingTask1 : Task
    {
        override public void run ( )
        {
            throw new Exception("unhandled");
        }
    }

    static class ThrowingTask2 : Task
    {
        override public void run ( )
        {
            theScheduler.processEvents();
            throw new Exception("unhandled");
        }
    }

    initScheduler(SchedulerConfiguration.init);

    int caught = 0;
    theScheduler.exception_handler = (Task t, Exception e) {
        test(t !is null);
        test(e !is null);
        test!("==")(e.msg, "unhandled");
        caught++;
    };

    theScheduler.schedule(new ThrowingTask1);
    theScheduler.schedule(new ThrowingTask2);
    theScheduler.eventLoop();

    test!("==")(caught, 2);
}
