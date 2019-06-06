/*******************************************************************************

    DelegateJobNotification. Used for notifying jobs from the AsyncIO.
    Allows the job to specify how it will be suspended and resumed via
    delegates.

    resume_job delegate is always requried, unlike suspend_job delegate: in
    the case where the job needs to suspend itself at the convenient
    location, no suspend_job delegate should be passed. One usage of this
    behaviour would be to allow resuming the job from the several
    external systems (e.g. from the disk IO and from the network), allowing
    the job to suspend itself at the convenient point where it's possible
    to distinguish if the job is resumed from the network or from the
    AsyncIO.

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

*******************************************************************************/

module ocean.util.aio.DelegateJobNotification;

import ocean.util.aio.JobNotification;
import ocean.core.Verify;

/// ditto
class DelegateJobNotification: JobNotification
{
    import ocean.core.Enforce: enforce;

    /***************************************************************************

        Delegate to resume the suspended job.

    ***************************************************************************/

    private void delegate() resume_job;

    /***************************************************************************

        Delegate to suspend the running job.

    ***************************************************************************/

    private void delegate() suspend_job;


    /***************************************************************************

        Constructor. Initializes DelegateJobNotification.

        Params:
            resume_job = delegate to call to resume suspended job
            suspend_job = delegate to call to suspend current job, null
                              if that should not be possible

    ***************************************************************************/

    public this (scope void delegate() resume_job,
            scope void delegate() suspend_job = null)
    {
        this.initialise(resume_job, suspend_job);
    }


    /***************************************************************************

        Initialization method. Initializes ManualJobNotification (separated
        from constructor for convenient use in reusable pool).

        Params:
            resume_job = delegate to call to resume suspended job
            suspend_job = delegate to call to suspend current job, null
                              if that should not be possible

    ***************************************************************************/

    public typeof(this) initialise (scope void delegate() resume_job,
            scope void delegate() suspend_job = null)
    {
        this.resume_job = resume_job;
        this.suspend_job = suspend_job;
        return this;
    }

    /***************************************************************************

        Yields the control to the suspended job, indicating that the aio
        operation has been done.

    ***************************************************************************/

    public override void wake_ ()
    {
        this.resume_job();
    }

    /***************************************************************************

        Cedes the control from the suspendable job, waiting for the aio
        operation to be done.

    ***************************************************************************/

    public override void wait_ ()
    {
        verify(&this.suspend_job !is null,
                "This job is not allowed to be suspended.");
        this.suspend_job();
    }
}
