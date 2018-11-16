/*******************************************************************************

    Utility to wrap any task and turn it into valid `ISuspendable`.

    Originally `Task` class itself was implementing `ISuspendable` but it had
    to be removed because with current scheduler implementation it is not legal
    for tasks to resume each other directly. Calling `suspend` is also only
    legal from within the to-be-suspended task.

    `TaskSuspender` workarounds it by calling `delayedResume` instead on a
    wrapped task and adding extra sanity checks about suspending context.

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.util.TaskSuspender;

import ocean.io.model.ISuspendable;
import ocean.task.Task;
import ocean.task.IScheduler;
import ocean.core.Verify;

/// ditto
public class TaskSuspender : ISuspendable
{
    private Task task;

    /***************************************************************************

        Constructor

        Params:
            task = task instance to wrap as suspendable

    ***************************************************************************/

    public this ( Task task )
    {
        verify(task !is null);
        this.task = task;
    }

    /***************************************************************************

        Implements resuming as delayed resuming

    ***************************************************************************/

    override public void resume ( )
    {
        theScheduler.delayedResume(this.task);
    }

    /***************************************************************************

        Forwards suspending to task while ensuring that it is called from
        within the task context.

    ***************************************************************************/

    override public void suspend ( )
    {
        auto context = Task.getThis();
        verify(context is this.task);
        context.suspend();
    }

    /***************************************************************************

        Returns:
            task state (true if suspended)

    ***************************************************************************/

    override public bool suspended ( )
    {
        return this.task.suspended();
    }
}
