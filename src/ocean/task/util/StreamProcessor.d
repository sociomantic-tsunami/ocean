/*******************************************************************************

    Framework for reading from a stream and throttling based on the progress of
    processing the received data.

    It is a relatively simple utility built on top of a task pool, the
    scheduler, and `ISuspendable`, to provide "ready to go" functionality to be
    used in applications.

    Usage example:
        See the documented unittest of the `StreamProcessor` class

    Copyright: Copyright (c) 2016 sociomantic labs. All rights reserved

*******************************************************************************/

module ocean.task.util.StreamProcessor;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.task.Task;
import ocean.task.TaskPool;
import ocean.task.Scheduler;

import ocean.core.Traits;
import ocean.core.Enforce;
import ocean.text.convert.Format;
import ocean.text.convert.Format;
import ocean.io.model.ISuspendable;
import ocean.io.model.ISuspendableThrottler;

debug (TaskScheduler)
{
    import ocean.io.Stdout;
}

/*******************************************************************************

    Class that handles distribution of data read from streams over a set of
    tasks in a task pool. The developer must define their own task class to do
    the work required to handle one record read from the streams; the stream
    processor takes care of throttling the input streams and distributing the
    resulting work over the pools of tasks / fibers.

    Params:
        TaskT = application-defined task class. Must have a `copyArguments`
            method whose arguments == the set of parameters expected from a data
            item read from the throttled stream(s)

*******************************************************************************/

class StreamProcessor ( TaskT : Task )
{
    /***************************************************************************

        Exception thrown when incorrect stream processor state is met that
        should never happen with valid throttling algorithm.

    ***************************************************************************/

    private ThrottlerFailureException throttler_failure_e;

    /***************************************************************************

        Pool of tasks used for processing stream data. Size of the pool is
        configured from StreamProcessor constructor and defines how fast
        the data can be consumed from streams (together with system-wide
        worker fiber count configured in scheduler).

    ***************************************************************************/

    protected ThrottledTaskPool!(TaskT) task_pool;

    /***************************************************************************

        Common constructor code

    ***************************************************************************/

    private this ( )
    {
        this.throttler_failure_e = new ThrottlerFailureException;
    }

    /***************************************************************************

        Constructor which accepts a custom throttler. (For standard throttling
        behaviour, based on the number of busy tasks, use the other ctor.)

        Params:
            max_tasks = the maximum number of simultaneous stream processing
                tasks allowed. Configure it based on the memory consumed by a
                single task.
            throttler = custom throttler to use.

    ***************************************************************************/

    public this ( size_t max_tasks, ISuspendableThrottler throttler )
    {
        this();
        this.task_pool = new ThrottledTaskPool!(TaskT)(throttler);
        this.task_pool.setLimit(max_tasks);
    }

    /***************************************************************************

        Constructor

        NB: configure suspend point so that there is always at least one
            "extra" spare task in the pool available after the limit is
            reached. This is necessary because throttling happens in the
            end of the task, not after it finishes and gets recycled.

        Params:
            max_tasks = the maximum number of simultaneous stream processing
                tasks allowed. Configure it based on the memory consumed by a
                single task.
            suspend_point = when the number of busy tasks reaches this count,
                 processing will be suspended
            resume_point = when the number of busy tasks reaches this count,
                processing will be resumed

    ***************************************************************************/

    public this ( size_t max_tasks, size_t suspend_point = size_t.max,
        size_t resume_point = size_t.max )
    {
        this();

        auto total = theScheduler.getStats().task_queue_total;

        if (suspend_point == size_t.max)
            suspend_point = total / 3 * 2;
        if (resume_point == size_t.max)
            resume_point = total / 5;

        enforce(total >= max_tasks,
            Format("Trying to configure StreamProcessor task pool size ({}) " ~
                " larger than max total task queue size {}", max_tasks, total));

        this.task_pool = new ThrottledTaskPool!(TaskT)(suspend_point, resume_point);
        this.task_pool.setLimit(max_tasks);
    }

    /***************************************************************************

        Method to be called to start processing a record newly received from a
        stream.

        Params:
            args = set of arguments to supply to processing task

        Throws:
            ThrottlerFailureException if it is not possible to process data
            because task pool limit is reached.

    ***************************************************************************/

    public void process ( ParameterTupleOf!(TaskT.copyArguments) args )
    {
        this.task_pool.throttler.throttledSuspend();

        if (!this.task_pool.start(args))
        {
            enforce(this.throttler_failure_e, false,
                "Throttler failure resulted in an attempt to process record " ~
                "with task pool full");
        }
    }

    /***************************************************************************

        Adds an input stream (which must implement ISuspendable) to the set of
        streams which are to be throttled. If it is already in the set, nothing
        happens.

        Params:
            s = suspendable input stream to be throttled

    ***************************************************************************/

    public void addStream ( ISuspendable s )
    {
        this.task_pool.throttler.addSuspendable(s);
    }

    /***************************************************************************

        Removes an input stream (which must implement ISuspendable) from the set
        of streams which are be throttled. If it is not in the set, nothing
        happens.

        Params:
            s = suspendable input stream to stop throttling

    ***************************************************************************/

    public void removeStream ( ISuspendable s )
    {
        this.task_pool.throttler.removeSuspendable(s);
    }
}

///
unittest
{
    // Global scheduler setup, it should happen at your application startup,
    // if the task system is to be used. The scheduler is shared by all stream
    // processors and all tasks in general.
    initScheduler(SchedulerConfiguration.init);

    static class MyProcessingTask : Task
    {
        import ocean.core.Array;

        // The task requires a single array as context, which is copied from the
        // outside by `copyArguments()`
        ubyte[] buffer;

        public void copyArguments ( ubyte[] data )
        {
            this.buffer.copy(data);
        }

        override public void run ( )
        {
            // Do something with the context and return when the task is
            // finished. Use `this.resume()` and `this.suspend()` to
            // control the execution of the bound worker fiber, if required
        }

        override public void recycle ( )
        {
            this.buffer.length = 0;
            enableStomping(this.buffer);
        }
    }

    const max_tasks = 5;
    auto stream_processor = new StreamProcessor!(MyProcessingTask)(max_tasks);

    // Set of input streams. In this example there are none. In your application
    // there should be more than none.
    ISuspendable[] input_streams;
    foreach ( input_stream; input_streams )
        stream_processor.addStream(input_stream);

    // An imaginary record arrives from one of the input streams and is passed
    // to the process() method. Arguments expected by `process` method are
    // identical to arguments expected by `copyArguments` method of your
    // task class
    ubyte[] record = [ 1, 2, 3 ];
    stream_processor.process(record);

    theScheduler.eventLoop();
}

/*******************************************************************************

    Special modified version of task pool used in StreamProcessor to enhance
    `outer` context of task with reference to throttler. Inheriting from
    TaskPool is necessary here because class can't have multiple `outer`
    contexts but inheriting `StreamProcessor` itself from task pool would
    expose all its public methods (which is not good).

*******************************************************************************/

private class ThrottledTaskPool ( TaskT ) : TaskPool!(TaskT)
{
   /***************************************************************************

        Throttler used to control tempo of data consumption from streams. By
        default internally defined PoolThrottler is used which is bound by
        task pool size limit.

    ***************************************************************************/

    private ISuspendableThrottler throttler;

    /***************************************************************************

        Task class used to process stream data. It inherits from user-supplied
        task type to insert throttling hooks before and after its main fiber
        method. Everything else is kept as is.

    ***************************************************************************/

    private class ProcessingTask : OwnedTask
    {
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

        Default throttler implementation used if no external one is supplied
        via constructor. It throttles on amount of busy tasks in internal
        task pool.

    ***************************************************************************/

    private class PoolThrottler : ISuspendableThrottler
    {
        /***********************************************************************

          When amount of total queued tasks is >= this value, the input
          will be suspended.

        ***********************************************************************/

        private size_t suspend_point;

        /***********************************************************************

          When amount of total queued tasks is <= this value, the input
          will be resumed.

        ***********************************************************************/

        private size_t resume_point;

        /***********************************************************************

            Constructor

            Params:
                suspend_point = when number of busy tasks reaches this count,
                    processing will get suspended
                resume_point = when number of busy tasks reaches this count,
                    processing will get resumed

        ***********************************************************************/

        public this ( size_t suspend_point, size_t resume_point )
        {
            assert(suspend_point > resume_point);
            assert(suspend_point < this.outer.limit());

            this.suspend_point = suspend_point;
            this.resume_point = resume_point;
        }

        /**********************************************************************/

        override protected bool suspend ( )
        {
            auto stats = theScheduler.getStats();
            auto total = stats.task_queue_total;
            auto used = stats.task_queue_busy;

            debug_trace("Throttler.suspend({}) : used = {}, total = {}, " ~
                "pool.busy = {}, pool.limit = {}", this.suspend_point, used,
                total, this.outer.num_busy(), this.outer.limit());

            return used >= this.suspend_point
                || (this.outer.num_busy() >= this.outer.limit() - 1);
        }

        /**********************************************************************/

        override protected bool resume ( )
        {
            auto stats = theScheduler.getStats();
            auto total = stats.task_queue_total;
            auto used = stats.task_queue_busy;

            debug_trace("Throttler.resume({}) : used = {}, total = {}, " ~
                "pool.busy = {}, pool.limit = {}", this.resume_point, used,
                total, this.outer.num_busy(), this.outer.limit());

            return used <= this.resume_point
                && (this.outer.num_busy() < this.outer.limit());
        }
    }

    /***************************************************************************

        Constructor

        Params:
            throttler = custom throttler to use.

    ***************************************************************************/

    private this ( ISuspendableThrottler throttler )
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

    private this ( size_t suspend_point, size_t resume_point )
    {
        this.throttler = new PoolThrottler(suspend_point, resume_point);
    }

    /***************************************************************************

        Rewrite of TaskPool.start changed to use `ProcessingTask` as actual
        task type instead of plain OwnedTask. Right now it is done by dumb
        copy-paste, if that pattern will appear more often, TaskPool base
        class may need a slight refactoring to support it.

        Params:
            args = same set of args as defined by `copyArguments` method of
                user-supplied task class, will be forwarded to it.

    ***************************************************************************/

    override protected bool start ( ParameterTupleOf!(TaskT.copyArguments) args )
    {
        if (this.num_busy() >= this.limit())
            return false;

        auto task = cast(TaskT) this.get(new ProcessingTask);
        assert (task !is null);
        task.copyArguments(args);
        theScheduler.schedule(task);

        return true;
    }
}

/*******************************************************************************

    Exception that indicates that used throttler doesn't work as intended

*******************************************************************************/

public class ThrottlerFailureException : Exception
{
    /***************************************************************************

        Constructor. Does not setup any exception information, relies on
        `enforce` to do it instead.

    ***************************************************************************/

    private this ( )
    {
        super("", "", 0);
    }
}

private void debug_trace ( T... ) ( cstring format, T args )
{
    debug ( TaskScheduler )
    {
        Stdout.formatln( "[ocean.task.util.StreamProcessor] " ~ format, args ).flush();
    }
}
