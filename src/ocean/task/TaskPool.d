/*******************************************************************************

    Ready-to-use task pool implementation that should be used in cases where the
    application has to spawn a large amount of the same type of task. It is
    possible to mix many different pools as well as an arbitrary amount of
    stand-alone tasks in the same applications - they will all use the same
    global `ocean.task.Scheduler`, including its pool of fibers.

    Usage example:
        See the documented unittest of the `TaskPool` class

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.TaskPool;


import ocean.transition;

import ocean.task.Task;
import ocean.task.IScheduler;

import ocean.core.Enforce;
import ocean.core.Buffer;
import ocean.core.array.Mutation; /* : insertShift */;
import ocean.meta.types.Function /* : ParametersOf */;
import ocean.meta.traits.Aggregates /* : hasMember */;
import ocean.meta.AliasSeq;
import ocean.util.container.pool.ObjectPool;

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

        Convenience method that does preparing initial arguments of reusable
        task and starting it via theScheduler in one go.

        Params:
            args = same set of args as defined by `copyArguments` method of
                user-supplied task class, will be forwarded to it.

        Returns:
            'false' if new task can't be started because pool limit is reached
            for now, 'true' otherwise

    ***************************************************************************/

    public bool start ( ParametersOf!(TaskT.copyArguments) args )
    {
        if (this.num_busy() >= this.limit())
            return false;

        auto task = cast(TaskT) this.get(new TaskT);
        assert (task !is null);

        task.copyArguments(args);
        this.startImpl(task);
        return true;
    }

    /***************************************************************************

        Common part of start implementation reused by derivatives. Split into
        separate method to ensure that recycling hook won't be omitted.

        Params:
            task = already setup task to run and recyle

    ***************************************************************************/

    protected void startImpl ( Task task )
    {
        task.terminationHook(&this.taskTerminationHook);
        theScheduler.schedule(task);
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
                    theScheduler.delayedResume(current_task);
            });
        }

        if (count > 0)
            current_task.suspend();
    }

    static if (__traits(hasMember, TaskT, "deserialize"))
    {
        /***********************************************************************

            Starts a task in the same manner as `start` but instead calls the
            `deserialize()` method on the derived task with arguments supported.
            This is to support dumping and loading tasks from disk.

            Params:
                args = Arguments matching the function arguments of the
                       'deserialize()' function of the task type.

            Returns:
                'false' if new task can't be started because pool limit is reached
                for now, 'true' otherwise

        ***********************************************************************/

        public bool restore  ( ParametersOf!(TaskT.deserialize) args )
        {
            if (this.num_busy() >= this.limit())
                return false;

            auto task = cast(TaskT) this.get(new TaskT);
            assert (task !is null);

            task.deserialize(args);
            this.startImpl(task);

            return true;
        }
    }

    /***************************************************************************

        Used to recycle pool tasks when they finish

    ***************************************************************************/

    private void taskTerminationHook ( )
    {
        auto task = Task.getThis();
        this.recycle(task);
    }
}

///
unittest
{
    void example ( )
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

        // Start some tasks, passing the required parameters to the pool's `start()`
        // method
        pool.start("abcd");
        pool.start("xyz");

        theScheduler.eventLoop();
    }
}
