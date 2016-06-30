/*******************************************************************************

    Ready-to-use task pool implementation that should be used in cases where the
    application has to spawn a large amount of the same type of task. It is
    possible to mix many different pools as well as an arbitrary amount of
    stand-alone tasks in the same applications - they will all use the same
    global `ocean.task.Scheduler`, including its pool of fibers.

    Usage example:
        See the documented unittest of the `TaskPool` class

    Copyright: Copyright (c) 2016 sociomantic labs. All rights reserved

*******************************************************************************/

module ocean.task.TaskPool;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.task.Task;
import ocean.task.Scheduler;

import ocean.core.Traits;
import ocean.util.container.pool.ObjectPool;

/*******************************************************************************

    Task pool which integrates with ocean.task.Scheduler.

    It is assumed that tasks that are going to be used with this class will
    require certain parameters to be passed to the task when it is started.
    These parameters are defined by the arguments of the `copyArguments` method,
    which the task class must implement. When a task is fetched from the pool to
    be used, its `copyArguments` method will be called, allowing the specified
    parameters to be passed into it.

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

        Internal helper class derived from user-supplied task type that is used
        to track reference to outer pool for recycling.

        Params:
            TaskT = user-supplied task type

    ***************************************************************************/

    private class OwnedTask : TaskT
    {
        override public void recycle ( )
        {
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
        task.copyArguments(args);
        theScheduler.schedule(task);

        return true;
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
