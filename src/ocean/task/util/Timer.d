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

    auto scheduled_event = registerResumeEvent(task, micro_seconds);
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
}

unittest
{
    // same as previous, but tests allocated event count inside `.timer` object

    initScheduler(SchedulerConfiguration.init);

    // re-create timer event pool to get rid of slots already allocated by other
    // test cases
    .timer = new typeof(.timer);

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

    Similar to `theScheduler.await` but also has waiting timeout. Calling task
    will be resumed either if awaited task finished or timeout is hit, whichever
    happens first.

    Params:
        task = task to await
        micro_seconds = timeout duration

    Returns:
        'true' if resumed via timeout, 'false' otherwise

*******************************************************************************/

public bool awaitOrTimeout ( Task task, uint micro_seconds )
{
    auto context = Task.getThis();
    assert (context !is null);

    auto scheduled_event = registerResumeEvent(context, micro_seconds);
    task.terminationHook(&scheduled_event.unregister);
    task.terminationHook(&context.resume);

    // force async scheduling to avoid checking if this context needs
    // suspend/resume and do it unconditionally
    theScheduler.queue(task);
    context.suspend();

    if (task.finished())
    {
        // resumed because awaited task has finished
        // timer was already unregistered by its termination hook, just quit
        return false;
    }
    else
    {
        // resumed because of timeout, need to clean up termination hooks of
        // awaited task to avoid double resume
        task.removeTerminationHook(&context.resume);
        task.removeTerminationHook(&scheduled_event.unregister);
        return true;
    }
}

///
unittest
{
    initScheduler(SchedulerConfiguration.init);

    static class InfiniteTask : Task
    {
        override public void run ( )
        {
            for (;;) .wait(100);
        }
    }

    static class RootTask : Task
    {
        Task to_wait_for;

        override public void run ( )
        {
            bool timeout = .awaitOrTimeout(this.to_wait_for, 200);
            test(timeout);

            // `awaitOrTimeout` itself won't terminate awaited task on timeout,
            // it will only "detach" it from the current context. If former is
            /// desired, it can be trivially done at the call site:
            if (timeout)
                this.to_wait_for.kill();
        }
    }

    auto root = new RootTask;
    root.to_wait_for = new InfiniteTask;

    theScheduler.schedule(root);
    theScheduler.eventLoop();

    test(root.finished());
    test(root.to_wait_for.finished());
}

unittest
{
    initScheduler(SchedulerConfiguration.init);

    static class FiniteTask : Task
    {
        override public void run ( )
        {
            .wait(100);
        }
    }

    static class RootTask : Task
    {
        Task to_wait_for;

        override public void run ( )
        {
            bool timeout = .awaitOrTimeout(this.to_wait_for, 500);
            test(!timeout);
            test(this.to_wait_for.finished());
        }
    }

    auto root = new RootTask;
    root.to_wait_for = new FiniteTask;

    theScheduler.schedule(root);
    theScheduler.eventLoop();

    test(root.finished());
    test(root.to_wait_for.finished());

}

/*******************************************************************************

    Implements timer event pool together with logic to handle arbitrary
    amount of events using single file descriptor. Allocated by
    `registerResumeEvent` on access.

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

/*******************************************************************************

    Helper function providing common code to schedule new timer event in a
    global `.timer` timer set.

    Allocates global `.timer` if not done already.

    Params:
        to_resume = task to resume when event fires
        micro_seconds = time to wait before event fires

    Returns:
        registered event interface

*******************************************************************************/

private TimerSet!(EventData).IEvent registerResumeEvent (
    Task to_resume, uint micro_seconds )
{
    if (timer is null)
        timer = new typeof(timer);

    return .timer.schedule(
        // EventData setup is run from the same fiber so it is ok to reference
        // variable from this function stack
        ( ref EventData event )
        {
            event.to_resume = to_resume;
        },
        // Callback of fired timer is run from epoll context and here it is
        // only legal to use data captured as EventData field (or other heap
        // allocated data)
        ( ref EventData event )
        {
            debug_trace("Resuming task <{}> by timer event",
                cast(void*) event.to_resume);
            event.to_resume.resume();
        },
        micro_seconds
    );
}

private void debug_trace ( T... ) ( cstring format, T args )
{
    debug ( TaskScheduler )
    {
        Stdout.formatln( "[ocean.task.util.Timer] " ~ format, args ).flush();
    }
}
