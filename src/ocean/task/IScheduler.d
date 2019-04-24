/*******************************************************************************

    This module defines public API for `ocean.task.Scheduler` together with
    all involved data types. It is intended to be used in other modules instead
    of direct `ocean.task.Scheduler` import to untangle complex dependency chain
    the latter brings.

    Copyright:
        Copyright (c) 2017 dunnhumby Germany GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.IScheduler;

import core.thread;

import ocean.task.Task;
import ocean.meta.traits.Indirections : hasIndirections;
import ocean.meta.types.Qualifiers;
import ocean.io.select.EpollSelectDispatcher;
import ocean.core.Optional;

/*******************************************************************************

    Scheduler handles concurrent execution of all application tasks,
    assigning them to limited amount of worker fibers. Scheduler functionality
    can be split into 3 major blocks:

    1. executing arbitrary `ocean.task.Task` using a worker fiber from a pool
    2. keeping queue of tasks to execute in cases when all worker fibers are
       busy
    3. allowing any task to suspend to allow event processing by epoll in a way
       that it will be automatically resumed by scheduler again when there are
       no more immediate pending events

*******************************************************************************/

public interface IScheduler
{
    /***************************************************************************

        Aggregation of various size limits used internally by scheduler.
        Instance of this struct is used as `initScheduler` argument.

        Default values of scheduler configuration are picked for convenient
        usage of `SchedulerConfiguration.init` in tests - large stack size but
        small queue limits.

    ***************************************************************************/

    public struct Configuration
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
        deprecated("Ignored, there is no limit anymore")
        size_t suspended_task_limit = 16;

        /// optional array that defines specialized worker fiber pools to be
        /// used for handling specific task kinds. Scheduled task is checked
        /// against this array every time thus it is not recommended to configure
        /// it to more than a few dedicated extra pools
        PoolDescription[] specialized_pools;

        /// Defines single mapping of `ClassInfo` to worker fiber pool in
        /// configuration
        public struct PoolDescription
        {
            /// fully qualified name (same as `Task.classinfo.name()`) for task
            /// type which is to be handled by this pool
            istring task_name;

            /// worker fiber allocated stack size
            size_t stack_size;
        }
    }

    /***************************************************************************

        Aggregate of various statistics that indicate overall scheduler load
        and performance.

    ***************************************************************************/

    public struct Stats
    {
        size_t task_queue_busy;
        size_t task_queue_total;
        deprecated("Replaced by single `suspended_tasks`")
        size_t suspended_queue_busy;
        deprecated("Replaced by single `suspended_tasks`")
        size_t suspended_queue_total;
        size_t suspended_tasks;
        size_t worker_fiber_busy;
        size_t worker_fiber_total;
    }

    /***************************************************************************

        Usage stats of a single specialized task pool

    ***************************************************************************/

    public struct SpecializedPoolStats
    {
        size_t used_fibers;
        size_t total_fibers;
    }

    /***************************************************************************

        Getter for scheduler epoll instance. Necessary for integration with
        `ISelectClient` utilities so that new select client can be registered.

        Returns:
            internally used epoll instance

    ***************************************************************************/

    public EpollSelectDispatcher epoll ( );

    /***************************************************************************

        Forces early termination of all active tasks and shuts down
        event loop.

        After this method has been called any attempt to interact with
        the scheduler will kill the calling task.

    ***************************************************************************/

    public void shutdown ( );

    /***************************************************************************

        Provides load stats for the scheduler

        Common usage examples would be load throttling and load stats recording.

        Returns:
            struct instance which aggregates all stats

    ***************************************************************************/

    public Stats getStats ( );

    /***************************************************************************

        Returns:
            Stats struct for a specialized pool defined by `name` if there is
            such pool. Empty Optional otherwise.

    ***************************************************************************/

    public Optional!(SpecializedPoolStats) getSpecializedPoolStats ( cstring name );

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

    public void schedule ( Task task );

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

    public void queue ( Task task );

    /***************************************************************************

        Schedules the argument and suspends calling task until the argument
        finishes.

        This method must not be called outside of a task.

        Because of how termination hooks are implemented, by the time `await`
        returns, the task object is not yet completely recycled - it will only
        happen during next context switch. Caller of `await` must either ensure
        that the task object lives long enough for that or call
        `theScheduler.processEvents` right after `await` to ensure immediate
        recycle (at the performance cost of an extra context switch).

        Params:
            task = task to schedule and wait for
            finished_dg = optional delegate called after task finishes but
                before it gets recycled, can be used to copy some data into
                caller fiber context

    ***************************************************************************/

    public void await ( Task task, scope void delegate (Task) finished_dg = null );

    /***************************************************************************

        Convenience shortcut on top of `await` to await for a task and return
        some value type as a result.

        Params:
            task = any task that defines `result` public field  of type with no
                indirections

        Returns:
            content of `result` field of the task read right after that task
            finishes

    ***************************************************************************/

    public final typeof(TaskT.result) awaitResult ( TaskT : Task ) ( TaskT task )
    {
        static assert (
            !hasIndirections!(typeof(task.result)),
            "'awaitResult' can only work with result types with no indirection"
        );
        typeof(task.result) result;
        this.await(task, (Task t) { result = (cast(TaskT) t).result; });
        return result;
    }

    /***************************************************************************

        Similar to `await` but also has waiting timeout. Calling task will be
        resumed either if awaited task finished or timeout is hit, whichever
        happens first.

        Params:
            task = task to await
            micro_seconds = timeout duration

        Returns:
            'true' if resumed via timeout, 'false' otherwise

    ***************************************************************************/

    public bool awaitOrTimeout ( Task task, uint micro_seconds );

    /***************************************************************************

        Orders scheduler to resume given task unconditionally after current
        epoll cycle. Must be used instead of plain `Task.resume` from
        termination hooks of other tasks.

        Params:
            task = task object to resume on next cycle

        Throws:
            SuspendQueueFullException if resuming queue is full

    ***************************************************************************/

    public void delayedResume ( Task task );

    /***************************************************************************

        Suspends current fiber temporarily, allowing pending events to be
        processed. Current fiber will be resumed as soon as no immediate events
        are left.

        Throws:
            SuspendQueueFullException if suspending is not possible because
            resuming queue is full

    ***************************************************************************/

    public void processEvents ( );

    /***************************************************************************

        Starts pseudo-infinite event loop. Event loop will keep running as long
        as there is at least one event registered.

        Throws:
            SanityException if there are some active worker fibers
            left in the pool by the time there are not events left

    ***************************************************************************/

    public void eventLoop ( );
}

/*******************************************************************************

    Singleton scheduler instance, same as `ocean.task.Scheduler.theScheduler`
    but returns that object as `IScheduler` interface.

    Returns:
        the global scheduler instance

*******************************************************************************/

public IScheduler theScheduler ( )
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

version (UnitTest)
{
    /***************************************************************************

        Occasionally useful in tests to drop reference to already initialized
        scheduler and test some code as if scheduler is not present.

    ***************************************************************************/

    public void dropScheduler ( )
    {
        _scheduler = null;
    }
}

/*******************************************************************************

    Initialized externally from `ocean.task.Scheduler` to reference the same
    singleton object.

*******************************************************************************/

package IScheduler _scheduler;

/******************************************************************************

    Exception thrown when suspended task queue overflows

******************************************************************************/

deprecated("Not thrown anymore")
public class SuspendQueueFullException : Exception
{
    this ( )
    {
        super("Attempt to temporary suspend a task when resuming queue is full");
    }
}

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
