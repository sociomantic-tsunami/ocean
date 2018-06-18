/*******************************************************************************

    Test for ocean.util.app.ext.TaskExt

    Copyright:
        Copyright (c) 2017 sociomantic labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module integrationtest.taskext_daemon.main;

import ocean.transition;
import ocean.util.app.DaemonApp;
import ocean.util.test.DirectorySandbox;
import ocean.task.Task;
import ocean.task.Scheduler;
import ocean.core.Test;
import ocean.io.device.File;
import Version;

class HarmlessException : Exception
{
    this ( )
    {
        super("");
    }
}

class AnotherTask : Task
{
    override public void run ( )
    {
        auto stats = theScheduler.getStats();
        // must be 1 (only main app task), not 2, as this task is configured
        // to run via dedicated worker fiber pool
        test!("==")(stats.worker_fiber_busy, 1);
    }
}

class TestApp : DaemonApp
{
    this ( )
    {
        istring name = "test app";
        istring desc = name;
        DaemonApp.OptionalSettings settings;
        settings.use_task_ext = true;
        super(name, desc, VersionInfo.init, settings);
    }

    override int run ( Arguments args, ConfigParser config )
    {
        theScheduler.exception_handler = (Task, Exception e)
        {
            throw e;
        };

        test(Task.getThis() !is null);
        test(isSchedulerUsed());
        auto stats = theScheduler.getStats();
        test!("==")(stats.worker_fiber_total, 3);
        theScheduler.schedule(new AnotherTask);
        throw new HarmlessException;
    }
}

version(UnitTest) {} else
int main ( istring[] cl_args )
{
    with (DirectorySandbox.create(["etc", "log"]))
    {
        scope (success)
            remove();
        scope (failure)
            exitSandbox();

        File.set("etc/config.ini", "[SCHEDULER]
worker_fiber_limit = 3
specialized_pools =
    integrationtest.taskext_daemon.main.AnotherTask:10240
    whatever:1024
[LOG.Root]
console = false");

        auto app = new TestApp;

        testThrown!(HarmlessException)(app.main(cl_args));
    }

    return 0;
}
