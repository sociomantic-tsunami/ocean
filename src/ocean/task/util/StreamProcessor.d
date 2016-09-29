/*******************************************************************************

    Framework for reading from a stream and throttling based on the progress of
    processing the received data.

    It is a relatively simple utility built on top of a task pool, the
    scheduler, and `ISuspendable`, to provide "ready to go" functionality to be
    used in applications.

    Usage example:
        See the documented unittest of the `StreamProcessor` class

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.util.StreamProcessor;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.task.Task;
import ocean.task.ThrottledTaskPool;
import ocean.task.Scheduler;

import ocean.core.Traits;
import ocean.core.Enforce;
import ocean.text.convert.Format;
import ocean.io.model.ISuspendable;
import ocean.io.model.ISuspendableThrottler;

debug (TaskScheduler)
{
    import ocean.io.Stdout;
}

version (UnitTest)
{
    import ocean.core.Test;
}

/*******************************************************************************

    Config struct to use when creating a stream processor that should use
    the default PoolThrottler for throttling.

*******************************************************************************/

public struct ThrottlerConfig
{
    /***************************************************************************

        The number of busy tasks to suspend at.

        The default value of `size_t.max` means that the suspend point will be
        calculated based on the task queue size in the constructor.

    ***************************************************************************/

    size_t suspend_point = size_t.max;

    /***************************************************************************

        The number of busy tasks to resume at.

        The default value of `size_t.max` means that the resume point will be
        calculated based on the task queue size in the constructor.

    ***************************************************************************/

    size_t resume_point = size_t.max;

    /***************************************************************************

        The maximum number of simultaneous tasks.

    ***************************************************************************/

    deprecated("Use getTaskPool().setLimit() to manually set max tasks limit")
    size_t max_tasks;
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
            throttler = custom throttler to use.

    ***************************************************************************/

    public this ( ISuspendableThrottler throttler )
    {
        this();
        this.task_pool = new ThrottledTaskPool!(TaskT)(throttler);
    }

    /***************************************************************************

        Constructor

        NB: configure suspend point so that there is always at least one
            "extra" spare task in the pool available after the limit is
            reached. This is necessary because throttling happens in the
            end of the task, not after it finishes and gets recycled.

        Params:
            throttler_config = The throttler configuration

    ***************************************************************************/

    public this ( ThrottlerConfig throttler_config )
    {
        this();

        auto total = theScheduler.getStats().task_queue_total;

        if (throttler_config.suspend_point == size_t.max)
            throttler_config.suspend_point = total / 3 * 2;
        else
        {
            enforce(
                this.throttler_failure_e,
                throttler_config.suspend_point < total,
                Format(
                    "Trying to configure StreamProcessor with suspend point ({}) " ~
                        "larger or equal to task queue size {}",
                    throttler_config.suspend_point, total
                )
            );
        }

        if (throttler_config.resume_point == size_t.max)
            throttler_config.resume_point = total / 5;
        {
            enforce(
                this.throttler_failure_e,
                throttler_config.resume_point < total,
                Format(
                    "Trying to configure StreamProcessor with resume point ({}) " ~
                        "larger or equal to task queue size {}",
                    throttler_config.resume_point, total
                )
            );
        }

        this.task_pool = new ThrottledTaskPool!(TaskT)(throttler_config.suspend_point, throttler_config.resume_point);
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

    deprecated("Use getTaskPool().setLimit() to manually set max tasks limit")
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

    deprecated("Use constructor that accepts a ThrottlerConfig struct")
    public this ( size_t max_tasks, size_t suspend_point = size_t.max,
        size_t resume_point = size_t.max )
    {
        this();

        auto total = theScheduler.getStats().task_queue_total;

        if (suspend_point == size_t.max)
            suspend_point = total / 3 * 2;
        else
        {
            enforce(
                this.throttler_failure_e,
                suspend_point < total,
                Format(
                    "Trying to configure StreamProcessor with suspend point ({}) " ~
                        "larger or equal to task queue size {}",
                    suspend_point, total
                )
            );
        }

        if (resume_point == size_t.max)
            resume_point = total / 5;
        {
            enforce(
                this.throttler_failure_e,
                resume_point < total,
                Format(
                    "Trying to configure StreamProcessor with resume point ({}) " ~
                        "larger or equal to task queue size {}",
                    resume_point, total
                )
            );
        }

        enforce(
            this.throttler_failure_e,
            max_tasks < total,
            Format(
                "Trying to configure StreamProcessor task pool size ({}) " ~
                    " larger than max total task queue size {}",
                max_tasks, total
            )
        );

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

    /***************************************************************************

        Get the task pool.

        Returns:
            The task pool

    ***************************************************************************/

    public ThrottledTaskPool!(TaskT) getTaskPool ( )
    {
        return this.task_pool;
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

    auto throttler_config = ThrottlerConfig(5, 1);
    auto stream_processor = new StreamProcessor!(MyProcessingTask)(throttler_config);

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

unittest
{
    SchedulerConfiguration config;
    initScheduler(config);

    static class DummyTask : Task
    {
        override public void run ( ) { }
        public void copyArguments ( ) { }
    }

    {
        // suspend point >= task queue
        auto throttler_config = ThrottlerConfig(config.task_queue_limit, 1);
        testThrown!(ThrottlerFailureException)(new StreamProcessor!(DummyTask)(
            throttler_config));
    }

    {
        // resume point >= task queue
        auto throttler_config = ThrottlerConfig(1, config.task_queue_limit);
        testThrown!(ThrottlerFailureException)(new StreamProcessor!(DummyTask)(
            throttler_config));
    }

    {
        // works
        auto throttler_config = ThrottlerConfig(config.task_queue_limit - 1, 1);
        auto processor = new StreamProcessor!(DummyTask)(throttler_config);
    }
}

deprecated unittest
{
    SchedulerConfiguration config;
    initScheduler(config);

    static class DummyTask : Task
    {
        override public void run ( ) { }
        public void copyArguments ( ) { }
    }

    // pool size > task queue
    testThrown!(ThrottlerFailureException)(new StreamProcessor!(DummyTask)(
        config.task_queue_limit + 1));

    // suspend point >= task queue
    testThrown!(ThrottlerFailureException)(new StreamProcessor!(DummyTask)(
        config.task_queue_limit, config.task_queue_limit));

    // resume point >= task queue
    testThrown!(ThrottlerFailureException)(new StreamProcessor!(DummyTask)(
        config.task_queue_limit, config.task_queue_limit - 1,
        config.task_queue_limit));

    // works
    auto processor = new StreamProcessor!(DummyTask)(config.task_queue_limit - 1,
        config.task_queue_limit -1, config.task_queue_limit - 2);
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
