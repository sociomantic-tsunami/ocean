/*******************************************************************************

    Adds functionality to suspend/resume registered ISuspendable instances
    based on the number of active tasks in the task pool.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.ThrottledTaskPool;

import ocean.task.TaskPool;
import ocean.task.Task;
import ocean.task.Scheduler;
import ocean.text.convert.Formatter;

import ocean.io.model.ISuspendableThrottler;
import ocean.util.container.pool.model.IPoolInfo;
import ocean.util.container.pool.model.ILimitable;

import ocean.transition;

/*******************************************************************************

    Special modified version of task pool to enhance `outer` context of task
    with reference to throttler.

*******************************************************************************/

public class ThrottledTaskPool ( TaskT ) : TaskPool!(TaskT)
{
    import ocean.core.Traits;
    import ocean.core.Enforce;

    debug (TaskScheduler)
    {
        import ocean.io.Stdout;
    }

    /***************************************************************************

        Throttler used to control tempo of data consumption from streams. By
        default internally defined PoolThrottler is used which is bound by
        task pool size limit.

    ***************************************************************************/

    public ISuspendableThrottler throttler;

    /***************************************************************************

        Task class used to process stream data. It inherits from user-supplied
        task type to insert throttling hooks before and after its main fiber
        method. Everything else is kept as is.

    ***************************************************************************/

    private class ProcessingTask : OwnedTask
    {
        /***********************************************************************

            Overloaded method to call throttledResume on the throttler when
            then task is finished.

        ***********************************************************************/

        override protected void run ( )
        {
            // Bug? Deduces type of `this.outer` as one of base class.
            auto pool = cast(ThrottledTaskPool) this.outer;
            assert (pool !is null);

            super.run();

            pool.throttler.throttledResume();
        }
    }

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

        this.throttler = new PoolThrottler(this, suspend_point, resume_point);
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

        Rewrite of TaskPool.start changed to use `ProcessingTask` as actual
        task type instead of plain OwnedTask. Right now it is done by dumb
        copy-paste, if that pattern will appear more often, TaskPool base
        class may need a slight refactoring to support it.

        Params:
            args = same set of args as defined by `copyArguments` method of
                user-supplied task class, will be forwarded to it.

        Returns:
            False if the pool is at maximum capacity;

    ***************************************************************************/

    override public bool start ( ParameterTupleOf!(TaskT.copyArguments) args )
    {
        assert (this.throttler !is null);

        if (this.num_busy() >= this.limit())
            return false;

        auto task = cast(TaskT) this.get(new ProcessingTask);
        assert (task !is null);

        try
        {
            task.copyArguments(args);
            theScheduler.schedule(task);
        }
        catch (TaskKillException e)
        {
            // don't try recycling task upon TaskKillException as this is not
            // normal code flow and it may have already been recycled by
            // finishing on its own
            throw e;
        }
        catch (Exception e)
        {
            this.recycle(task);
            throw e;
        }

        this.throttler.throttledSuspend();

        return true;
    }

    static if( hasMethod!(TaskT, "deserialize", void delegate(void[])) )
    {
        /***********************************************************************

            Starts a task in the same manner as `start` but instead calls
            a restore method on the derived task with a serialized buffer of the
            state. This is to support dumping and loading tasks from disk.

            Params:
                serialized = same set of args as defined by `serialized` method
                    of user-supplied task class, will be forwarded to it.

            Returns:
                'false' if new task can't be started because pool limit is
                reached for now, 'true' otherwise

        ***********************************************************************/

        override public bool restore ( void[] serialized )
        {
            assert (this.throttler !is null);

            if (this.num_busy() >= this.limit())
                return false;

            auto task = cast(TaskT) this.get(new ProcessingTask);
            assert (task !is null);

            try
            {
                task.deserialize(serialized);
                theScheduler.schedule(task);
            }
            catch (TaskKillException e)
            {
                // don't try recycling task upon TaskKillException as this is not
                // normal code flow and it may have already been recycled by
                // finishing on its own
                throw e;
            }
            catch (Exception e)
            {
                this.recycle(task);
                throw e;
            }

            this.throttler.throttledSuspend();

            return true;
        }
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

        debug_trace("Throttler.suspend({}) : used = {}, total = {}, " ~
            "pool.busy = {}, pool.limit = {}", this.suspend_point, used,
            total, this.pool.num_busy(), this.pool.limit());

        return used >= this.suspend_point
            || (this.pool.num_busy() >= this.pool.limit() - 1);
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

        debug_trace("Throttler.resume({}) : used = {}, total = {}, " ~
            "pool.busy = {}, pool.limit = {}", this.resume_point, used,
            total, this.pool.num_busy(), this.pool.limit());

        return used <= this.resume_point
            && (this.pool.num_busy() < this.pool.limit());
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
