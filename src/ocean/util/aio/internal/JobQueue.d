/******************************************************************************

    Module containing implementation of the request queue for AsyncIO.

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

******************************************************************************/

module ocean.util.aio.internal.JobQueue;

import ocean.transition;

import core.stdc.errno;
import core.stdc.stdint;
import core.sys.posix.unistd;
import core.sys.posix.semaphore;
import core.sys.posix.pthread;

import ocean.sys.ErrnoException;

import ocean.util.aio.AsyncIO;
import ocean.util.aio.JobNotification;
import ocean.util.aio.internal.AioScheduler;

/**********************************************************************

    Single job definition

**********************************************************************/

public static struct Job
{
    import ocean.core.array.Mutation: copy;
    import ocean.util.aio.internal.MutexOps;

    /******************************************************************

        Command to be executed for the current request.

    *******************************************************************/

    public enum Command
    {
        Read,
        Write,
        Fsync,
        Close,
        CallDelegate,
    }

    /******************************************************************

        Command to run for this request

    ******************************************************************/

    public Command cmd;

    /****************************************************************

        File descriptor of the file to perform
        the request on

    ****************************************************************/

    public int fd;

    /****************************************************************

        Offset from the file to perform the request

    ****************************************************************/

    public size_t offset;

    /****************************************************************

        User supplied delegate to call.

    ****************************************************************/

    public void delegate (AsyncIO.Context) user_delegate;

    /****************************************************************

        The field to store the return value of the system call.

    ****************************************************************/

    public ssize_t return_value;

    /****************************************************************

        Pointer to variable which should receive the return value of
        the system call.

    ****************************************************************/

    public ssize_t* ret_val;

    /****************************************************************

        Pinter to variable which should receive the errno value
        after the system call

    ****************************************************************/

    public int* errno_val;

    /****************************************************************

        JobNotification used to wake the job.

    ****************************************************************/

    public JobNotification suspended_job;

    /****************************************************************

        Indicates if the job is being handled within one
        of the threads

    ****************************************************************/

    private bool is_taken;

    /****************************************************************

        Indicates if this slot in the queue is empty
        and can be taken

    ****************************************************************/

    private bool is_slot_free;

    /****************************************************************

        Buffer to be filled by the worker thread. When the job is
        finalised, the contents are copied into user_buffer.

    ****************************************************************/

    public void[] recv_buffer;

    /***************************************************************

        User buffer to copy the results to. NOTE: the reason to have
        recv_buffer and user_buffer separate is because it might happen
        that user discards the job and the buffer, while thread is
        writing into it, in which case the contents of recv_buffer
        are discarded.

    ****************************************************************/

    public void[] user_buffer;

    /***************************************************************************

        Prepares the results, called upon the completion of the request,
        if the jobs has not been cancelled while waiting for the completion.

    ***************************************************************************/

    public void function(Job* job) finalize_results;

    /***************************************************************************

        User-provided method to call when the job has been completed.

    ***************************************************************************/

    public void delegate(ssize_t)[]  finish_callback_dgs;

    /***************************************************************************

        Job queue where this jobs is currently resident. Used for recycling.

    ***************************************************************************/

    private JobQueue owner_queue;

    /***************************************************************************

        Performs any actions at the end of the AIO operation.

    ***************************************************************************/

    public void finished ()
    {
        if ((&this).finalize_results)
        {
            (&this).finalize_results((&this));
        }

        if ((&this).finish_callback_dgs.length)
        {
            foreach (dg; (&this).finish_callback_dgs)
            {
                dg((&this).return_value);
            }
        }
    }

    /***************************************************************************

        Registers the callback to call after finishing the job.

        Params:
            dg = delegate to call when the job is finished.

    ***************************************************************************/

    public Job* registerCallback (scope void delegate(ssize_t) dg)
    {
        (&this).finish_callback_dgs ~= dg;
        return (&this);
    }

    /***************************************************************************

        Recycles the job and marks it free to use by the AIO for the next
        operation.

    ***************************************************************************/

    public void recycle ()
    {
        (&this).owner_queue.recycleJob((&this), &lock_mutex, &unlock_mutex);
    }
}

/**************************************************************************

    Pending jobs queue.

**************************************************************************/

public static class JobQueue
{
    import ocean.util.container.LinkedList;


    /********************************************************************

        List containing requests.
        Note that, since the worker threads are taking
        pointers to jobs, moving container must not be used
        as that would invalidate pointers to the exiting jobs
        held by other threads

    *********************************************************************/

    private LinkedList!(Job*) jobs;


    /********************************************************************

        Mutex protecting job queue.

    ********************************************************************/

    private pthread_mutex_t jobs_mutex;


    /*********************************************************************

        Indicator if workers should
        stop doing more work

    *********************************************************************/

    private bool cancel_further_jobs;


    /*********************************************************************

        AioScheduler used to wake the ready jobs.

    *********************************************************************/

    private AioScheduler scheduler;

    /*********************************************************************

        Constructor

        Params:
            exception = ErrnoException instance to throw in case
                        initialization failed
            scheduler = AioScheduler to schedule waking the jobs on

    *********************************************************************/

    public this (ErrnoException exception, AioScheduler scheduler)
    {
        this.jobs = new typeof(this.jobs);
        this.scheduler = scheduler;

        exception.enforceRetCode!(pthread_mutex_init).call(
                &this.jobs_mutex, null);

        exception.enforceRetCode!(sem_init).call
            (&this.jobs_available, 0, 0); // No jobs are ready initially
    }


    /*********************************************************************

        Takes the first jobs in the queue that's not being
        served by any other thread.

        Params:
            MutexOp = function or delegate mutex accepting the pointer to the
                mutex. Used so this method works both with delegate and
                function.
            lock_mutex = method to be called to lock a mutex and perform
                         error checking
            unlock_mutex = method to be called to unlock a mutex and perform
                         error checking

    *********************************************************************/

    public Job* takeFirstNonTakenJob(MutexOp)(MutexOp lock_mutex,
            MutexOp unlock_mutex)
    {
        lock_mutex(&this.jobs_mutex);
        scope (exit)
        {
            unlock_mutex(&this.jobs_mutex);
        }

        if (this.cancel_further_jobs)
        {
            return null;
        }

        foreach (ref job; this.jobs)
        {
            if (job.is_slot_free == false && job.is_taken == false)
            {
                job.is_taken = true;
                return job;
            }
        }

        return null;
    }

    /*********************************************************************

        Reserves a job slot in the queue. It either reuses
        existing slot, or allocates a new one if all
        existing slots are occupied

        Params:
            MutexOp = function or delegate mutex accepting the pointer to the
                mutex. Used so this method works both with delegate and
                function.
            lock_mutex = method to be called to lock a mutex and perform
                         error checking
            unlock_mutex = method to be called to unlock a mutex and perform
                         error checking

        Returns:
            pointer to the job slot in the queue

    *********************************************************************/

    public Job* reserveJobSlot(MutexOp)(MutexOp lock_mutex,
            MutexOp unlock_mutex)
    {
        lock_mutex(&this.jobs_mutex);
        scope (exit)
        {
            unlock_mutex(&this.jobs_mutex);
        }

        Job* free_job = null;

        foreach (ref job; this.jobs)
        {
            if (job.is_slot_free && !job.is_taken)
            {
                free_job = job;
                break;
            }
        }

        if (!free_job)
        {
            // adds at the beginning
            auto new_job = new Job();
            this.jobs.add(new_job);
            free_job = this.jobs.get(0);
        }

        free_job.is_taken = false;
        free_job.is_slot_free = false;
        free_job.owner_queue = this;
        free_job.finish_callback_dgs.length = 0;
        enableStomping(free_job.finish_callback_dgs);
        free_job.ret_val = null;
        free_job.errno_val = null;

        return free_job;
    }

    /*********************************************************************

        Marks the job as ready and schedules the routine to be waken
        up by the scheduler.

        Params:
            job = job that has completed
            lock_mutex = function or delegate to lock the mutex
            unlock_mutex = function or delegate to unlock the mutex

    *********************************************************************/

    public void markJobReady(MutexOp) ( Job* job,
            MutexOp lock_mutex, MutexOp unlock_mutex )
    {
        this.scheduler.requestReady(job,
                lock_mutex, unlock_mutex);
    }

    /*********************************************************************

        Recycles the job slot and checks if there are any more jobs to
        be served.

        Params:
            MutexOp = function or delegate mutex accepting the pointer to the
                mutex. Used so this method works both with delegate and
                function.
            job = job to recycle
            lock_mutex = method to be called to lock a mutex and perform
                         error checking
            unlock_mutex = method to be called to unlock a mutex and perform
                         error checking

        Returns:
            true if there will be more jobs, false otherwise


    *********************************************************************/

    public bool recycleJob(MutexOp) (Job* job, MutexOp lock_mutex,
            MutexOp unlock_mutex)
    {
        if (this.cancel_further_jobs)
            return false;

        lock_mutex(&this.jobs_mutex);
        scope(exit)
        {
            unlock_mutex(&this.jobs_mutex);
        }

        job.is_taken = false;
        job.is_slot_free = true;

        return !this.cancel_further_jobs;
    }

    /*********************************************************************

        Tells the queue to stop serving more jobs to workers.

        Params:
            MutexOp = function or delegate mutex accepting the pointer to the
                mutex. Used so this method works both with delegate and
                function.
            lock_mutex = method to be called to lock a mutex and perform
                         error checking
            unlock_mutex = method to be called to unlock a mutex and perform
                         error checking


    *********************************************************************/

    public void stop(MutexOp) (MutexOp lock_mutex,
            MutexOp unlock_mutex)
    {
        lock_mutex(&this.jobs_mutex);
        scope(exit)
        {
            unlock_mutex(&this.jobs_mutex);
        }

        this.cancel_further_jobs = true;
    }

    /*********************************************************************

        Destructor

        Params:
            exception = ErrnoException instance to throw in case destruction
            failed

    *********************************************************************/

    public void destroy (ErrnoException exception)
    {
        // Can only fail if the mutex is still held somewhere.  Since users
        // should already be joined on all threads, that should not be
        // possible.
        auto ret = pthread_mutex_destroy(&this.jobs_mutex);

        switch (ret)
        {
            case 0:
                break;
            default:
                throw exception.set(ret, "pthread_mutex_destroy");
            case EBUSY:
                assert(false, "Mutex still held");
            case EINVAL:
                assert(false, "Mutex reference is invalid");
        }

        ret = sem_destroy(&this.jobs_available);

        switch (ret)
        {
            case 0:
                break;
            default:
                throw exception.set(ret, "sem_destroy");
            case EINVAL:
                assert(false, "Semaphore is not valid.");
        }
    }

    /********************************************************************

        Semaphore indicating number of jobs in the request queue.

    ********************************************************************/

    public sem_t jobs_available;
}
