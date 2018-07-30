/*******************************************************************************

    Extension to automate typical task scheduler setup.

    Reads scheduler configuration from app config from [SCHEDULER] section,
    initializes global scheduler instance using it and provides a method to
    start main application method inside a task.

    Expected configuration file format (all fields are optional):

    [SCHEDULER]
    worker_fiber_stack_size = 102400
    worker_fiber_limit = 5
    task_queue_limit = 10
    suspended_task_limit = 16
    specialized_pools =
        pkg.mod.MyTask:1024
        pkg.mod.MyOtherTask:2048

    Copyright:
        Copyright (c) 2017 sociomantic labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.ext.TaskExt;

import ocean.transition;
import ocean.core.array.Search : find;
import ocean.core.Enforce;
import ocean.text.convert.Integer;
import ocean.util.app.ext.model.IConfigExtExtension;
import ocean.task.Scheduler;
import ocean.task.Task;
import ocean.util.config.ConfigParser;
import ocean.util.config.ConfigFiller;
import ocean.meta.codegen.Identifier;

/// ditto
class TaskExt : IConfigExtExtension
{
    /***************************************************************************

        Default scheduler configuration to use in absence of explicit
        configuration setting.

    ***************************************************************************/

    SchedulerConfiguration config;

    /***************************************************************************

        Constructor

        Params:
            config = optional, scheduler configuration to use in absence
                of config file overrides

    ***************************************************************************/

    this ( SchedulerConfiguration config = SchedulerConfiguration.init )
    {
        this.config = config;
    }

    /***************************************************************************

        Parse the configuration file options to get the scheduler configuration

        Params:
            app = the application instance
            parser = configuration instance

    ***************************************************************************/

    public override void processConfig ( IApplication app, ConfigParser parser )
    {
        scope(exit)
            initScheduler(this.config);

        if (parser is null)
            return;

        static immutable category = "SCHEDULER";

        foreach (idx, ref field; this.config.tupleof)
        {
            static if (fieldIdentifier!(SchedulerConfiguration, idx)
                != "specialized_pools")
            {
                field = parser.get(
                    category,
                    fieldIdentifier!(SchedulerConfiguration, idx),
                    field
                );
            }
        }

        auto specialized_pools = parser.getList!(istring)(
            category, "specialized_pools", null);

        foreach (line; specialized_pools)
        {
            if (line.length == 0)
                continue;

            auto idx = find(line, ':');
            enforce(
                idx < line.length,
                "Malformed configuration for scheduler"
            );

            size_t size;
            enforce(
                toInteger(line[idx+1 .. $], size),
                "Malformed configuration for scheduler"
            );

            this.config.specialized_pools ~=
                SchedulerConfiguration.PoolDescription(line[0 .. idx], size);
        }
    }

    /***************************************************************************

        Wraps given delegate returning app exit status code in a new allocated
        task object and immediately starts the scheduler event loop to handle
        it.

        Params:
            dg = delegate forwarding to the app entry point

        Returns:
            app return status code

    ***************************************************************************/

    public int run ( scope int delegate () dg )
    {
        auto task = new class Task {
            int delegate() dg;
            int result = -1;

            override void run ( )
            {
                this.result = this.dg();
            }
        };

        task.dg = dg;
        theScheduler.queue(task);
        theScheduler.eventLoop();

        return task.result;
    }

    /***************************************************************************

        Extension order. Doesn't matter as long as it happens after LogExt.

        Returns:
            the extension order

    ***************************************************************************/

    public override int order ( )
    {
        return -1;
    }

    /***************************************************************************

        Unused IConfigExtExtension method.

        We just need to provide an "empty" implementation to satisfy the
        interface.

        Params:
            app = the application instance
            config = configuration instance

    ***************************************************************************/

    public override void preParseConfig ( IApplication app, ConfigParser config )
    {
        // Unused
    }


    /***************************************************************************

        Unused IConfigExtExtension method.

        We just need to provide an "empty" implementation to satisfy the
        interface.

        Params:
            app = the application instance
            config = configuration instance
            files = current list of configuration files to parse

        Returns:
            new list of configuration files to parse

    ***************************************************************************/

    public override istring[] filterConfigFiles ( IApplication app,
                                         ConfigParser config,
                                         istring[] files )
    {
        // Unused
        return files;
    }
}
