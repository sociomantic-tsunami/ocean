/*******************************************************************************

    Extends reusable fiber pool with task queue. Used in task scheduler
    as "default" way to schedule tasks.

    Copyright:
        Copyright (c) 2017 dunnhumby Germany GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.internal.FiberPoolWithQueue;

import core.thread : Fiber;

import ocean.meta.types.Qualifiers;
import ocean.core.Enforce;
import ocean.task.IScheduler;
import ocean.task.internal.FiberPool;
import ocean.task.Task;
import ocean.util.container.queue.FixedRingQueue;

debug (TaskScheduler)
    import ocean.io.Stdout;

/// Ditto
public class FiberPoolWithQueue : FiberPool
{
    /// Queue of tasks awaiting idle worker fiber to be executed in
    /* package(ocean.task) */
    public FixedRingQueue!(Task) queued_tasks;

    /// Thrown when all fibers are busy, task queue is full and no custom
    /// delegate to handle queue overflow is supplied.
    /* package(ocean.task) */
    public TaskQueueFullException queue_full_e;

    /***************************************************************************

        Called each time task is attempted to be queue but size limit is
        reached. Both the queue and the task will be supplied as arguments.

    ***************************************************************************/

    public TaskQueueFullCB task_queue_full_cb;

    /**************************************************************************

        Constructor

        Params:
            queue_limit = max size of task queue, recommened to be at least as
                large as pool limit
            stack_size = fiber stack size to use in this pool
            limit = limit to pool size. If set to 0 (default), there is no
                app limit and pool growth will be limited only by OS
                resources

    **************************************************************************/

    public this ( size_t queue_limit, size_t stack_size, size_t limit )
    {
        super(stack_size, limit);
        this.queued_tasks = new FixedRingQueue!(Task)(queue_limit);
        this.queue_full_e = new TaskQueueFullException;
    }

    /***************************************************************************

        Method used to queue the task for later execution.

        Will always put the task into the queue, even if there are idle worker
        fibers. This method is mostly useful when implementing advanced library
        facilities to ensure that no immediate execution takes place.

        Will result in starting the task in the next event loop cycle at the
        earliest.

        Params:
            task = derivative from `ocean.task.Task` defining some application
                task to execute

        Throws:
            TaskQueueFullException if task queue is at full capacity AND
            if no custom `task_queue_full_cb` is set.

    ***************************************************************************/

    public void queue ( Task task )
    {
        if (!this.queued_tasks.push(task))
        {
            debug_trace("trying to queue a task while task queue is full");

            if (this.task_queue_full_cb !is null)
                this.task_queue_full_cb(task, this.queued_tasks);
            else
                enforce(this.queue_full_e, false);
        }
        else
        {
            debug_trace(
                "task '{}' queued for delayed execution",
                cast(void*) task
            );
        }
    }

    /***************************************************************************

        Method used to execute a task.

        If there are idle worker fibers, the task will be executed immediately
        and this method will only return when that task first calls `suspend`.

        If all workers are busy, the task will be added to the queue and this
        method will return immediately.

        Params:
            task = derivative from `ocean.task.Task` defining some application
                task to execute

        Throws:
            TaskQueueFullException if task queue is at full capacity AND
            if no custom `task_queue_full_cb` is set.

    ***************************************************************************/

    public void runOrQueue ( Task task )
    {
        if (this.num_busy() >= this.limit())
        {
            this.queue(task);
            return;
        }

        auto fiber = this.get();
        debug_trace("running task <{}> via worker fiber <{}>",
            cast(void*) task, cast(void*) fiber);
        // `Task.entryPoint` is supposed to be entry method for worker fiber
        // but it does not allow to reuse worker fiber immediately for new tasks
        // waititing in the queue. Because of that a custom method is used as
        // entry point instead which will internally call `Task.entryPoint`
        // directly:
        task.assignTo(fiber, &this.workerFiberMethod);
        task.resume();
    }

    /***************************************************************************

        Set in runOrQueue() as a "real" fiber entry method when a task is
        assigned to a worker fiber.

        Takes care of:
        - recycling both task and worker fiber after main task method finishes
        - reusing current worker fiber to run new scheduled tasks if there are
            any

    ***************************************************************************/

    private void workerFiberMethod ( )
    {
        auto fiber = cast(WorkerFiber) Fiber.getThis();
        enforce(fiber !is null);
        auto task = fiber.activeTask();
        enforce(task !is null);

        void runTask ( )
        {
            bool had_exception = task.entryPoint();

            // in case task was resumed after unhandled exception, delay further
            // execution for one cycle to avoid situation where exception handler
            // calls `Task.continueAfterThrow()` and that throws again
            if (had_exception)
                theScheduler.processEvents();

            // makes impossible to use the task by an accident in the period
            // between finishing it here and getting it started anew after
            // recycling
            task.fiber = null;
        }

        runTask();

        while (this.queued_tasks.pop(task))
        {
            // there are some scheduled tasks in the queue. it is best for
            // latency and performance to start one of those immediately in
            // current fiber instead of going through recycle+get again
            debug_trace("Reusing worker fiber <{}> to run scheduled task <{}>",
                cast(void*) fiber, cast(void*) task);

            task.assignTo(fiber);
            runTask();
        }

        // there are no scheduled tasks right now, can simply recycle
        // worker fiber for future usage
        debug_trace("Recycling worker fiber <{}>", cast(void*) fiber);
        this.recycle(fiber);
    }
}

/******************************************************************************

    See `FiberPoolWithQueue.task_queue_full_cb`

******************************************************************************/

public alias void delegate(Task, FixedRingQueue!(Task)) TaskQueueFullCB;


private void debug_trace ( T... ) ( cstring format, T args )
{
    debug ( TaskScheduler )
    {
        Stdout.formatln( "[ocean.task.internal.FiberPoolWithQueue] "
            ~ format, args ).flush();
    }
}
