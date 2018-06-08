/*******************************************************************************

    Common interface for various types of suspendable jobs waiting for
    AsyncIO to finish.

    copyright:
        Copyright (c) 2016-2018 dunnhumby Germany GmbH. All rights reserved

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

*******************************************************************************/

module ocean.util.aio.JobNotification;

/// Ditto
abstract class JobNotification
{
    import ocean.core.array.Mutation: copy;
    import ocean.util.aio.internal.JobQueue: Job;

    /***************************************************************************

        AsyncIO's method that should be called to discard the results of scheduled
        asynchronous method.

    ***************************************************************************/

    private void delegate(Job*) remove_dg;

    /***************************************************************************

        Pointer to the AIO job suspended on this JobNotification.
        Used for canceling the jobs. TODO: is the closure possible combining
        remove_dg and job?

    ***************************************************************************/

    private Job* job;

    /***************************************************************************

        Yields the control to the suspendable job, indicating that the aio
        operation has been done.

    ***************************************************************************/

    protected abstract void wake_ ();

    /***************************************************************************

        Cedes the control from the suspendable job, waiting for the aio
        operation to be done. Implementation is defined by the concrete classes.

    ***************************************************************************/

    protected abstract void wait_();

    /***************************************************************************

        Cedes the control from the suspendable job, waiting for the aio
        operation to be done. Called by AsyncIO framework internally.

        Params:
            remove_dg = delegate to call to inform AIO that results of this job
                        can be discarded.

    ***************************************************************************/

    public final void wait (Job* job, typeof(this.remove_dg) remove_dg)
    {
        scope (failure)
            this.discardResults();

        this.register(job, remove_dg);
        this.wait_();
    }

    /**************************************************************************

        Registers the Job instance with this job notification and sets up
        removal delegate.

        Params:
            job = instance of the job that this job notification is waiting on
            remove_dg = delegate to call to inform AIO that results of this job
                        can be discarded.

    ***************************************************************************/

    public final void register (Job* job, typeof(this.remove_dg) remove_dg)
    {
        this.job = job;
        this.remove_dg = remove_dg;
    }

    /***************************************************************************

        Detaches the Job instance from this JobNotification (the opposite of
        register).

    ***************************************************************************/

    public final void unregister ()
    {
        this.job = null;
    }

    /***************************************************************************

        Yields the control to the suspended job, indicating that the aio
        operation has been done. Called by the AsyncIO framework internally.

    ***************************************************************************/

    public final void wake ()
    {
        this.unregister();
        this.wake_();
    }

    /***************************************************************************

        Should be called by the concrete classes to inform the AIO that
        results of this operation are no longer needed.

    ***************************************************************************/

    public final void discardResults ()
    {
        if (this.job)
        {
            this.remove_dg(this.job);
            this.job = null;
        }
    }
}
