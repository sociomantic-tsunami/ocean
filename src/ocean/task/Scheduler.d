/*******************************************************************************

    This module provides the standard task scheduler and a singleton object
    instance of it. The developer must call the `initScheduler` function to get
    the singleton into a usable state.

    Usage example:
        See the documented unittest of the `Scheduler` class

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.Scheduler;


import core.thread;

import ocean.transition;
import ocean.core.Enforce;
import ocean.core.Verify;
import ocean.core.TypeConvert;
import ocean.core.Optional;
import ocean.io.select.EpollSelectDispatcher;
import ocean.util.container.queue.FixedRingQueue;
import ocean.meta.traits.Indirections;

import ocean.task.Task;
import ocean.task.IScheduler;
import ocean.task.internal.FiberPoolWithQueue;
import ocean.task.internal.SpecializedPools;
import ocean.task.util.Timer;

version (UnitTest)
{
    import ocean.core.Test;
    import ocean.io.Stdout;
    import core.stdc.stdlib : abort;
}

debug (TaskScheduler)
{
    import ocean.io.Stdout;
}

public alias IScheduler.Configuration SchedulerConfiguration;
public alias IScheduler.Stats SchedulerStats;

/*******************************************************************************

    Implementation of the IScheduler API

*******************************************************************************/

final class Scheduler : IScheduler
{
    /***************************************************************************

        Tracks scheduler internal state to safeguard against harmful operations

    ***************************************************************************/

    private enum State
    {
        /// Initial configured state
        Initial,
        /// Set when `eventLoop` method starts
        Running,
        /// Set when shutdown sequence is initiated and normal mode of operations
        /// has to be prevented.
        Shutdown
    }

    /// ditto
    private State state = State.Initial;

    /***************************************************************************

        Worker fiber pool, allows reusing fiber memory to run different tasks

    ***************************************************************************/

    private FiberPoolWithQueue fiber_pool;

    /***************************************************************************

        Indicates if this.selectCycleHook is already registered for the next
        epoll cycle.

    ***************************************************************************/

    bool select_cycle_hook_registered;

    /***************************************************************************

        Used internally by scheduler to do all event handling

    ***************************************************************************/

    private EpollSelectDispatcher _epoll;

    /***************************************************************************

        Optional mapping from some Task ClasInfo's to dedicated worker
        fiber pools.

    ***************************************************************************/

    private SpecializedPools specialized_pools;

    /***************************************************************************

        Tracks how many tasks are currently pending resume via epoll
        cycle callbacks.

    ***************************************************************************/

    private size_t cycle_pending_task_count;

    /***************************************************************************

        Getter for scheduler epoll instance. Necessary for integration with
        `ISelectClient` utilities so that new select client can be registered.

        Returns:
            internally used epoll instance

    ***************************************************************************/

    public EpollSelectDispatcher epoll ( )
    {
        assert (this._epoll !is null);
        return this._epoll;
    }

    /***************************************************************************

        Set delegate to call each time task is attempted to be queue but size
        limit is reached. Both the queue and the task will be supplied as
        arguments.

    ***************************************************************************/

    public void task_queue_full_cb ( scope TaskQueueFullCB dg )
    {
        this.fiber_pool.task_queue_full_cb = dg;
    }

    /***************************************************************************

        Gets current callback for case of full queue

    ***************************************************************************/

    public TaskQueueFullCB task_queue_full_cb ( )
    {
        return this.fiber_pool.task_queue_full_cb;
    }

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
                "\ttask_queue_limit = {}\n",
            config.worker_fiber_stack_size,
            config.worker_fiber_limit,
            config.task_queue_limit
        );

        verify(
            config.task_queue_limit >= config.worker_fiber_limit,
            "Must configure task queue size at least equal to worker fiber " ~
                "count for optimal task scheduler performance."
        );

        if (epoll is null)
            this._epoll = new EpollSelectDispatcher;
        else
            this._epoll = epoll;

        this.fiber_pool = new FiberPoolWithQueue(
            config.task_queue_limit,
            config.worker_fiber_stack_size,
            config.worker_fiber_limit
        );

        this.specialized_pools = new SpecializedPools(config.specialized_pools);
    }

    /***************************************************************************

        Forces early termination of all active tasks and shuts down
        event loop.

        After this method has been called any attempt to interact with
        the scheduler will kill the calling task.

    ***************************************************************************/

    public void shutdown ( )
    {
        // no-op if already shutting down
        if (this.state == State.Shutdown)
            return;

        debug_trace(
            "Shutting down initiated. {} queued tasks will be discarded",
            this.fiber_pool.queued_tasks.length()
        );

        this.state = State.Shutdown;
        this.fiber_pool.queued_tasks.clear();
        this.epoll.shutdown();

        auto task = Task.getThis();
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
            task_queue_busy : this.fiber_pool.queued_tasks.length(),
            task_queue_total : this.fiber_pool.queued_tasks.maxItems(),
            suspended_tasks : this.cycle_pending_task_count,
            worker_fiber_busy : this.fiber_pool.num_busy(),
            worker_fiber_total : this.fiber_pool.limit()
        };
        return stats;
    }

    /***************************************************************************

        Returns:
            Stats struct for a specialized pool defined by `name` if there is
            such pool. Empty Optional otherwise.

    ***************************************************************************/

    public Optional!(SpecializedPoolStats) getSpecializedPoolStats ( cstring name )
    {
        Optional!(SpecializedPoolStats) result;

        this.specialized_pools.findPool(name).visit(
            ( ) { },
            (ref SpecializedPools.SpecializedPool descr) {
                result = optional(SpecializedPoolStats(
                    descr.pool.num_busy(),
                    descr.pool.length()
                ));
            }
        );

        return result;
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
        if (this.state == State.Shutdown)
        {
            // Simply returning here would be generally sufficient to make sure
            // no new tasks get added after shutdown. However, it is of some
            // merit to try to kill everything as soon as possible thus
            // scheduler kills the caller tasks on any attempt to schedule a new
            // one.
            auto caller_task = Task.getThis();
            if (caller_task !is null)
                caller_task.kill();
            return;
        }

        try
        {
            if (!this.specialized_pools.run(task))
            {
                this.fiber_pool.runOrQueue(task);
                this.registerCycleCallback();
            }
        }
        catch (Exception e)
        {
            if (this.exception_handler !is null)
                this.exception_handler(task, e);
            else
                throw e;
        }
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
        this.fiber_pool.queue(task);
        this.registerCycleCallback();
    }

    /***************************************************************************

        Schedules the argument and suspends calling task until the argument
        finishes.

        This method must not be called outside of a task.

        If `task` is already scheduled, it will not be re-scheduled again but
        awaiting will still occur.

        Params:
            task = task to schedule and wait for
            finished_dg = optional delegate called after task finishes but
                before it gets recycled, can be used to copy some data into
                caller fiber context

    ***************************************************************************/

    public void await ( Task task, scope void delegate (Task) finished_dg = null )
    {
        auto context = Task.getThis();
        assert (context !is null);
        assert (context !is task);

        // this methods stack is guaranteed to still be valid by the time
        // task finishes, so we can reference `task` from delegate
        task.terminationHook({
            if (context.suspended())
                theScheduler.delayedResume(context);
        });

        if (finished_dg !is null)
            task.terminationHook({ finished_dg(task); });

        if (!task.suspended())
            this.schedule(task);

        if (!task.finished())
            context.suspend();
    }

    ///
    unittest
    {
        void example ( )
        {
            static class ExampleTask : Task
            {
                mstring data;

                override void run ( )
                {
                    // do things that may result in suspending ...
                    data = "abcd".dup;
                }

                override void recycle ( )
                {
                    this.data = null;
                }
            }

            mstring data;

            theScheduler.await(
                new ExampleTask,
                (Task t) {
                    // copy required data before tasks gets recycled
                    auto task = cast(ExampleTask) t;
                    data = task.data.dup;
                }
            );

            test!("==")(data, "abcd");
        }
    }

    /***************************************************************************

        Convenience shortcut on top of `await` to await for a task and return
        some value type as a result.

        If `task` is already scheduled, it will not be re-scheduled again but
        awaiting will still occur.

        Params:
            task = any task that defines `result` public field  of type with no
                indirections

        Returns:
            content of `result` field of the task read right after that task
            finishes

    ***************************************************************************/

    public typeof(TaskT.result) awaitResult ( TaskT : Task ) ( TaskT task )
    {
        static assert (
            !hasIndirections!(typeof(task.result)),
            "'awaitResult' can only work with result types with no indirection"
        );
        typeof(task.result) result;
        this.await(task, (Task t) { result = (cast(TaskT) t).result; });
        return result;
    }

    ///
    unittest
    {
        void example ( )
        {
            static class ExampleTask : Task
            {
                int result;

                override void run ( )
                {
                    // do things that may result in suspending ...
                    this.result = 42;
                }

                override void recycle ( )
                {
                    this.result = 43;
                }
            }

            auto data = theScheduler.awaitResult(new ExampleTask);
            test!("==")(data, 42);
        }
    }

    /***************************************************************************

        Similar to `await` but also has waiting timeout. Calling task will be
        resumed either if awaited task finished or timeout is hit, whichever
        happens first.

        If `task` is already scheduled, it will not be re-scheduled again but
        awaiting will still occur.

        Params:
            task = task to await
            micro_seconds = timeout duration

        Returns:
            'true' if resumed via timeout, 'false' otherwise

    ***************************************************************************/

    public bool awaitOrTimeout ( Task task, uint micro_seconds )
    {
        return ocean.task.util.Timer.awaitOrTimeout(task, micro_seconds);
    }

    /***************************************************************************

        Starts pseudo-infinite event loop. Event loop will keep running as long
        as there is at least one event registered.

        Throws:
            SanityException if there are some active worker fibers
            left in the pool by the time there are not events left

    ***************************************************************************/

    public void eventLoop ( )
    {
        assert (this.state != State.Shutdown);
        this.state = State.Running;

        debug_trace("Starting scheduler event loop");

        do
        {
            this.epoll.eventLoop(
                null,
                this.exception_handler is null ? null :
                    &this.exceptionHandlerForEpoll
            );

            debug_trace(
                "end of scheduler internal event loop cycle " ~
                    "({} worker fibers still suspended, " ~
                    "{} pending tasks to resume)",
                this.fiber_pool.num_busy(),
                this.cycle_pending_task_count
            );

        }
        while ((this.fiber_pool.queued_tasks.length ||
            this.cycle_pending_task_count) && this.state != State.Shutdown);

        // cleans up any stalled worker fibers left after deregistration
        // of all events.
        scope iterator = this.fiber_pool.new BusyItemsIterator;
        foreach (ref fiber; iterator)
            fiber.active_task.kill();
        this.specialized_pools.kill();

        verify(this.fiber_pool.num_busy() == 0);
        verify(this.fiber_pool.queued_tasks.length() == 0);
    }

    /***************************************************************************

        Orders scheduler to resume given task unconditionally after current
        epoll cycle. Must be used instead of plain `Task.resume` from
        termination hooks of other tasks.

        Params:
            task = task object to resume on next cycle

    ***************************************************************************/

    public void delayedResume ( Task task )
    {
        static void resumer ( void* task_ )
        {
            auto task = cast(Task) task_;
            theScheduler.cycle_pending_task_count--;

            try
            {
                task.resume();
            }
            catch (Exception e)
            {
                if (theScheduler.exception_handler !is null)
                    theScheduler.exception_handler(task, e);
                else
                    throw e;
            }
        }

        auto cb = toContextDg!(resumer)(cast(void*) task);
        this.cycle_pending_task_count++;
        this.epoll.onCycleEnd(cb);

        debug_trace("task <{}> will be resumed after current epoll cycle",
            cast(void*) task);
    }

    /***************************************************************************

        Suspends current fiber temporarily, allowing pending events to be
        processed. Current fiber will be resumed as soon as no immediate events
        are left.

        Throws:
            SuspendQueueFullException if suspending is not possible because
            resuming queue is full

    ***************************************************************************/

    public void processEvents ( )
    {
        auto task = Task.getThis();
        if (this.state == State.Shutdown)
            task.kill();

        this.delayedResume(task);
        task.suspend();
    }

    /***************************************************************************

        Registers cycle callback if it is not already present (to avoid
        duplicates)

    ***************************************************************************/

    private void registerCycleCallback ( )
    {
        if (!this.select_cycle_hook_registered)
        {
            this.select_cycle_hook_registered = true;
            this.epoll.onCycleEnd(&this.selectCycleHook);
        }
    }

    /***************************************************************************

        This method gets called each time `this._epoll.select()` cycle
        finishes. It takes care of suspended task queue
        ensuring everything will get resumed/run eventually.

    ***************************************************************************/

    private void selectCycleHook ( )
    {
        // if there are tasks in the queue AND free worker fibers, process some

        while (this.fiber_pool.num_busy() < this.fiber_pool.limit()
            && this.fiber_pool.queued_tasks.length)
        {
            Task task;
            auto success = this.fiber_pool.queued_tasks.pop(task);
            assert(success);
            this.schedule(task);
        }

        if (this.fiber_pool.queued_tasks.length)
            this.epoll.onCycleEnd(&this.selectCycleHook);
        else
            this.select_cycle_hook_registered = false;
    }

    /***************************************************************************

        Wraps configured `exception_handler` into API that doesn't refer to
        tasks and thus is usable by EpollSelectDispatcher

        Params:
            e = unhandled exception instance

        Returns:
            'true` if 'this.exception_handler' is not null, 'false' otherwise

    ***************************************************************************/

    private bool exceptionHandlerForEpoll ( Exception e )
    {
        if (this.exception_handler !is null)
        {
            this.exception_handler(null, e);
            return true;
        }
        else
            return false;
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

            static immutable very_long_loop = 5;

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

    int queue_full_hits = 0;
    theScheduler.exception_handler = (Task t, Exception e) {
        if (cast(TaskQueueFullException) e)
            queue_full_hits++;
    };

    class DummyTask : Task
    {
        override public void run ( ) { theScheduler.processEvents(); }
    }

    // goes to worker fiber ..
    theScheduler.schedule(new DummyTask);
    // goes to queue ..
    theScheduler.schedule(new DummyTask);
    // boom!
    test!("==")(queue_full_hits, 0);
    theScheduler.schedule(new DummyTask);
    test!("==")(queue_full_hits, 1);

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
{
    assert(_scheduler !is null, "Scheduler is null, initScheduler must be called before using it");

    return _scheduler;
}

/*******************************************************************************

    Returns:
        'true' if scheduler system was initialized, 'false' otherwise

*******************************************************************************/

public bool isSchedulerUsed ( )
{
    return _scheduler !is null;
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
            && _scheduler.fiber_pool.queued_tasks.length() == 0;
    }

    if (_scheduler !is null)
        assert (is_scheduler_unused());

    _scheduler = new Scheduler(config, epoll);

    version(UnitTest)
    {
        _scheduler.exception_handler = (Task t, Exception e) {
            if (t !is null)
            {
                Stderr.formatln(
                    "Unhandled exception in task {} ({})",
                    cast(void*) t, t.classinfo.name
                );
            }
            else
            {
                Stderr.formatln("Unhandled exception in epoll/scheduler");
            }

            Stderr.formatln("\t{} ({}:{})", e.message(), e.file, e.line)
                .flush();

            abort();
        };
    }

    // set interface-based global scheduler getter in IScheduler module:
    ocean.task.IScheduler._scheduler = _scheduler;
}

/*******************************************************************************

    Private variable that stores the singleton object

*******************************************************************************/

private Scheduler _scheduler;

public alias ocean.task.IScheduler.TaskQueueFullException
    TaskQueueFullException;

public alias ocean.task.IScheduler.SuspendQueueFullException
    SuspendQueueFullException;

private void debug_trace ( T... ) ( cstring format, T args )
{
    debug ( TaskScheduler )
    {
        Stdout.formatln( "[ocean.task.Scheduler] " ~ format, args ).flush();
    }
}
