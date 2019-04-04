/*******************************************************************************

    Simple utility to run a delegate inside a task while automatically starting
    event loop behind the scen. Intended for usage in script-like programs, does
    a new allocation each call.

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.util.QuickRun;

import ocean.task.IScheduler;
import ocean.task.Task;
import ocean.core.Verify;

/*******************************************************************************

    Turns `dg` into a task and runs it through scheduler. Starts the event loop
    automatically and will finish only when all tasks finish and no registered
    events remain (or `theScheduler.shutdown` is called).

    Requires `initScheduler` to be already called before.

    Params:
        dg = delegate to run inside a task. Return value of the delegate will
            be propagated as the return value of `quickRun` itself, which can
            used as app exit status code.

*******************************************************************************/

public int quickRun ( scope int delegate () dg )
{
    auto task = new DgTask(dg);
    theScheduler.queue(task);
    theScheduler.eventLoop();
    verify(task.finished());
    return task.result;
}

///
unittest
{
    int main ( )
    {
        // Make sure the scheduler is initialized first, e.g.:
        // initScheduler(SchedulerConfiguration.init);

        return quickRun({
            // code that has to run inside task
            return 42;
        });
    }
}

/*******************************************************************************

    Helper to turn a delegate into a task.

*******************************************************************************/

private class DgTask : Task
{
    int delegate () dg;
    int result;

    this (scope int delegate() dg)
    {
        this.dg = dg;
    }

    override void run ()
    {
        this.result = this.dg();
    }
}
