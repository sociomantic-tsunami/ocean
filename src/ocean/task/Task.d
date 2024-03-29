/*******************************************************************************

    Defines the fundamental task abstraction.

    `Task`s are responsible for:
    - defining the actual function to execute as a task
    - defining suspend/resume semantics on top of the core Fiber semantics

    The `TaskWith` class, derived from `Task`, provides the facility of tasks
    with customised suspend/resume semantics, as specified by one of more
    extensions.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.Task;


static import core.thread;

import ocean.meta.types.Qualifiers;
import ocean.core.array.Mutation : moveToEnd, reverse;
import ocean.core.Buffer;
import ocean.core.Verify;
import ocean.task.internal.TaskExtensionMixins;
import ocean.task.IScheduler;

version (unittest)
{
    import ocean.core.Test;
}

debug (TaskScheduler)
{
    import ocean.io.Stdout;
}

/*******************************************************************************

    Fiber sub-class used by the scheduler to run tasks in. In addition to the
    functionality of the base fiber, it also:
        1. stores a reference to the task currently being executed
        2. can be stored in an object pool

*******************************************************************************/

public class WorkerFiber : core.thread.Fiber
{
    /***************************************************************************

        Allows smooth integration of WorkerFiber with object pool

    ***************************************************************************/

    public size_t object_pool_index;

    /***************************************************************************

        If not null, refers to the Task object currently being executed in this
        fiber

    ***************************************************************************/

    package Task active_task;

    /***************************************************************************

        Returns:
            the task object currently being executed in this fiber or null if
            there isn't one

    ***************************************************************************/

    public Task activeTask ( )
    {
        return this.active_task;
    }

    /***************************************************************************

        Terminates itself by killing underlying task

    ***************************************************************************/

    public void kill ( )
    {
        this.active_task.kill();
    }

    /***************************************************************************

        Constructor

        Worker fibers are always created with a dummy empty function as an
        entry point and are intented to be reset this later to the real task to
        be executed.

        Params:
            stack_size = stack size of the new fiber to allocate

    ***************************************************************************/

    public this ( size_t stack_size )
    {
        super(() {} , stack_size);
        // Calls itself once to get into the TERM state. The D2 runtime doesn't
        // allow creating a fiber with no function attached and neither runtime
        // allows resetting a fiber which is not in the TERM state
        this.call();
        assert (this.state() == core.thread.Fiber.State.TERM);
    }
}

/*******************************************************************************

    Exception class that indicates that current task must be terminated. It
    can be used to forcefully kill the task while still properly cleaning
    current stack frame.

*******************************************************************************/

public class TaskKillException : Exception
{
    public this ( string file = __FILE__, int line = __LINE__ )
    {
        super("Task was killed", file, line);
    }
}

/*******************************************************************************

    Minimal usable Task class.

    Serves as a base for all other task classes. Provides the following
    functionality:
      * assigning a task to an arbitrary fiber (`assignTo()`)
      * wraps the abstract `run()` method in a try/catch statement which
        rethrows any unhandled exceptions

*******************************************************************************/

public abstract class Task
{
    /***************************************************************************

        Thrown from within the task to force early termination. One instance
        is used by all tasks as this exception must never be caught.

    ***************************************************************************/

    private static TaskKillException kill_exception;

    /***************************************************************************

        Static constructor. Initializes the exception that indicates the task
        must be terminated.

    ***************************************************************************/

    public static this ( )
    {
        Task.kill_exception = new TaskKillException;
    }

    /***************************************************************************

        Bitmask representing internal task state

    ***************************************************************************/

    private TaskState state_bitmask;

    /***************************************************************************

        List of hooks that needs to be fired after Task has been terminated.

        Delegates will be called both if task terminates routinely and if
        it terminates dues to unhandled exception / gets killed.

    ***************************************************************************/

    private Buffer!(void delegate()) termination_hooks;

    /***************************************************************************

        Reserved index field which ensures that any Task derivative can be
        used with ObjectPool. That comes at minor cost of one unused size_t
        per Task instance if not needed which is not a problem.

    ***************************************************************************/

    public size_t object_pool_index;

    /***************************************************************************

        Fiber this task executes in

        This field is declared as public because qualified package protection
        is only available in D2. Please don't use it in applications
        directly.

    ***************************************************************************/

    /* package(ocean.task) */
    public WorkerFiber fiber;

    /***************************************************************************

        Returns:
            current task reference if there is one running, null otherwise

    ***************************************************************************/

    public static Task getThis ( )
    {
        auto worker = cast(WorkerFiber) core.thread.Fiber.getThis();
        if (worker !is null)
            return worker.activeTask();
        else
            return null;
    }

    /***************************************************************************

        Constructor. Used only to insert debug trace message.

    ***************************************************************************/

    public this ( )
    {
        debug_trace("'{}' <{}> has been created", this.classinfo.name,
            cast(void*) this);
    }

    /***************************************************************************

        Assigns the task to a fiber. In most cases you need to use
        `Scheduler.schedule` instead.

        In simple applications there tends to be 1-to-1 relation between task
        and fiber it executes in. However in highly concurrent server apps
        it may be necessary to maintain a separate task queue because of
        memory consumption reasons (fiber has to allocate a stack for itself
        which doesn't allow having too many of them). Such functionality
        is provided by `ocean.task.Scheduler`.

        Params:
            fiber = the fiber to assign the task to
            entry_point = optional custom entry point to replace
                `this.entryPoint`

    ***************************************************************************/

    public void assignTo ( WorkerFiber fiber,
        scope void delegate() entry_point = null )
    {
        this.state_bitmask = TaskState.None;

        this.fiber = fiber;
        this.fiber.active_task = this;
        if (fiber.state == fiber.state.TERM)
        {
            // cast to ignore return value
            this.fiber.reset(entry_point ? entry_point
                : cast(void delegate()) &this.entryPoint);
        }
    }

    /***************************************************************************

        Suspends execution of this task.

    ***************************************************************************/

    public void suspend ( )
    {
        assert (this.fiber !is null);
        verify (this.fiber is core.thread.Fiber.getThis());
        verify (this.fiber.state == this.fiber.state.EXEC);

        debug_trace("<{}> is suspending itself", cast(void*) this);
        this.fiber.yield();

        if (this.state_bitmask & TaskState.ToKill)
            throw Task.kill_exception;
    }

    /***************************************************************************

        Resumes execution of this task. If task has not been started yet,
        starts it.

    ***************************************************************************/

    public void resume ( )
    {
        assert (this.fiber !is null);
        assert (this.fiber.state != this.fiber.state.EXEC);

        auto resumer = Task.getThis();
        assert (resumer !is this);
        verify(
            resumer is null || !resumer.finished(),
            "Use `theScheduler.resume(task)` to resume a task from termination"
                ~ " hook of another task"
        );

        debug (TaskScheduler)
        {
            if (resumer is null)
            {
                debug_trace("<{}> has been resumed by main thread or event loop",
                    cast(void*) this);
            }
            else
            {
                debug_trace("<{}> has been resumed by <{}>",
                    cast(void*) this, cast(void*) resumer);
            }
        }

        this.fiber.call();
    }

    /***************************************************************************

        Registers a termination hook that will be executed when the Task is
        killed.

        Params:
            hook = delegate to be called after the task terminates

    ***************************************************************************/

    public void terminationHook (scope void delegate() hook)
    {
        this.termination_hooks ~= hook;
    }

    /***************************************************************************

        Unregisters a termination hook that would be executed when the Task is
        killed.

        Params:
            hook = delegate that would be called when the task terminates

    ***************************************************************************/

    public void removeTerminationHook (scope void delegate() hook)
    {
        this.termination_hooks.length = .moveToEnd(this.termination_hooks[], hook);
    }

    /***************************************************************************

        Returns:
            true if the fiber is suspended

    ***************************************************************************/

    final public bool suspended ( )
    {
        if (this.fiber is null)
            return false;
        return this.fiber.state() == core.thread.Fiber.State.HOLD;
    }

    /***************************************************************************

        Returns:
            true if this task was started and reached end of `run` method

    ***************************************************************************/

    final public bool finished ( )
    {
        return (this.state_bitmask & TaskState.Finished) > 0;
    }

    /***************************************************************************

        Forces abnormal termination for the task by throwing special
        exception instance.

    ***************************************************************************/

    public void kill ( string file = __FILE__, int line = __LINE__ )
    {
        Task.kill_exception.file = file;
        Task.kill_exception.line = line;

        if (this is Task.getThis())
            throw Task.kill_exception;
        else
        {
            this.state_bitmask |= TaskState.ToKill;
            this.resume();
        }
    }

    /***************************************************************************

        Method that will be run by scheduler when task finishes. Must be
        overridden by specific task class to reset reusable resources.

        It is public so that both scheduler can access it and derivatives can
        override it. No one but scheduler must call this method.

    ***************************************************************************/

    public void recycle ( ) { }

    /***************************************************************************

        Method that must be overridden in actual application/library task
        classes to provide entry point.

    ***************************************************************************/

    protected abstract void run ( );

    /***************************************************************************

        Internal wrapper around `this.run()` which is used as primary fiber
        entry point and ensures any uncaught exception propagates to the
        context that has started this task.

        Returns:
            'true' if the task terminated with unhandled exception, 'false'
            otherwise

    ***************************************************************************/

    /* package(ocean.task) */
    public final bool entryPoint ( )
    {
        debug_trace("<{}> start of main function", cast(void*) this);

        scope(exit)
        {
            this.state_bitmask |= TaskState.Finished;

            if (this.termination_hooks.length)
            {
                debug_trace("Calling {} termination_hooks for task <{}>",
                    this.termination_hooks.length, cast(void*) this);

                auto hooks = reverse(this.termination_hooks[]);
                this.termination_hooks.reset();

                foreach (hook; hooks)
                {
                    hook();
                    assert(
                        this.termination_hooks.length == 0,
                        "Adding new hooks while running existing " ~
                            "ones is not supported"
                    );
                }
            }

            // allow task to recycle any shared resources it may have
            // (or recycle task instance itself)
            //
            // NB: this must be the final part of the method and relies
            // on assumption that no other fiber will have any chance
            // to start executing this task until it actually reaches
            // end of the method
            debug_trace("Recycling task <{}>", cast(void*) this);
            this.recycle();
        }

        try
        {
            assert (this.fiber is core.thread.Fiber.getThis());
            assert (this       is Task.getThis());
            this.run();
        }
        catch (TaskKillException)
        {
            debug_trace("<{}> termination (killed)", cast(void*) this);
            this.state_bitmask &= ~cast(int) TaskState.ToKill;
            return false;
        }
        catch (Exception e)
        {
            debug_trace("<{}> termination (uncaught exception): {} ({}:{})",
                cast(void*) this, e.message(), e.file, e.line);

            // After yielding to rethrow exception this task has to be resumed
            // by someone to finish cleanup and keep reusing its worker fiber.
            // If scheduler is available, it can do it automatically, otherwise
            // it becomes reponsibility of the caller.

            if (isSchedulerUsed())
                theScheduler.delayedResume(this);
            this.fiber.yieldAndThrow(e);

            // if task was resumed with `kill` from 'pending cleanup' state
            // just quit the method as if it was originally terminated by kill
            if (this.state_bitmask & TaskState.ToKill)
            {
                debug_trace("<{}> termination (killed)", cast(void*) this);
                return false;
            }
            else
                return true;
        }

        debug_trace("<{}> termination (end of main function)", cast(void*) this);
        return false;
    }
}

///
unittest
{
    // represents some limited resource used by this task (e.g. memory or a
    // file handle)
    class LimitedResourceHandle { }
    LimitedResourceHandle getResource ( ) { return null; }
    void releaseResource ( LimitedResourceHandle ) { }

    // example custom task class
    class MyTask : Task
    {
        LimitedResourceHandle resource;

        override public void run ( )
        {
            this.resource = getResource();
        }

        override public void recycle ( )
        {
            releaseResource(this.resource);
        }
    }

    // Example of running a task by manually spawning a worker fiber.
    // More commonly, it is instead done via ocean.task.Scheduler.
    auto task = new MyTask;
    // a large stack size is important for debug traces to not crash tests:
    task.assignTo(new WorkerFiber(10240));
    task.resume();
}

unittest
{
    // test killing

    class MyTask : Task
    {
        bool clean_finish = false;

        override protected void run ( )
        {
            this.suspend();
            this.clean_finish = true;
        }
    }

    auto task = new MyTask;
    task.assignTo(new WorkerFiber(10240));
    task.resume();

    task.kill();
    test(!task.clean_finish);
    test!("==")(task.fiber.state, core.thread.Fiber.State.TERM);
    test(task.finished());
}

unittest
{
    // test context sanity

    class TestTask : Task
    {
        Task task;
        WorkerFiber fiber;

        override public void run ( )
        {
            this.fiber = cast(WorkerFiber) WorkerFiber.getThis();
            this.suspend();
            this.task = Task.getThis();
        }
    }

    test(Task.getThis() is null); // outside of task

    auto task = new TestTask;
    auto worker = new WorkerFiber(10240);

    task.assignTo(worker);
    test(worker.activeTask() is task);

    task.resume();
    test(task.fiber is worker);
    test(task.task is null);

    task.resume();
    test(task.task is task);
}

unittest
{
    // test exception forwarding semantics

    // If the scheduler was initialized before, it will have one pending task from
    // the thrown exception. Drop it before proceeding.

    dropScheduler();

    class ExceptionInternal : Exception
    {
        this ( )
        {
            super("internal");
        }
    }

    class TestTask : Task
    {
        override public void run ( )
        {
            throw new ExceptionInternal;
        }
    }

    auto task = new TestTask;
    auto worker = new WorkerFiber(10240);

    task.assignTo(worker);
    testThrown!(ExceptionInternal)(task.resume());
    test!("==")(task.fiber.state, core.thread.Fiber.State.HOLD);
    task.resume();
    test!("==")(task.fiber.state, core.thread.Fiber.State.TERM);
}

unittest
{
    // test TaskKillException

    class TestTask : Task
    {
        override public void run ( )
        {
            throw new TaskKillException;
        }
    }

    auto task = new TestTask;
    auto worker = new WorkerFiber(10240);

    task.assignTo(worker);
    task.resume();
    test!("==")(task.fiber.state, core.thread.Fiber.State.TERM);
}

/*******************************************************************************

    `Task` descendant which supports extensions that alter the semantics of
    suspending and resuming the task. An arbitrary number of extensions may be
    specified (see Params).

    Each extension must be a struct which defines one or more of the following
    methods:
    - void onBeforeSuspend ( )
    - void onBeforeResume ( )
    - void onResumed ( ) // called right after execution gets back to task

    There is no `onSuspended` hook because it would be executed in the context
    of the caller fiber, right after the current task yields. Such a context
    tends to be neither well-defined nor useful in practice.

    The relevant extension methods are called before `this.suspend` /
    `this.resume` in the same order as they are supplied via the template
    argument list.

    The relevant extension methods are called after `this.suspend` /
    `this.resume` in the reverse order that they are supplied via the template
    argument list.

    Params:
        Extensions = variadic template argument list of extensions to use

*******************************************************************************/

public class TaskWith ( Extensions... ) : Task
{
    mixin (genExtensionAggregate!(Extensions)());

    /***************************************************************************

        Constructor

        Allows extensions to get information about host task if they have
        matching `reset` method defined.

    ***************************************************************************/

    this ( )
    {
        foreach (ref extension; this.extensions.tupleof)
        {
            static if (is(typeof(extension.reset(this))))
                extension.reset(this);
        }
    }

    /***************************************************************************

        Suspends this task, calls extension methods before and after
        suspending (if there are any).

    ***************************************************************************/

    override public void suspend ( )
    {
        foreach (ref extension; this.extensions.tupleof)
        {
            static if (is(typeof(extension.onBeforeSuspend())))
                extension.onBeforeSuspend();
        }

        super.suspend();

        foreach_reverse (ref extension; this.extensions.tupleof)
        {
            static if (is(typeof(extension.onResumed())))
                extension.onResumed();
        }
    }

    /***************************************************************************

        Resumes this task, calls extension methods before resuming
        (if there are any).

    ***************************************************************************/

    override public void resume ( )
    {
        foreach (ref extension; this.extensions.tupleof)
        {
            static if (is(typeof(extension.onBeforeResume())))
                extension.onBeforeResume();
        }

        super.resume();
    }

    /***************************************************************************

        Ensures extensions are reset to initial state when task is assigned
        to new worker fiber.

    ***************************************************************************/

    override public void assignTo ( WorkerFiber fiber,
        scope void delegate() entry_point = null )
    {
        super.assignTo(fiber, entry_point);

        foreach (ref extension; this.extensions.tupleof)
        {
            static if (is(typeof(extension.reset(this))))
                extension.reset(this);
            else
                extension = extension.init;
        }
    }
}

///
unittest
{
    // see tests/examples in ocean.task.extensions.*
}

/// Values for task state bitmask
private enum TaskState : ubyte
{
    None   = 0b0000_0000,

    /// If this flag is set, task will try to kill itself as soon at is
    /// resumed by throwing TaskKillException.
    ToKill     = 0b0000_0001,
    /// This flag is set when `run` method of the task finishes
    Finished   = 0b0000_0010,
}

private void debug_trace ( T... ) ( cstring format, T args )
{
    debug ( TaskScheduler )
    {
        Stdout.formatln( "[ocean.task.Task] " ~ format, args ).flush();
    }
}
