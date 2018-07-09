/*******************************************************************************

    Implements mapping between specific task `TypeInfo` and matching
    `FiberPoolEager` instances intended to serve all tasks of such type.

    Copyright: Copyright (c) 2017 dunnhumby Germany GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.internal.SpecializedPools;

import ocean.meta.types.Qualifiers;
import ocean.task.internal.FiberPoolEager;
import ocean.task.IScheduler;
import ocean.task.Task;
import ocean.core.Verify;
import ocean.core.Enforce;
import ocean.core.Optional;

debug (TaskScheduler)
    import ocean.io.Stdout;

public alias IScheduler.Configuration.PoolDescription PoolDescription;

/*******************************************************************************

    Defines all mappings between task kinds and dedicated worker fiber pools
    processing those.

*******************************************************************************/

public class SpecializedPools
{
    /// mapping as a simple array (expected to contain few elements)
    private SpecializedPool[] mapping;

    /// mapping element
    private static struct SpecializedPool
    {
        istring task_name;
        FiberPoolEager pool;
    }

    /***************************************************************************

        Constructor

        Params:
            config = array of specialized descriptions coming from the scheduler
                configuration

    ***************************************************************************/

    public this ( PoolDescription[] config )
    {
        foreach (description; config)
        {
            verify(description.task_name.length > 0);
            verify(
                description.stack_size >= 1024,
                "Configured stack size is suspiciously low"
            );
            verify(
                !this.findPool(description.task_name).isDefined(),
                "ClasInfo present in task/pool mapping twice"
            );

            debug_trace("Registering specialized worker fiber pool for '{}'",
                description.task_name);

            this.mapping ~= SpecializedPool(
                description.task_name,
                new FiberPoolEager(
                    description.stack_size
                )
            );
        }
    }

    /***************************************************************************

        Lookup specific pool data

        Params:
            task = task type fully qualified name to look for

        Returns:
            `Optional.undefined` is nothing was found, wrapped pool struct
            otherwise

    ***************************************************************************/

    public Optional!(SpecializedPool) findPool ( istring task )
    {
        foreach (meta; this.mapping)
        {
            if (meta.task_name == task)
                return optional(meta);
        }

        return Optional!(SpecializedPool).undefined;
    }

    /***************************************************************************

        Runs task in one of dedicated worker fiber pools if it is registered in
        the mapping.

        Params:
            task = task to run

        Returns: 'true' if task was present in the mapping, 'false' otherwise.

    ***************************************************************************/

    public bool run ( Task task )
    {
        bool found = false;
        auto name = task.classinfo.name;

        this.findPool(name).visit(
            ( ) { },
            (ref SpecializedPool meta) {
                debug_trace("Processing task <{}> in a dedicated fiber pool",
                    cast(void*) task);
                meta.pool.run(task);
                found = true;
            }
        );

        return found;
    }

    /***************************************************************************

        Kills all worker fibers in all pools

    ***************************************************************************/

    public void kill ( )
    {
        debug_trace("Killing all worker fibers in all specialized pools");

        foreach (meta; this.mapping)
        {
            scope iterator = meta.pool.new BusyItemsIterator;
            foreach (ref fiber; iterator)
                fiber.kill();
        }
    }
}

private void debug_trace ( T... ) ( cstring format, T args )
{
    debug ( TaskScheduler )
    {
        Stdout.formatln( "[ocean.task.internal.SpecializedPools] "
            ~ format, args ).flush();
    }
}
