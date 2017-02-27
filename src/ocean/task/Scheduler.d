/*******************************************************************************

    This module provides the standard task scheduler and a singleton object
    instance of it. The developer must call the `initScheduler` function to get
    the singleton into a usable state.

    Usage example:
        See the documented unittest of the `Scheduler` class

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.Scheduler;

/*******************************************************************************

    Imports

*******************************************************************************/

import core.thread;

import ocean.transition;
import ocean.core.Enforce;
import ocean.core.array.Mutation : reverse;
import ocean.io.select.EpollSelectDispatcher;
import ocean.util.container.queue.FixedRingQueue;

import ocean.task.Task;
import ocean.task.internal.FiberPool;

version (UnitTest)
{
    import ocean.core.Test;
}

debug (TaskScheduler)
{
    import ocean.io.Stdout;
}

/*******************************************************************************

    Aggregation of various size limits used internally by scheduler. Instance
    of this struct is used as `initScheduler` argument.

    Default values of scheduler configuration are picked for convenient usage
    of `SchedulerConfiguration.init` in tests - large stack size but small
    queue limits.

*******************************************************************************/

struct SchedulerConfiguration
{
    /// stack size allocated for all worker fibers created by the scheduler
    size_t worker_fiber_stack_size = 102400;

    /// maximum amount of simultaneous worker fibers in the scheduler pool
    size_t worker_fiber_limit = 5;

    /// maximum amount of tasks awaiting scheduling in the queue while all
    /// worker fibers are busy
    size_t task_queue_limit = 10;

    /// maximum amount of tasks that can be suspended via
    /// `theScheduler.processEvents` in between scheduler dispatch cycles
    size_t suspended_task_limit = 16;
}

/*******************************************************************************

    Aggregate of various statistics that indicate overall scheduler load
    and performance.

*******************************************************************************/

struct SchedulerStats
{
    size_t task_queue_busy;
    size_t task_queue_total;
    size_t suspended_queue_busy;
    size_t suspended_queue_total;
    size_t worker_fiber_busy;
    size_t worker_fiber_total;
}

/*******************************************************************************

    Scheduler class handles concurrent execution of all application tasks,
    assigning them to limited amount of worker fibers. Scheduler functionality
    can be split into 3 major blocks:

    1. executing arbitrary `ocean.task.Task` using a worker fiber from a pool
    2. keeping queue of tasks to execute in cases when all worker fibers are
       busy
    3. allowing any task to suspend to allow event processing by epoll in a way
       that it will be automatically resumed by scheduler again when there are
       no more immediate pending events

*******************************************************************************/

final class Scheduler
{
    /***************************************************************************

        Set when shutdown sequence is initiated and normal mode of operations
        has to be prevented.

    ***************************************************************************/

    private bool shutting_down = false;

    /***************************************************************************

        Thrown instead of `AssertError` when scheduler sanity is violated. Such
        issues are almost impossible to reason about if not caught in time
        thus we want all sanity checks to remain even in `-release` mode.

    ***************************************************************************/

    private SchedulerSanityException sanity_e;

    /***************************************************************************

        Thrown when all fibers are busy, task queue is full and no custom
        delegate to handle queue overflow is supplied.

    ***************************************************************************/

    private TaskQueueFullException queue_full_e;

    /***************************************************************************

        Thrown when task is being added for later resuming via
        Scheduler.processEvents but matching queue is full

    ***************************************************************************/

    private SuspendQueueFullException suspend_queue_full_e;

    /***************************************************************************

        Worker fiber pool, allows reusing fiber memory to run different tasks

    ***************************************************************************/

    private FiberPool fiber_pool;

    /***************************************************************************

        Used internally by scheduler to do all event handling

    ***************************************************************************/

    private EpollSelectDispatcher _epoll;

    /***************************************************************************

        Getter for scheduler epoll instance. Necessary for integration with
        `ISelectClient` utilities so that new select event can be registered.

        Returns:
            internally used epoll instance

    ***************************************************************************/

    public EpollSelectDispatcher epoll ( )
    {
        assert (this._epoll !is null);
        return this._epoll;
    }

    /***************************************************************************

        Queue of tasks awaiting idle worker fiber to be executed in

    ***************************************************************************/

    private FixedRingQueue!(Task) queued_tasks;

    /***************************************************************************

        Queue of tasks to be resumed after next `this._epoll.select()` finishes

    ***************************************************************************/

    private FixedRingQueue!(Task) suspended_tasks;

    /***************************************************************************

        Called each time task is attempted to be queue but size limit is
        reached. Both the queue and the task will be supplied as arguments.

    ***************************************************************************/

    public void delegate ( Task, FixedRingQueue!(Task) ) task_queue_full_cb;

    /***************************************************************************

        Called each time task terminates with an exception when being run in
        context of the scheduler or the event loop.

        NB: the task reference will be null when the delegate is called from the
        EpollSelectDispatcher context (i.e. if task threw after resuming from
        an event callback)

    ***************************************************************************/

    public void delegate ( Task, Exception ) exception_handler;

    /***************************************************************************

        Temporary storage used to pass currently used worker into the
        fiber function so that it can make copy of it on stack and handle the
        recycling in the end of fiber function.

        Content is undefined in all situation but starting new task.

    ***************************************************************************/

    private WorkerFiber last_used_worker;

    /***************************************************************************

        Temporary storage used to pass currently used worker into the
        fiber function so that it can make copy of it on stack and handle the
        recycling in the end of fiber function.

        Content is undefined in all situation but starting new task.

    ***************************************************************************/

    private Task last_scheduled_task;

    /***************************************************************************

        Constructor

        Params:
            config = see `.SchedulerConfiguration`
            epoll  = epoll instance to use for internal event loop. If null,
                Scheduler will create new instance with default arguments

    ***************************************************************************/

    private this ( SchedulerConfiguration config,
        EpollSelectDispatcher epoll = null )
    {
        debug_trace(
            "Creating new Scheduler with following configuration:\n" ~
                "\tworker_fiber_stack_size = {}\n" ~
                "\tworker_fiber_limit = {}\n" ~
                "\ttask_queue_limit = {}\n" ~
                "\tsuspended_task_limit = {}",
            config.worker_fiber_stack_size,
            config.worker_fiber_limit,
            config.task_queue_limit,
            config.suspended_task_limit
        );

        this.sanity_e = new SchedulerSanityException;
        this.queue_full_e = new TaskQueueFullException;
        this.suspend_queue_full_e = new SuspendQueueFullException;

        enforce(
            this.sanity_e,
            config.task_queue_limit >= config.worker_fiber_limit,
            "Must configure task queue size at least equal to worker fiber " ~
                "count for optimal task scheduler performance."
        );

        if (epoll is null)
            this._epoll = new EpollSelectDispatcher;
        else
            this._epoll = epoll;

        this.fiber_pool = new FiberPool(
            config.worker_fiber_stack_size,
            config.worker_fiber_limit
        );

        this.queued_tasks = new FixedRingQueue!(Task)(config.task_queue_limit);
        this.suspended_tasks = new FixedRingQueue!(Task)(config.suspended_task_limit);
    }

    /***************************************************************************

        Forces early termination of all active tasks and shuts down
        event loop.

        After this method has been called any attempt to interact with
        the scheduler will kill the calling task.

    ***************************************************************************/

    public void shutdown ( )
    {
        debug_trace("Shutting down initiated. {} queued tasks will be " ~
            " discardead, {} suspended tasks will be killed",
            this.queued_tasks.length(), this.suspended_tasks.length());

        this.shutting_down = true;
        this.queued_tasks.clear();

        Task task;
        while (this.suspended_tasks.pop(task))
            task.kill();
        this.epoll.shutdown();

        task = Task.getThis();
        if (task !is null)
            task.kill();
    }

    /***************************************************************************

        Provides load stats for the scheduler

        Common usage examples would be load throttling and load stats recording.

        Returns:
            struct instance which aggregates all stats

    ***************************************************************************/

    public SchedulerStats getStats ( )
    {
        SchedulerStats stats =  {
            task_queue_busy : this.queued_tasks.length(),
            task_queue_total : this.queued_tasks.maxItems(),
            suspended_queue_busy : this.suspended_tasks.length(),
            suspended_queue_total : this.suspended_tasks.maxItems(),
            worker_fiber_busy : this.fiber_pool.num_busy(),
            worker_fiber_total : this.fiber_pool.limit()
        };
        return stats;
    }

    /***************************************************************************

        Method used to execute new task.

        If there are idle worker fibers, the task will be executed immediately
        and this method will only return when that task first calls `suspend`.

        If all workers are busy, the task will be added to the queue and this
        method will return immediately.

        Params:
            task = derivative from `ocean.task.Task` defining some application
                task to execute

        Throws:
            TaskQueueFullException if task queue is at full capacity

    ***************************************************************************/

    public void schedule ( Task task )
    {
        if (this.shutting_down)
        {
            auto caller_task = Task.getThis();
            if (caller_task !is null)
                caller_task.kill();
        }

        if (this.fiber_pool.num_busy() >= this.fiber_pool.limit())
        {
            if (!this.queued_tasks.push(task))
            {
                debug_trace("trying to schedule a task with all worker " ~
                    "fibers busy and task queue full");
                if (this.task_queue_full_cb !is null)
                    this.task_queue_full_cb(task, this.queued_tasks);
                else
                    enforce(this.queue_full_e, false);
            }
            else
            {
                debug_trace("delayed scheduling of task '{}' because all" ~
                    " worker fibers are busy", cast(void*) task);
            }
        }
        else
        {
            auto fiber = this.fiber_pool.get();
            debug_trace("running task <{}> via worker fiber <{}>",
                cast(void*) task, cast(void*) fiber);
            fiber.reset(&this.worker_fiber_method);
            task.assignTo(fiber);
            this.resumeTask(task);
        }
    }

    /***************************************************************************

        Starts pseudo-infinite event loop. Event loop will keep running as long
        as there is at least one event registered.

        Throws:
            SchedulerSanityException if there are some active worker fibers
            left in the pool by the time there are not events left

    ***************************************************************************/

    public void eventLoop ( )
    {
        do
        {
            this.epoll.eventLoop(
                &this.select_cycle_hook,
                this.exception_handler is null ? null : (Exception e) {
                        this.exception_handler(null, e);
                    }
            );
            debug_trace("end of scheduler internal event loop cycle ({} worker " ~
                "fibers still suspended)", this.fiber_pool.num_busy());

        }
        // handles corner case which is likely to only happen in synthetic
        // tests - when there are no/few events and tasks keep calling
        // `processEvents` in a loop
        while (this.suspended_tasks.length);

        // cleans up any stalled worker fibers left after deregistration
        // of all events.
        scope iterator = this.fiber_pool.new BusyItemsIterator;
        foreach (ref fiber; iterator)
            fiber.active_task.kill();

        enforce(this.sanity_e, this.fiber_pool.num_busy() == 0);
        enforce(this.sanity_e, this.queued_tasks.length() == 0);
        enforce(this.sanity_e, this.suspended_tasks.length() == 0);
    }

    /***************************************************************************

        Suspends current fiber temporarily, allowing pending events to be
        processed. Current fiber will be resumed as soon as no immediate events
        are left.

        Throws:
            SuspendQueueFullException if suspending is not possible because
            resuming queue is full

    ***************************************************************************/

    public void processEvents ( istring file = __FILE__, int line = __LINE__ )
    {
        auto task = Task.getThis();
        if (this.shutting_down)
            task.kill();

        enforceImpl(
            this.suspend_queue_full_e,
            this.suspended_tasks.push(task),
            this.suspend_queue_full_e.msg,
            file,
            line
        );

        debug_trace("task <{}> will be resumed after processing pending events",
            cast(void*) task);
        task.suspend();
    }

    /***************************************************************************

        Params:
            worker = reference to worker fiber item
            task   = task to run

        Throws:
            SchedulerSanityException on attempt to run new task from the very
            same fiber which would result in fiber resetting own state.

    ***************************************************************************/

    private void runTask ( WorkerFiber fiber, Task task )
    {
        task.assignTo(fiber);
        // execute the task
        bool had_exception = task.entryPoint();
        // allow task to recycle any shared resources it may have (or recycle
        // task instance itself)
        debug_trace("Recycling task <{}>", cast(void*) task);
        task.recycle();

        if (task.termination_hooks.length)
        {
            debug_trace("Calling {} termination_hooks for task <{}>",
                task.termination_hooks.length, cast(void*) task);

            auto hooks = reverse(task.termination_hooks[]);
            task.termination_hooks.reset();

            foreach (hook; hooks)
            {
                hook();
                assert(
                    task.termination_hooks.length == 0,
                    "Adding new hooks while running existing ones is not" ~
                        "supported"
                );
            }
        }

        // in case task was resumed after unhandled exception, delay further
        // execution for one cycle to avoid situation where exception handler
        // calls `Task.continueAfterThrow()` and that throws again
        if (had_exception)
            this.processEvents();
    }

    /***************************************************************************

        Set in schedule() as a "real" fiber entry method when a task is
        assigned to a worker fiber.

        Takes care of:
        - recycling both task and worker fiber after main task method finishes
        - reusing current worker fiber to run new scheduled tasks if there are
            any

    ***************************************************************************/

    private void worker_fiber_method ( )
    {
        auto fiber = cast(WorkerFiber) Fiber.getThis();
        enforce(fiber !is null);
        auto task = fiber.activeTask();
        enforce(task !is null);

        runTask(fiber, task);

        while (this.queued_tasks.pop(task) && !this.shutting_down)
        {
            // there are some scheduled tasks in the queue. it is best for
            // latency and performance to start one of those immediately in
            // current fiber instead of going through recycle+get again
            debug_trace("Reusing worker fiber <{}> to run scheduled task <{}>",
                cast(void*) fiber, cast(void*) task);

            runTask(fiber, task);
        }

        // there are no scheduled tasks right now, can simply recycle
        // worker fiber for future usage
        debug_trace("Recycling worker fiber <{}>", cast(void*) fiber);
        this.fiber_pool.recycle(fiber);
    }

    /***************************************************************************

        This method gets called each time `this._epoll.select()` cycle
        finishes. It takes care of suspended task queue
        ensuring everything will get resumed/run eventually.

        Returns:
            'true' if there are any pending tasks suspended via `processEvents`
            left, 'false' otherwise.

    ***************************************************************************/

    private bool select_cycle_hook ( )
    {
        // resuming queued tasks may result in more tasks being queued
        // to avoid `select_cycle_hook()` call being infinite, remember
        // initial count and process only that amount at one go
        size_t current_count = this.suspended_tasks.length;

        if (current_count)
            debug_trace("resuming {} tasks suspended via processEvents",
                current_count);

        for (auto i = 0; i < current_count; ++i)
        {
            Task task;
            enforce(this.sanity_e, this.suspended_tasks.pop(task));
            if (this.shutting_down)
                task.kill();
            else
                this.resumeTask(task);
        }

        return this.suspended_tasks.length > 0;
    }

    /***************************************************************************

        Helper method which combines recurring pattern of resuming some task
        and handling potential exceptions.

        Params:
            task = task to resume

    ***************************************************************************/

    private void resumeTask ( Task task )
    {
        try
        {
            task.resume();
        }
        catch (Exception e)
        {
            if (this.exception_handler !is null)
                this.exception_handler(task, e);
            else
                throw e;
        }
    }
}

///
unittest
{
    // mandatory scheduler initialziation, should happen only once in the app
    SchedulerConfiguration config;
    initScheduler(config);

    // example custom task type - its `run` method will be executed
    // within the context of the worker fiber to which it is assigned
    class TestTask : Task
    {
        static size_t started;
        static size_t recycled;

        override public void run ( )
        {
            ++TestTask.started;

            const very_long_loop = 5;

            for (int i = 0; i < very_long_loop; ++i)
            {
                // sometimes a task has to do lengthy computations
                // without any I/O like requests to remote servers. To avoid
                // completely blocking all other tasks, it should call the
                // `processEvents` method to pause briefly:
                theScheduler.processEvents();
            }
        }

        override public void recycle ( )
        {
            ++TestTask.recycled;
        }
    }

    // a task that can be processed by an idle worker fiber from the scheduler's
    // pool will be run immediately upon scheduling and yield on a call to
    // `processEvents`, keeping their assigned worker fibers busy:
    for (int i = 0; i < config.worker_fiber_limit; ++i)
        theScheduler.schedule(new TestTask);

    // new tasks scheduled while all worker fibers are busy will get pushed into
    // the scheduler's task queue to be run later on, when a worker fiber
    // finishes its current job:
    for (int i = 0; i < config.task_queue_limit; ++i)
        theScheduler.schedule(new TestTask);

    // when the task queue is full, any new scheduling attempt will result
    // in a TaskQueueFullException being thrown. However, it is possible to
    // specify a custom callback to handle the situation instead:
    theScheduler.task_queue_full_cb = ( Task, FixedRingQueue!(Task) ) { };
    theScheduler.schedule(new TestTask); // will do nothing now

    // all worker fibers are still waiting, suspended, now as the scheduler loop
    // isn't running, so there was nothing to resume them
    test!("==")(TestTask.started, config.worker_fiber_limit);
    test!("==")(TestTask.recycled, 0);

    // in a real application, this call will block the main thread for the
    // duration of the application and most resuming will be done by epoll
    // events
    theScheduler.eventLoop();
    test!("==")(TestTask.recycled,
        config.worker_fiber_limit + config.task_queue_limit);
}

unittest
{
    SchedulerConfiguration config;
    config.worker_fiber_limit = 1;
    config.task_queue_limit = 1;
    initScheduler(config);

    class DummyTask : Task
    {
        override public void run ( ) { theScheduler.processEvents(); }
    }

    // goes to worker fiber ..
    theScheduler.schedule(new DummyTask);
    // goes to queue ..
    theScheduler.schedule(new DummyTask);
    // boom!
    testThrown!(TaskQueueFullException)(theScheduler.schedule(new DummyTask));

    // cleanup remaining state before proceeding to other tests
    theScheduler.eventLoop();
}

unittest
{
    initScheduler(SchedulerConfiguration.init);

    class DummyTask : Task
    {
        override public void run ( ) { theScheduler.processEvents(); }
    }

    int result;
    auto task = new DummyTask;

    // use dummy dg to pre-allocate memory in hook array
    void delegate() dummy = { };

    task.terminationHook(dummy);
    task.terminationHook(dummy);
    task.removeTerminationHook(dummy);

    // test with real delegates, make sure closure is not allocated in D2
    testNoAlloc({
        task.terminationHook({ result = 1; });
        task.terminationHook({ result = 2; });
    }());

    theScheduler.schedule(task);
    theScheduler.eventLoop();

    test!("==")(result, 1);
}

/*******************************************************************************

    Singleton scheduler instance.

    `initScheduler` must be called before the singleton instance can be used.

    Returns:
        the global scheduler instance

*******************************************************************************/

public Scheduler theScheduler ( )
in
{
    assert(_scheduler !is null, "Scheduler is null, initScheduler must be called before using it");
}
body
{
    return _scheduler;
}

/*******************************************************************************

    Creates or re-creates the scheduler instance.

    Re-creating of scheduler is only allowed if previous one doesn't have
    any work remaining and is intended exclusively for ease of writing
    unittest blocks.

    Params:
        config = see `.SchedulerConfiguration`
        epoll  = existing epoll instance to use, if set to null, scheduler
            will create a new one

*******************************************************************************/

public void initScheduler ( SchedulerConfiguration config,
    EpollSelectDispatcher epoll = null )
{
    static bool is_scheduler_unused ( )
    {
        return _scheduler.fiber_pool.num_busy() == 0
            && _scheduler.suspended_tasks.length() == 0
            && _scheduler.queued_tasks.length() == 0;
    }

    if (_scheduler !is null)
        assert (is_scheduler_unused());

    _scheduler = new Scheduler(config, epoll);
}

/*******************************************************************************

    Private variable that stores the singleton object

*******************************************************************************/

private Scheduler _scheduler;

/******************************************************************************

    Exception thrown when scheduled task queue overflows

******************************************************************************/

public class TaskQueueFullException : Exception
{
    this ( )
    {
        super("Attempt to schedule a task when all worker fibers are busy "
            ~ " and delayed execution task queue is full");
    }
}

/******************************************************************************

    Exception thrown when suspended task queue overflows

******************************************************************************/

public class SuspendQueueFullException : Exception
{
    this ( )
    {
        super("Attempt to temporary suspend a task when resuming queue is full");
    }
}

/******************************************************************************

    Exception class that indicates scheduler internal sanity violation,
    for example, worker fiber leak.

******************************************************************************/

private class SchedulerSanityException : Exception
{
    this ( )
    {
        super("Internal sanity violation using the scheduler");
    }
}

private void debug_trace ( T... ) ( cstring format, T args )
{
    debug ( TaskScheduler )
    {
        Stdout.formatln( "[ocean.task.Scheduler] " ~ format, args ).flush();
    }
}
