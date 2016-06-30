/******************************************************************************

    Task extension which makes it possible to store exceptions from a callback
    so that is gets thrown after the task is resumed. This is useful for
    providing meaningful stacktraces which point to the origin of the faulty
    operation rather than to the event loop context.

    Usage example:
        See the documented unittest of the ExceptionForwarding struct

    Copyright: Copyright (c) 2016 sociomantic labs. All rights reserved

******************************************************************************/

module ocean.task.extensions.ExceptionForwarding;

version (UnitTest)
{
    import ocean.core.Test;
    import ocean.task.Task;
    import core.thread;
}

/******************************************************************************

    Task extension to be used with the `TaskWith` class.

******************************************************************************/

struct ExceptionForwarding
{
    public Exception to_throw;

    void onResumed ( )
    {
        if (this.to_throw !is null)
        {
            // reset the reference so it won't throw again
            // if the same fiber handles an exception and suspends again
            auto to_throw = this.to_throw;
            this.to_throw = null;
            throw to_throw;
        }
    }
}

///
unittest
{
    class ExceptionExternal : Exception
    {
        this ( )
        {
            super("external");
        }
    }

    class MyTask : TaskWith!(ExceptionForwarding)
    {
        bool caught = false;

        override protected void run ( )
        {
            try
            {
                // when the following call to `this.suspend()` exit (== after
                // resuming by a callback or the scheduler), the stored
                // exception (if any) will be thrown
                this.suspend();
            }
            catch (ExceptionExternal e)
            {
                caught = true;
            }
        }
    }

    // create a task and assign it to a worker fiber
    auto task = new MyTask;
    task.assignTo(new WorkerFiber(10240));

    // will start the task (which then yields immediately)
    task.resume();

    // makes stored exception instance thrown from within the task when
    // resumed
    task.extensions.exception_forwarding.to_throw = new ExceptionExternal;
    task.resume();
    test(task.caught);
}
