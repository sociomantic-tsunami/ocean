/*******************************************************************************

    Adds functionality to suspend/resume registered ISuspendable instances
    based on the number of active tasks in the task pool.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.ThrottledTaskPool;

import ocean.task.TaskPool;
import ocean.task.Task;
import ocean.task.IScheduler;
import ocean.text.convert.Formatter;

import ocean.io.model.ISuspendableThrottler;
import ocean.util.container.pool.model.IPoolInfo;
import ocean.util.container.pool.model.ILimitable;

import ocean.meta.traits.Aggregates /* : hasMethod */;
import ocean.meta.types.Function /* ParametersOf */;

import ocean.transition;
import ocean.core.Verify;

debug (TaskScheduler)
    import ocean.io.Stdout;

/*******************************************************************************

    Special modified version of task pool to enhance `outer` context of task
    with reference to throttler.

*******************************************************************************/

public class ThrottledTaskPool ( TaskT ) : TaskPool!(TaskT)
{
    import ocean.core.Enforce;

    /***************************************************************************

        Indicates that throttling hook has already been registered for a next
        epoll cycle.

    ***************************************************************************/

    private bool hook_registered;

    /***************************************************************************

        Throttler used to control tempo of data consumption from streams. By
        default internally defined PoolThrottler is used which is bound by
        task pool size limit.

    ***************************************************************************/

    public ISuspendableThrottler throttler;

    /***************************************************************************

        Constructor

        If this constructor is used, one must call `useThrottler` method before
        actually using the pool itself. Typical use case for that is deriving
        from the default `PoolThrottler` class (defined in this module) which
        requires reference to the pool as its constructor argument.

    ***************************************************************************/

    public this ( )
    {
        this.throttler = null;
    }

    /***************************************************************************

        Constructor

        Params:
            throttler = custom throttler to use.

    ***************************************************************************/

    public this ( ISuspendableThrottler throttler )
    {
        assert(throttler !is null);
        this.throttler = throttler;
    }

    /***************************************************************************

        Constructor

        Params:
            suspend_point = when number of busy tasks reaches this count,
                processing will get suspended
            resume_point = when number of busy tasks reaches this count,
                processing will get resumed

    ***************************************************************************/

    public this ( size_t suspend_point, size_t resume_point )
    {
        auto total = theScheduler.getStats().task_queue_total;

        enforce(suspend_point < total, format(
            "Trying to configure ThrottledTaskPool with suspend point ({}) " ~
                "larger or equal to task queue size {}",
            suspend_point, total));

        enforce(resume_point < total, format(
            "Trying to configure ThrottledTaskPool with suspend point ({}) " ~
                "larger or equal to task queue size {}",
            suspend_point, total));

        auto name = TaskT.classinfo.name;

        if (theScheduler.getSpecializedPoolStats(name).isDefined())
        {
            this.throttler = new SpecializedPoolThrottler(this,
                suspend_point, resume_point, name);
        }
        else
        {
            this.throttler = new PoolThrottler(this, suspend_point, resume_point);
        }
    }

    /***************************************************************************

        Sets or replaces current throttler instance

        Params:
            throttler = throttler to use

    ***************************************************************************/

    public void useThrottler ( ISuspendableThrottler throttler )
    {
        this.throttler = throttler;
    }

    /***************************************************************************

        Register throttling hook and check for suspend when starting a task.

        Params:
            task = The task being started from the throttled task pool.

    ***************************************************************************/

    override protected void startImpl ( Task task )
    {
        this.registerThrottlingHook();
        super.startImpl(task);
        this.throttler.throttledSuspend();
    }

    /***************************************************************************

        Registers throttling hook if not already present

    ***************************************************************************/

    void registerThrottlingHook ( )
    {
        if (!this.hook_registered)
        {
            this.hook_registered = true;
            theScheduler.epoll.onCycleEnd(&this.throttlingHook);
        }
    }

    /***************************************************************************

        Called upon owned task termination

    ***************************************************************************/

    private void throttlingHook ( )
    {
        this.throttler.throttledResume();

        if (this.num_busy() > 0)
            theScheduler.epoll.onCycleEnd(&this.throttlingHook);
        else
            this.hook_registered = false;
    }
}

/*******************************************************************************

    Default throttler implementation used if no external one is supplied
    via constructor. It throttles on amount of busy tasks in internal
    task pool.

*******************************************************************************/

public class PoolThrottler : ISuspendableThrottler
{
    /***************************************************************************

        Reference to the throttled pool

    ***************************************************************************/

    protected IPoolInfo pool;

    /***************************************************************************

      When amount of total queued tasks is >= this value, the input
      will be suspended.

    ***************************************************************************/

    protected size_t suspend_point;

    /***************************************************************************

      When amount of total queued tasks is <= this value, the input
      will be resumed.

    ***************************************************************************/

    protected size_t resume_point;

    /***************************************************************************

        Constructor

        Params:
            pool = pool to base throttling decision on
            suspend_point = when number of busy tasks reaches this count,
                processing will get suspended
            resume_point = when number of busy tasks reaches this count,
                processing will get resumed

    ***************************************************************************/

    public this ( IPoolInfo pool, size_t suspend_point, size_t resume_point )
    {
        assert(suspend_point > resume_point);
        assert(suspend_point < pool.limit());

        this.pool = pool;
        this.suspend_point = suspend_point;
        this.resume_point = resume_point;
    }

    /***************************************************************************

        Check if the total number of active tasks has reached the desired
        limit to suspend.

        Checks both amount of unused tasks in this pool and amount of unused
        tasks in global scheduler queue.

    ***************************************************************************/

    override protected bool suspend ( )
    {
        auto stats = theScheduler.getStats();
        auto total = stats.task_queue_total;
        auto used = stats.task_queue_busy;

        auto result = used >= this.suspend_point
            || (this.pool.num_busy() >= this.pool.limit() - 1);

        debug_trace("Throttler.suspend -> {}", result);

        return result;
    }

    /***************************************************************************

        Check if the total number of active tasks is below the desired
        limit to resume.

        Checks both amount of unused tasks in this pool and amount of unused
        tasks in global scheduler queue.

    ***************************************************************************/

    override protected bool resume ( )
    {
        auto stats = theScheduler.getStats();
        auto total = stats.task_queue_total;
        auto used = stats.task_queue_busy;

        auto result = used <= this.resume_point
            && (this.pool.num_busy() < this.pool.limit());

        debug_trace("Throttler.resume -> {}", result);

        return result;
    }
}

/*******************************************************************************

    Throttler implementation intended to be used with a specialized task
    pools.

*******************************************************************************/

public class SpecializedPoolThrottler : ISuspendableThrottler
{
    /***************************************************************************

        Reference to the throttled pool

    ***************************************************************************/

    protected IPoolInfo pool;

    /***************************************************************************

      When amount of total queued tasks is >= this value, the input
      will be suspended.

    ***************************************************************************/

    protected size_t suspend_point;

    /***************************************************************************

      When amount of total queued tasks is <= this value, the input
      will be resumed.

    ***************************************************************************/

    protected size_t resume_point;

    /***************************************************************************

        String representation of the class name of the task handled by the host
        task pool.

    ***************************************************************************/

    protected istring task_class_name;

    /***************************************************************************

        Constructor

        Params:
            pool = pool to base throttling decision on
            suspend_point = when number of busy tasks reaches this count,
                processing will get suspended
            resume_point = when number of busy tasks reaches this count,
                processing will get resumed
            name = class name for the task type handled by the `pool`

    ***************************************************************************/

    public this ( IPoolInfo pool, size_t suspend_point, size_t resume_point,
        istring name )
    {
        assert(suspend_point > resume_point);
        assert(suspend_point < pool.limit());

        this.pool = pool;
        this.suspend_point = suspend_point;
        this.resume_point = resume_point;
        this.task_class_name = name;
    }

    /***************************************************************************

        Check if the total number of active tasks has reached the desired
        limit to suspend.

        Checks both amount of unused tasks in this pool and amount of unused
        tasks in global scheduler queue.

    ***************************************************************************/

    override protected bool suspend ( )
    {
        bool result;

        auto stats = theScheduler.getSpecializedPoolStats(this.task_class_name);
        stats.visit(
            ( ) {
                verify(false, "Specialized task pool throttler initalized " ~
                    "with missing task class name");
            },
            (ref IScheduler.SpecializedPoolStats s) {
                result = s.used_fibers >= this.suspend_point;
            }
        );

        debug_trace("Throttler.suspend -> {}", result);
        return result;
    }

    /***************************************************************************

        Check if the total number of active tasks is below the desired
        limit to resume.

        Checks both amount of unused tasks in this pool and amount of unused
        tasks in global scheduler queue.

    ***************************************************************************/

    override protected bool resume ( )
    {
        bool result;

        auto stats = theScheduler.getSpecializedPoolStats(this.task_class_name);
        stats.visit(
            ( ) {
                verify(false, "Specialized task pool throttler initalized " ~
                    "with missing task class name");
            },
            (ref IScheduler.SpecializedPoolStats s) {
                result = s.used_fibers <= this.resume_point;
            }
        );

        debug_trace("Throttler.resume -> {}", result);
        return result;
    }
}

/*******************************************************************************

    Debug trace output when builing with the TaskScheduler debug flag.

    Params:
        format = Format for variadic argument output.
        args = Variadic arguments for output.

*******************************************************************************/

private void debug_trace ( T... ) ( cstring format, T args )
{
    debug ( TaskScheduler )
    {
        Stdout.formatln( "[ocean.task.ThrottledTaskPool] " ~ format, args )
            .flush();
    }
}
