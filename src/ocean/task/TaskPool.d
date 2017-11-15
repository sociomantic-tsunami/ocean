/*******************************************************************************

    Ready-to-use task pool implementation that should be used in cases where the
    application has to spawn a large amount of the same type of task. It is
    possible to mix many different pools as well as an arbitrary amount of
    stand-alone tasks in the same applications - they will all use the same
    global `ocean.task.Scheduler`, including its pool of fibers.

    Usage example:
        See the documented unittest of the `TaskPool` class

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.TaskPool;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.task.Task;
import ocean.task.Scheduler;

import ocean.core.Enforce;
import ocean.core.Traits;
import ocean.util.container.pool.ObjectPool;

version (UnitTest)
{
    import ocean.core.Test;
    import ocean.task.util.Timer;
}

/*******************************************************************************

    Task pool which integrates with ocean.task.Scheduler.

    It is assumed that tasks that are going to be used with this class will
    require certain parameters to be passed to the task when it is started.
    These parameters are defined by the arguments of the `copyArguments` method,
    which the task class must implement. When a task is fetched from the pool to
    be used, its `copyArguments` method will be called, allowing the specified
    parameters to be passed into it.

    If the derived tasks contains a method matching the signature of
    `void deserialize ( void[] )` then the TaskPool with be created with
    support for starting tasks with a void buffer (via the restore() method).
    This supports serialization and deserialization of task internal state.

    It is crucial for tasks to either deep copy their initial parameters or
    ensure that those can never change during the task's lifetime, otherwise
    very hard to debug fiber races can happen.

    Params:
        TaskT = specific task type managed by this pool

*******************************************************************************/

class TaskPool ( TaskT : Task ) : ObjectPool!(Task)
{
    static assert(
        is (typeof(TaskT.copyArguments)),
        "Task derivative must define copyArguments function to work with " ~
            " a task pool"
    );

    /***************************************************************************

        Convenience alias for knowing task type.

    ***************************************************************************/

    public alias TaskT TaskType;

    /***************************************************************************

        Internal helper class derived from user-supplied task type that is used
        to track reference to outer pool for recycling.

        Params:
            TaskT = user-supplied task type

    ***************************************************************************/

    protected class OwnedTask : TaskT
    {
        /***********************************************************************

            Recycles the task by first calling its own recycle method to
            reset it to a clean state, and returns it to the pool of
            available tasks instances afterwards.

        ***********************************************************************/

        override public void recycle ( )
        {
            super.recycle();
            this.outer.recycle(this);
        }
    }

    /***************************************************************************

        Convenience method that does preparing initial arguments of reusable
        task and starting it via theScheduler in one go.

        Params:
            args = same set of args as defined by `copyArguments` method of
                user-supplied task class, will be forwarded to it.

        Returns:
            'false' if new task can't be started because pool limit is reached
            for now, 'true' otherwise

    ***************************************************************************/

    public bool start ( ParameterTupleOf!(TaskT.copyArguments) args )
    {
        if (this.num_busy() >= this.limit())
            return false;

        auto task = cast(TaskT) this.get(new OwnedTask);
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

        return true;
    }

    /***************************************************************************

        Suspends the current task until all running tasks in the pool have
        finished executing.

        Because of `terminationHook` implementation details, by the time caller
        task gets resumed, there will still be one (last) non-recycled running
        task in the pool, suspended right before actual termination. Once caller
        task gets suspended again for any reason, that last task will be
        recycled too. It is possible to manually call
        `theScheduler.processEvents()` after `awaitRunningTasks()` to force
        recycling of that last task at cost of a small additional delay in
        resuming the caller.

        Note: it is important to ensure that the current task (i.e. the one to
        be suspended) is not itself a task from the pool. If that were allowed,
        the current task would never get resumed, and this function would never
        return.

        Throws:
            `Exception` if the current task is null or if the current task
            belongs to the task pool

    ***************************************************************************/

    public void awaitRunningTasks ()
    {
        if (!this.num_busy())
            return;

        auto current_task = Task.getThis();
        enforce(current_task !is null,
            "Current task is null in TaskPool.awaitRunningTasks");

        scope tasks_iterator = this.new AllItemsIterator;
        int count;

        foreach (task; tasks_iterator)
        {
            enforce(!this.isSame(this.toItem(current_task), this.toItem(task)),
                "Current task cannot be from the pool of tasks to wait upon");

            if (!this.isBusy(this.toItem(task)))
                continue;

            ++count;

            task.terminationHook({
                --count;
                if (count == 0)
                    current_task.resume();
            });
        }

        if (count > 0)
            current_task.suspend();
    }

    static if( hasMethod!(TaskT, "deserialize", void delegate(void[])) )
    {
        /***********************************************************************

            Starts a task in the same manner as `start` but instead calls the
            `deserialize()` method on the derived task with a serialized buffer
            of the state. This is to support dumping and loading tasks from disk.

            Params:
                serialized = Buffer containing serialized data for restoring
                             the internal state of a task.

            Returns:
                'false' if new task can't be started because pool limit is reached
                for now, 'true' otherwise

        ***********************************************************************/

        public bool restore ( void[] serialized )
        {
            if (this.num_busy() >= this.limit())
                return false;

            auto task = cast(TaskT) this.get(new OwnedTask);
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

            return true;
        }
    }
}

///
unittest
{
    static class DummyTask : Task
    {
        import ocean.core.Array : copy;

        // The task requires a single string, which is copied from the outside
        // by `copyArguments()`
        private mstring buffer;

        public void copyArguments ( cstring arg )
        {
            this.buffer.copy(arg);
        }

        override public void recycle ( )
        {
            this.buffer.length = 0;
            enableStomping(this.buffer);
        }

        public override void run ( )
        {
            // do good stuff
        }
    }

    auto pool = new TaskPool!(DummyTask);
    initScheduler(SchedulerConfiguration.init);

    // Start some tasks, passing the required parameters to the pool's `start()`
    // method
    pool.start("abcd");
    pool.start("xyz");

    theScheduler.eventLoop();
}

unittest
{
    // Test that the recycle method of custom tasks is called
    static class RecycleTask : Task
    {
        static size_t recycle_count;

        public void copyArguments ( )
        {

        }

        override public void recycle ( )
        {
            recycle_count++;
        }

        override public void run ( )
        {

        }
    }

    auto pool = new TaskPool!(RecycleTask);
    initScheduler(SchedulerConfiguration.init);

    pool.start();
    pool.start();

    theScheduler.eventLoop();
    test!("==")(RecycleTask.recycle_count, 2,
        "RecycleTask.recycle was not called the correct number of times");
}

unittest
{
    // Test for waiting until all running tasks of a task pool finish executing.

    static class AwaitTask : Task
    {
        static int value;

        public void copyArguments ( )
        {
        }

        override public void run ( )
        {
            .wait(1); // so that the task gets suspended
            value++;
        }
    }

    class MainTask : Task
    {
        TaskPool!(AwaitTask) my_task_pool;

        public this ( )
        {
            this.my_task_pool = new TaskPool!(AwaitTask);
        }

        override protected void run ( )
        {
            static immutable NUM_START_CALLS = 6;

            for (uint i; i < NUM_START_CALLS; i++)
                this.my_task_pool.start();

            this.my_task_pool.awaitRunningTasks();

            test!("==")(AwaitTask.value, NUM_START_CALLS);
        }
    }

    initScheduler(SchedulerConfiguration.init);
    theScheduler.schedule(new MainTask);
    theScheduler.eventLoop();
}

unittest
{
    // Test that 'awaitRunningTasks()' cannot be called from a task that itself
    // belongs to the pool.

    static class AwaitTask : Task
    {
        void delegate () dg;

        public void copyArguments ( scope void delegate () dg )
        {
            this.dg = dg;
        }

        override public void run ( )
        {
            testThrown!(Exception)(this.dg());
        }
    }

    auto pool = new TaskPool!(AwaitTask);
    initScheduler(SchedulerConfiguration.init);

    pool.start(
        {
            // This delegate should throw as it will attempt to call the task
            // pool's awaitRunningTasks() method from within a task that itself
            // belongs to the pool.
            pool.awaitRunningTasks();
        }
    );
}
