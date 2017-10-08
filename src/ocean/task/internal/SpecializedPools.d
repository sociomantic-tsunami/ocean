/*******************************************************************************

    Implements mapping between specific task `TypeInfo` and matching
    `FiberPoolEager` instances intended to serve all tasks of such type.

    Copyright: Copyright (c) 2017 sociomantic Labs GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.internal.SpecializedPools;

import ocean.meta.types.Qualifiers;
import ocean.task.internal.FiberPoolEager;
import ocean.task.Task;
import ocean.core.Verify;
import ocean.core.Enforce;
import ocean.core.Optional;

debug (TaskScheduler)
    import ocean.io.Stdout;

/*******************************************************************************

    Defines single mapping of `ClassInfo` to worker fiber pool in configuration

*******************************************************************************/

public struct PoolDescription
{
    /// result of `Task.classinfo` for task type which is to be handled
    /// by this pool
    ClassInfo task_kind;

    /// worker fiber allocate stack size
    size_t stack_size;
}

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
        ClassInfo task_kind;
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
            verify(description.task_kind !is null);
            verify(
                description.stack_size >= 1024,
                "Configured stack size is suspiciously low"
            );
            verify(
                !this.findPool(description.task_kind).isDefined(),
                "ClasInfo present in task/pool mapping twice"
            );

            debug_trace("Registering specialized worker fiber pool for '{}'",
                description.task_kind.name);

            this.mapping ~= SpecializedPool(
                description.task_kind,
                new FiberPoolEager(
                    description.stack_size
                )
            );
        }
    }

    /***************************************************************************

        Lookup specific pool data

        Params:
            task = task type info to look for

        Returns:
            `Optional.undefined` is nothing was found, wrapped pool struct
            otherwise

    ***************************************************************************/

    public Optional!(SpecializedPool) findPool ( ClassInfo task )
    {
        foreach (meta; this.mapping)
        {
            if (meta.task_kind is task)
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
        auto ti = task.classinfo;

        this.findPool(ti).visit(
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
