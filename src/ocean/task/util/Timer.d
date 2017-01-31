/*******************************************************************************

    Collection of task waiting / timer utilities wrapped in an easy to use,
    pseudo-blocking API.

    Uses a private static `ocean.io.select.client.TimerSet` instance for fiber
    resuming.

    Usage example:
        See the documented unittest of the `wait()` function

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.util.Timer;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.io.select.client.TimerSet;
import ocean.util.container.pool.ObjectPool;

import ocean.task.Task;
import ocean.task.Scheduler;

debug (TaskScheduler)
{
    import ocean.io.Stdout;
}

version (UnitTest)
{
    import ocean.core.Test;
    import core.thread;
}

/*******************************************************************************

    Suspends the current fiber/task and resumes it again after `micro_seconds`
    microseconds.

    Params:
        micro_seconds = amount of microseconds to suspend for

*******************************************************************************/

public void wait ( uint micro_seconds )
{
    if (micro_seconds == 0)
        return;

    auto task = Task.getThis();
    assert (task !is null);

    if (.timer is null)
        .timer = new typeof(timer);

    auto scheduled_event =  .timer.schedule(
        // EventData setup is run from the same fiber so it is ok to reference
        // variable from this function stack
        ( ref EventData event )
        {
            event.to_resume = task;
        },
        // Callback of fired timer is run from epoll context and here it is
        // only legal to use data captured as EventData field (or other heap
        // allocated data)
        ( ref EventData event )
        {
            debug_trace("Resuming task <{}> by timer",
                cast(void*) event.to_resume);
            event.to_resume.resume();
        },
        micro_seconds
    );

    task.terminationHook(&scheduled_event.unregister);

    debug_trace("Suspending task <{}> for {} microseconds",
        cast(void*) task, micro_seconds);
    task.suspend();

    task.removeTerminationHook(&scheduled_event.unregister);
}

///
unittest
{
    initScheduler(SchedulerConfiguration.init);

    .timer = new typeof(timer);

    class SimpleTask : Task
    {
        override public void run ( )
        {
            for (int i = 0; i < 10; ++i)
                .wait(10);
        }
    }

    auto task = new SimpleTask;
    theScheduler.schedule(task);
    theScheduler.eventLoop();

    // NB: allocated event count is expected to be 1 more than strictly
    // necessary here because they are recycled only after task finishes
    // or suspend again, not immediately after it gets resumed on timer
    test!("==")(.timer.allocated_event_count(), 2);
}

/*******************************************************************************

    Implements timer event pool together with logic to handle arbitrary
    amount of events using single file descriptor. Allocated lazily when
    functions of this module are called.

*******************************************************************************/

private TimerSet!(EventData) timer;

/*******************************************************************************

    Event data to be used with timer scheduler. Simply contains reference
    to heap-allocated resumer closure (which is necessary to keep it valid
    after fiber suspends).

*******************************************************************************/

private struct EventData
{
    Task to_resume;
}

private void debug_trace ( T... ) ( cstring format, T args )
{
    debug ( TaskScheduler )
    {
        Stdout.formatln( "[ocean.task.util.Timer] " ~ format, args ).flush();
    }
}
