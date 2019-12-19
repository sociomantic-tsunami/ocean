/*******************************************************************************

    Test for ocean.util.app.ext.TaskExt for CliApp

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module integrationtest.taskext_cli.main;

import ocean.transition;
import ocean.util.app.CliApp;
import ocean.text.Arguments;
import ocean.task.Task;
import ocean.task.Scheduler;
import ocean.core.Test;
import Version;

class HarmlessException : Exception
{
    this ( )
    {
        super("");
    }
}

class TestApp : CliApp
{
    this ( )
    {
        istring name = "test app";
        istring desc = name;
        CliApp.OptionalSettings settings;
        settings.use_task_ext = true;
        settings.scheduler_config.worker_fiber_limit = 5;
        super(name, desc, VersionInfo.init, settings);
    }

    override int run ( Arguments args )
    {
        theScheduler.exception_handler = (Task, Exception e)
        {
            throw e;
        };

        test(Task.getThis() !is null);
        test(isSchedulerUsed());
        auto stats = theScheduler.getStats();
        test!("==")(stats.worker_fiber_total, 5);
        throw new HarmlessException;
    }
}


version (unittest) {} else
int main ( istring[] cl_args )
{
    auto app = new TestApp;
    testThrown!(HarmlessException)(app.main(cl_args));
    return 0;
}
