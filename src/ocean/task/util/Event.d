/*******************************************************************************

    Shortcut wrapper for `ocean.task.Task` to suspend/resume on certain
    conditions.

    Copyright:
        Copyright (c) 2017 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.util.Event;

import ocean.transition;
import ocean.task.Task;
import ocean.task.util.Timer;
import ocean.task.Scheduler;

debug (TaskScheduler)
{
    import ocean.io.Stdout;
}

/*******************************************************************************

    Binds together a task reference and a boolean flag to indicate the event 
    status.

    Allows calling wait/trigger in any order as opposed to the plain
    resume/suspend.

*******************************************************************************/

struct TaskEvent
{
    /// indicates that event this instance described was triggered
    private bool triggered;
    /// refers to the task instance that must be resumed on the event
    private Task task;

    /***************************************************************************

        Pauses execution of the current task until `trigger()` is called.
        If `trigger()` has already been called before, does nothing.

    ***************************************************************************/

    public void wait ( )
    {
        if (!(&this).triggered)
        {
            (&this).task = Task.getThis();
            debug_trace("Task {} suspended waiting for event {}",
                cast(void*) (&this).task, cast(void*) (&this));
            (&this).task.suspend();
        }

        (&this).triggered = false;
    }

    /***************************************************************************

        Triggers resuming a task paused via `wait`. If no task is currently
        paused, raises the flag so that the next `wait` becomes no-op.

    ***************************************************************************/

    public void trigger ( )
    {
        (&this).triggered = true;
        if ((&this).task !is null && (&this).task.suspended())
        {
            debug_trace("Resuming task {} by trigger of event {}",
                cast(void*) (&this).task, cast(void*) (&this));
            (&this).task.resume();
        }
    }
}

version (UnitTest)
{
    import ocean.core.Test;
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

private void debug_trace ( T... ) ( cstring format, T args )
{
    debug ( TaskScheduler )
    {
        Stdout.formatln( "[ocean.task.util.Event] " ~ format, args ).flush();
    }
}
