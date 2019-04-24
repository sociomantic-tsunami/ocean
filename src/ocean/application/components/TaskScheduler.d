/*******************************************************************************

    Support for scheduler config and running an app's main logic in a Task.

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.application.components.TaskScheduler;

import ocean.transition;
import ocean.core.array.Search : find;
import ocean.core.Enforce;
import ocean.meta.codegen.Identifier;
import ocean.task.Scheduler;
import ocean.task.Task;
import ocean.text.convert.Integer;
import ocean.util.config.ConfigParser;

/*******************************************************************************

    Parses the task scheduler config from the provided config parser.

    Params:
        parser = config parser instance
        config = scheduler config instance to set fields of

*******************************************************************************/

public void parseSchedulerConfig ( ConfigParser parser,
    ref SchedulerConfiguration config )
{
    if (parser is null)
        return;

    static immutable category = "SCHEDULER";

    foreach (idx, ref field; config.tupleof)
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

        config.specialized_pools ~=
            SchedulerConfiguration.PoolDescription(line[0 .. idx], size);
    }
}

/*******************************************************************************

    Runs the specified delegate in a task.

    Params:
        dg = application main delegate to run in a task

    Returns:
        exit code to return to the OS

*******************************************************************************/

public int runInTask ( scope int delegate () dg )
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
