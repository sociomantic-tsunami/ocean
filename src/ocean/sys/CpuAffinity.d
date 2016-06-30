/*******************************************************************************

    Functions to set a process' CPU affinity.

    This module uses the GNU API and contains declarations and functionality
    found in <sched.h> on GNU/Linux. See
    http://www.gnu.org/software/libc/manual/html_node/CPU-Affinity.html

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.CpuAffinity;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.stdc.posix.sys.types : pid_t;



/*******************************************************************************

    Definition of external functions required to set cpu affinity.

*******************************************************************************/

private extern ( C )
{
    /* Type for array elements in 'cpu_set_t'.  */
    mixin(Typedef!(uint, "__cpu_mask"));

    /* Size definition for CPU sets.  */
    const __CPU_SETSIZE = 1024;
    const __NCPUBITS = (8 * __cpu_mask.sizeof);

    /* Data structure to describe CPU mask.  */
    struct cpu_set_t
    {
        __cpu_mask[__CPU_SETSIZE / __NCPUBITS] __bits;
    }

    int sched_setaffinity(pid_t pid, size_t cpusetsize, cpu_set_t *mask);
}



/*******************************************************************************

    Struct containing static functions for cpu affinity.

*******************************************************************************/

public struct CpuAffinity
{
    import ocean.sys.ErrnoException;
    import ocean.stdc.errno: EINVAL;

static:

    /***************************************************************************

        Sets the CPU affinity of the calling process.

        Params:
            cpu = index of cpu to run process on

        Throws:
            ErrnoException on failure. Possible errors:
            - EINVAL: The processor is not currently physically on the system
                and permitted to the process according to any restrictions that
                may be imposed by the "cpuset" mechanism described in cpuset(7).
            - EPERM: The calling process does not have appropriate privileges.

    ***************************************************************************/

    public void set ( uint cpu )
    {
        try
        {
            cpu_set_t cpu_set;
            CPU_SET(cast(__cpu_mask)cpu, cpu_set);

            const pid_t pid = 0; // 0 := calling process
            if (sched_setaffinity(pid, cpu_set_t.sizeof, &cpu_set))
            {
                throw (new ErrnoException).useGlobalErrno("sched_setaffinity");
            }
        }
        catch (ErrnoException e)
        {
            /*
             * Add a sensible error message for EINVAL because this error can be
             * caused by a bad parameter value in the config.ini, and the
             * standard message "sched_setaffinity: Invalid argument" may appear
             * cryptic to the user.
             */

            if (e.errorNumber == EINVAL)
            {
                e.append(" - probably attempted to set the CPU affinity to a " ~
                         "CPU that doesn't exist in this system.");
            }

            throw e;
        }
    }


    // TODO: multiple CPU affinity setter (if needed)


    /***************************************************************************

        CPU index bit mask array index. Converted from the __CPUELT macro
        defined in bits/sched.h:

        ---

            # define __CPUELT(cpu)    ((cpu) / __NCPUBITS)

        ---

        Params:
            cpu = cpu index

        Returns:
            index of bit mask array element which the indexed cpu is within

    ***************************************************************************/

    private size_t CPUELT ( uint cpu )
    {
        return (cpu / __NCPUBITS);
    }


    /***************************************************************************

        CPU index bit mask. Converted from the __CPUMASK macro defined in
        bits/sched.h:

        ---

            # define __CPUMASK(cpu) ((__cpu_mask) 1 << ((cpu) % __NCPUBITS))

        ---

        Params:
            cpu = cpu index

        Returns:
            bit mask with the indexed cpu set to 1

    ***************************************************************************/

    private __cpu_mask CPUMASK ( uint cpu )
    {
        return cast(__cpu_mask)(1 << (cpu % __NCPUBITS));
    }


    /***************************************************************************

        Sets the bit mask of the provided cpu_set_t to the indexed cpu.
        Converted from the __CPU_SET macro defined in bits/sched.h:

        ---

            # define __CPU_SET(cpu, cpusetp) \
              ((cpusetp)->__bits[__CPUELT (cpu)] |= __CPUMASK (cpu))

        ---

        Params:
            cpu = cpu index
            set = cpu set

        Throws:
            ErrnoException (EINVAL) if cpu is too high to fit in set.

    ***************************************************************************/

    private void CPU_SET ( uint cpu, ref cpu_set_t set )
    {
        auto i = CPUELT(cpu);

        if (i < set.__bits.length)
        {
            set.__bits[i] |= CPUMASK(cpu);
        }
        else
        {
            throw (new ErrnoException).set(EINVAL, "CPU_SET")
                                      .append(" - CPU index too high");
        }
    }
}

