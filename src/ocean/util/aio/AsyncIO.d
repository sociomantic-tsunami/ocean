/******************************************************************************

    Module for doing non-blocking reads supported by threads.

    This module contains AsyncIO definition. Intented usage of AsyncIO is to
    perform normally blocking IO calls (disk requests) in fiber-blocking
    manner.

    Fiber wanting to perform a request should submit its request to AsyncIO
    using public interface, passing all the arguments normally used by the
    blocking call and JobNotification instance on which it will be
    blocked.  After issuing the request, request will be put in the queue and
    the fiber will block immidiatelly, giving chance to other fibers to run.

    In the background, fixed amount of worker threads are taking request from
    the queue, and performing it (using blocking call which will in turn block
    this thread). When finished, the worker thread will resume the blocked fiber,
    and block on the semaphore waiting for the next request.

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

******************************************************************************/

module ocean.util.aio.AsyncIO;

import ocean.transition;
import ocean.core.Verify;

import core.stdc.errno;
import core.sys.posix.semaphore;
import core.sys.posix.pthread;
import core.sys.posix.unistd;
import core.stdc.stdint;
import core.stdc.stdio;
import ocean.core.array.Mutation: copy;
import ocean.sys.ErrnoException;
import ocean.io.select.EpollSelectDispatcher;

import ocean.util.aio.internal.JobQueue;
import ocean.util.aio.internal.ThreadWorker;
import ocean.util.aio.internal.MutexOps;
import ocean.util.aio.internal.AioScheduler;
import ocean.util.aio.JobNotification;

version (UnitTest)
{
    import ocean.core.Test;
    import ocean.task.Scheduler;
    import ocean.io.device.File;
}

/******************************************************************************

    Class implementing AsyncIO support.

******************************************************************************/

class AsyncIO
{
    /**************************************************************************

        Base class for the thread worker context

    **************************************************************************/

    public static class Context
    {

    }

    /**************************************************************************

        Ernno exception instance

        NOTE: must be thrown and catched only from/in main thread, as it is not
              multithreaded-safe

    **************************************************************************/

    private ErrnoException exception;


    /**************************************************************************

        Job queue

   ***************************************************************************/

    private JobQueue jobs;

    /**************************************************************************

        AioScheduler used to wake the ready jobs.

    **************************************************************************/

    private AioScheduler scheduler;

    /**************************************************************************

        Handles of worker threads.

    **************************************************************************/

    private pthread_t[] threads;

    /**************************************************************************

        Indicator if the AsyncIO is destroyed

    **************************************************************************/

    private bool destroyed;

    /**************************************************************************

        Struct providing the initialization data for the thread.

    **************************************************************************/

    public struct ThreadInitializationContext
    {
        JobQueue job_queue;
        AsyncIO.Context delegate() makeContext;
        pthread_mutex_t init_mutex;
        pthread_cond_t init_cond;
        int to_create;
    }

    /**************************************************************************

        Ditto

    **************************************************************************/

    private ThreadInitializationContext thread_init_context;

    /**************************************************************************

        Constructor.

        Params:
            epoll = epoll select dispatcher instance
            number_of_threads = number of worker threads to allocate
            make_context = delegate to create a context within a thread
            thread_stack_size = default stack size to allocate

    **************************************************************************/

    public this (EpollSelectDispatcher epoll, int number_of_threads,
            scope AsyncIO.Context delegate() makeContext = null,
            long thread_stack_size = 256 * 1024)
    {

        this.exception = new ErrnoException;

        this.scheduler = new AioScheduler(this.exception);
        this.jobs = new JobQueue(this.exception, this.scheduler);
        this.nonblocking = new typeof(this.nonblocking);
        this.blocking = new typeof(this.blocking);

        // create worker threads
        this.threads.length = number_of_threads;
        this.thread_init_context.to_create = number_of_threads;

        this.thread_init_context.job_queue = this.jobs;
        this.thread_init_context.makeContext = makeContext;
        exception.enforceRetCode!(pthread_mutex_init).call(
                &this.thread_init_context.init_mutex, null);
        exception.enforceRetCode!(pthread_cond_init).call(
                &this.thread_init_context.init_cond, null);

        pthread_attr_t attr;
        pthread_attr_setstacksize(&attr, thread_stack_size);

        foreach (i, tid; this.threads)
        {
            // Create a thread passing this instance as a parameter
            // to thread's entry point
            this.exception.enforceRetCode!(pthread_create).call(&this.threads[i],
                &attr,
                &thread_entry_point!(ThreadInitializationContext),
                cast(void*)&this.thread_init_context);
        }

        // wait all threads to create
        pthread_mutex_lock(&this.thread_init_context.init_mutex);
        while (this.thread_init_context.to_create > 0)
        {
            pthread_cond_wait(&thread_init_context.init_cond, &this.thread_init_context.init_mutex);
        }

        pthread_mutex_unlock(&this.thread_init_context.init_mutex);

        epoll.register(this.scheduler);
    }

    /**************************************************************************

        Issues a pread request, blocking the fiber connected to the provided
        suspended_job until the request finishes.

        This will read buf.length number of bytes from fd to buf, starting
        from offset.

        Params:
            buf = buffer to fill
            fd = file descriptor to read from
            offset = offset in the file to read from
            suspended_job = JobNotification instance to
                block the fiber on

        Returns:
            number of the bytes read

        Throws:
            ErrnoException with appropriate errno set in case of failure

    **************************************************************************/

    public size_t pread (void[] buf, int fd, size_t offset,
            JobNotification suspended_job)
    {
        ssize_t ret_val;
        int errno_val;
        auto job = this.jobs.reserveJobSlot(&lock_mutex,
                &unlock_mutex);

        job.recv_buffer.length = buf.length;
        enableStomping(job.recv_buffer);
        job.fd = fd;
        job.suspended_job = suspended_job;
        job.offset = offset;
        job.cmd = Job.Command.Read;
        job.ret_val = &ret_val;
        job.errno_val = &errno_val;
        job.user_buffer = buf;
        job.finalize_results = &finalizeRead;

        // Let the threads waiting on the semaphore know that they
        // can start doing single read
        post_semaphore(&this.jobs.jobs_available);

        // Block the fiber
        suspended_job.wait(job, &this.scheduler.discardResults);

        // At this point, fiber is resumed,
        // check the return value and throw if needed
        if (ret_val == -1)
        {
            throw this.exception.set(errno_val,
                    "pread");
        }

        assert(ret_val >= 0);
        return cast(size_t)ret_val;
    }

    /***************************************************************************

        Appends a buffer to the file.

        Buffer must be alive during the lifetime of the request (until the
        notification fires)

        Returns:
            number of bytes written

    **************************************************************************/
    
    public size_t write (void[] buf, int fd, JobNotification notification)
    {
        ssize_t ret_val;
        int errno_val;
        auto job = this.jobs.reserveJobSlot(&lock_mutex, &unlock_mutex);

        job.recv_buffer = buf;
        job.fd = fd;
        job.suspended_job = notification;
        job.cmd = Job.Command.Write;
        job.ret_val = &ret_val;
        job.errno_val = &errno_val;

        post_semaphore(&this.jobs.jobs_available); 
        notification.wait(job, &this.scheduler.discardResults);

        if (ret_val == -1)
        {
            throw this.exception.set(errno_val, "write");
        }

        verify(ret_val >= 0);
        return cast(size_t)ret_val;
    }

    /***************************************************************************

        Calls an user provided delegate. The delegate is called from within a
        separate thread and it should not do anything non-thread safe (for example,
        using GC must be avoided) from the runtime's perspective. Delegate receives
        a reference to the per-thread context which it can use.

        Params:
            user_delegate = delegate to call
            JobNotification = notification used to resume/suspend the caller

    **************************************************************************/

    public void callDelegate (scope void delegate(AsyncIO.Context) user_delegate,
            JobNotification notification)
    {
        ssize_t ret_val;
        int errno_val;
        auto job = this.jobs.reserveJobSlot(&lock_mutex, &unlock_mutex);

        job.user_delegate = user_delegate;
        job.suspended_job = notification;
        job.cmd = Job.Command.CallDelegate;
        job.ret_val = &ret_val;
        job.errno_val = &errno_val;

        post_semaphore(&this.jobs.jobs_available);
        notification.wait(job, &this.scheduler.discardResults);

        if (ret_val == -1)
        {
            throw this.exception.set(errno_val, "delegate call");
        }

        verify(ret_val >= 0);
    }

    /***************************************************************************

        Finalizes the read request - copies the contents of receive buffer
        to user provided buffer.

        Params:
            job = job to finalize.

    ***************************************************************************/

    private static void finalizeRead (Job* job)
    {
        if (job.ret_val !is null)
        {
            *job.ret_val = job.return_value;
        }

        if (job.return_value >= 0)
        {
            auto dest = (job.user_buffer.ptr)[0..job.return_value];
            copy(dest, job.recv_buffer[0..job.return_value]);
        }
    }

    /***************************************************************************

        Set of non-blocking methods. The user is responsible to suspend the fiber,
        and AsyncIO will not resume it. Instead, the callback will be called
        where the user can do whatever is required.

    ***************************************************************************/

    public final class Nonblocking
    {
        /**************************************************************************

            Issues a pread request, filling the buffer as much as possible,
            expecting the user to suspend the caller manually.

            This will read buf.length number of bytes from fd to buf, starting
            from offset.

            Params:
                buf = buffer to fill
                ret_val = return value to fill
                fd = file descriptor to read from
                offset = offset in the file to read from
                finish_callback_dg = method to call when the request has finished,
                    passing the return value of the pread call
                suspended_job = suspended job to resume upon finishing the
                    IO operation and calling finish_callback_dg

            Returns:
                Job that's scheduled

            Throws:
                ErrnoException with appropriate errno set in case of failure

        **************************************************************************/

        public Job* pread (void[] buf,
                int fd, size_t offset,
                JobNotification suspended_job)
        {
            auto job = this.outer.jobs.reserveJobSlot(&lock_mutex,
                    &unlock_mutex);

            job.recv_buffer.length = buf.length;
            enableStomping(job.recv_buffer);

            job.fd = fd;
            job.offset = offset;
            job.cmd = Job.Command.Read;
            job.user_buffer = buf;
            job.finalize_results = &finalizeRead;
            job.suspended_job = suspended_job;
            suspended_job.register(job, &this.outer.scheduler.discardResults);

            // Let the threads waiting on the semaphore know that they
            // can start doing single read
            post_semaphore(&this.outer.jobs.jobs_available);

            return job;
        }
    }

    /// Ditto
    public Nonblocking nonblocking;

    /// Task wrapper
    public final class TaskBlocking
    {
        import ocean.util.aio.TaskJobNotification;
        import ocean.task.Task;

        public size_t write (void[] buf, int fd)
        {
            assert (Task.getThis() !is null);
            scope JobNotification notification = new TaskJobNotification;
            return this.outer.write(buf, fd, notification);
        }

        public size_t pread (void[] buf, int fd, size_t offset)
        {
            assert (Task.getThis() !is null);
            scope JobNotification notification = new TaskJobNotification;
            return this.outer.pread(buf, fd, offset, notification);
        }

        public void callDelegate (scope void delegate(AsyncIO.Context) user_delegate)
        {
            assert (Task.getThis() !is null);
            scope JobNotification notification = new TaskJobNotification;
            this.outer.callDelegate(user_delegate, notification);
        }
    }

    /// ditto
    public TaskBlocking blocking;

    /**************************************************************************

        Issues a fsync request, blocking the fiber connected to the provided
        suspended_job until the request finishes.

        Synchronize a file's in-core state with storage device.

        Params:
            fd = file descriptor to perform fsync on
            suspended_job = JobNotification instance to
                block the fiber on

        Throws:
            ErrnoException with appropriate errno set in the case of failure

    **************************************************************************/

    public void fsync (int fd,
            JobNotification suspended_job)
    {
        long ret_val;
        int errno_val;

        auto job = this.jobs.reserveJobSlot(&lock_mutex,
                &unlock_mutex);

        job.fd = fd;
        job.suspended_job = suspended_job;
        job.cmd = Job.Command.Fsync;
        job.ret_val = &ret_val;
        job.errno_val = &errno_val;
        job.finalize_results = null;

        // Let the threads waiting on the semaphore that they
        // can perform fsync
        post_semaphore(&this.jobs.jobs_available);

        // Block the fiber
        suspended_job.wait(job, &this.scheduler.discardResults);

        // At this point, fiber is resumed,
        // check the return value and throw if needed
        if (ret_val == -1)
        {
            throw this.exception.set(errno_val,
                    "fsync");
        }
    }

    /**************************************************************************

        Issues a close request, blocking the fiber connected to the provided
        suspendable request handler until the request finishes.

        Synchronize a file's in-core state with storage device.

        Params:
            fd = file descriptor to close
            suspended_job = JobNotification instance to
                block the caller on

        Throws:
            ErrnoException with appropriate errno set in the case of failure

    **************************************************************************/

    public void close (int fd,
            JobNotification suspended_job)
    {
        long ret_val;
        int errno_val;

        auto job = this.jobs.reserveJobSlot(&lock_mutex,
                &unlock_mutex);

        job.fd = fd;
        job.suspended_job = suspended_job;
        job.cmd = Job.Command.Close;
        job.ret_val = &ret_val;
        job.errno_val = &errno_val;
        job.finalize_results = null;

        post_semaphore(&this.jobs.jobs_available);

        // Block the fiber
        suspended_job.wait(job, &this.scheduler.discardResults);

        // At this point, fiber is resumed,
        // check the return value and throw if needed
        if (ret_val == -1)
        {
            throw this.exception.set(errno_val,
                    "close");
        }
    }

    /*********************************************************************

        Destroys entire AsyncIO object.
        It's unusable after this point.

        NOTE: this blocks the calling thread

        Throws:
            ErrnoException if one of the underlying system calls
            failed

    *********************************************************************/

    public void destroy ()
    {
        assert(!this.destroyed);

        // Stop all workers
        // and wait for all threads to exit
        this.join();

        this.jobs.destroy(this.exception);
        this.destroyed = true;
    }

    /**************************************************************************

        Indicate worker threads not to take any more jobs.

        Throws:
            ErrnoException if one of the underlying system calls
            failed

    **************************************************************************/

    private void stopAll ()
    {
        this.jobs.stop(&lock_mutex,
                &unlock_mutex);

        // Let all potential threads blocked on semaphore
        // move forward and exit
        for (int i; i < this.threads.length; i++)
        {
            post_semaphore(&this.jobs.jobs_available);
        }
    }

    /**************************************************************************

        Waits for all threads to finish and checks the exit codes.

        Throws:
            ErrnoException if one of the underlying system calls
            failed

    **************************************************************************/

    private void join ()
    {
        // We need to tell threads actually to stop working
        this.stopAll();

        for (int i = 0; i < this.threads.length; i++)
        {
            // Note: no need for mutex guarding this
            // as this is just an array of ids which
            // will not change during the program's lifetime
            void* ret_from_thread;
            int ret = pthread_join(this.threads[i], &ret_from_thread);

            switch (ret)
            {
                case 0:
                    break;
                default:
                    throw this.exception.set(ret, "pthread_join");
                case EDEADLK:
                    assert(false, "Deadlock was detected");
                case EINVAL:
                    assert(false, "Join performed on non-joinable thread" ~
                            " or another thread is already waiting on it");
                case ESRCH:
                    assert(false, "No thread with this tid can be found");
            }

            // Check the return value from the thread routine
            if (cast(intptr_t)ret_from_thread != 0)
            {
                throw this.exception.set(cast(int)ret_from_thread,
                        "thread_method");
            }
        }
    }

    /*********************************************************************

        Helper function for posting the semaphore value
        and checking for the return value

        Params:
            sem = pointer to the semaphore handle


    *********************************************************************/

    private void post_semaphore (sem_t* sem)
    {
        int ret = sem_post(sem);

        switch (ret)
        {
            case 0:
                break;
            default:
                throw this.exception.set(ret, "sem_post");
            case EINVAL:
                assert(false, "The semaphore is not valid");
        }
    }
}

/// Example showing the task-blocking API
unittest
{
    /// Per-thread context. Can be anything, but it needs to inherit
    // from AsyncIO.Context
    class AioContext: AsyncIO.Context
    {
        int i;
    }

    // Creates the per thread context. This is executed inside
    // each worker thread. Useful to initialize C libraries (e.g.
    // curl_easy_init)
    // This method is synchronized, so everything here is thread safe
    // One must only pay attention not to call methods that need
    // thread-local state
    AsyncIO.Context makeContext()
    {
        auto ctx = new AioContext;

        // set some things
        ctx.i = 0;

        return ctx;
    }
    /// Callback called from another thread to set the counter
    void setCounter (AsyncIO.Context ctx)
    {
        // cast the per-thread context
        auto myctx = cast(AioContext)ctx;
        myctx.i++;
    }

    void example()
    {
        auto async_io = new AsyncIO(theScheduler.epoll, 10, &makeContext);

        // open a new file
        auto f = new File("var/output.txt", File.ReadWriteAppending);

        // write a file in another thread
        char[] buf = "Hello darkness, my old friend.".dup;
        async_io.blocking.write(buf, f.fileHandle());

        // read the file from another thread
        buf[] = '\0';
        async_io.blocking.pread(buf, f.fileHandle(), 0);

        test!("==")(buf[], "Hello darkness, my old friend.");
        test!("==")(f.length, buf.length);

        // call the delegate from another thread
        async_io.blocking.callDelegate(&setCounter);
    }
}
