/*******************************************************************************

    Task suspend/resume interface for suspendable jobs waiting
    for AsyncIO to finish.

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

*******************************************************************************/

module ocean.util.aio.TaskJobNotification;

import ocean.task.Task;
import ocean.task.util.Event;
import ocean.core.Verify;
import ocean.util.aio.DelegateJobNotification;

/// ditto
class TaskJobNotification: DelegateJobNotification
{
    /***************************************************************************

        Constructor.

    ***************************************************************************/

    this ()
    {
        this.task = Task.getThis();
        super(&this.trigger, &this.wait);
    }

    /**************************************************************************

        Triggers the event.

    **************************************************************************/

    private void trigger ()
    {
        this.event.trigger();
    }

    /**************************************************************************

        Waits on the event.

    **************************************************************************/

    private void wait ()
    {
        this.event.wait();
    }

    /**************************************************************************

        Resets the notification to a current task.

    **************************************************************************/

    public void reset ()
    {
        this.task = Task.getThis();
    }

    /**************************************************************************

        Task to be resumed.

    **************************************************************************/

    private Task task;

    /**************************************************************************

        TaskTriggerEvent used to resume a task.

    **************************************************************************/

    private TaskEvent event;
}
