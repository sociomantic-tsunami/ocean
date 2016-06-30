/*******************************************************************************

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.linux.sched;

import ocean.stdc.posix.sys.types: pid_t;
import ocean.stdc.config: c_ulong;
import ocean.stdc.posix.time: timespec;
import ocean.stdc.string: memset;

extern (C):

private // helpers
{

    /* Size definition for CPU sets.  */
    enum
    {
        __CPU_SETSIZE = 1024,
        __NCPUBITS  = 8 * cpu_mask.sizeof,
    }

    /* Macros */

    /* Basic access functions.  */
    size_t __CPUELT(size_t cpu)
    {
        return cpu / __NCPUBITS;
    }
    cpu_mask __CPUMASK(size_t cpu)
    {
        return 1UL << (cpu % __NCPUBITS);
    }

    cpu_mask __CPU_SET_S(size_t cpu, size_t setsize, cpu_set_t* cpusetp)
    {
        if (cpu < 8 * setsize)
        {
            cpusetp.__bits[__CPUELT(cpu)] |= __CPUMASK(cpu);
            return __CPUMASK(cpu);
        }

        return 0;
    }
}

/* Data structure to describe a process' schedulability.  */
struct sched_param
{
    int __sched_priority;
}

/* Type for array elements in 'cpu_set_t'.  */
alias c_ulong cpu_mask;

/* Data structure to describe CPU mask.  */
struct cpu_set_t
{
    cpu_mask[__CPU_SETSIZE / __NCPUBITS] __bits;
}

/* Access macros for `cpu_set' (missing a lot of them) */

cpu_mask CPU_SET(size_t cpu, cpu_set_t* cpusetp)
{
     return __CPU_SET_S(cpu, cpu_set_t.sizeof, cpusetp);
}

/* Functions */
int sched_setparam (pid_t pid, sched_param* param);
int sched_getparam (pid_t pid, sched_param* param);
int sched_setscheduler (pid_t pid, int policy, sched_param* param);
int sched_getscheduler (pid_t pid);
int sched_yield ();
int sched_get_priority_max (int algorithm);
int sched_get_priority_min (int algorithm);
int sched_rr_get_interval (pid_t pid, timespec* t);
int sched_setaffinity(pid_t pid, size_t cpusetsize, cpu_set_t *mask);
int sched_getaffinity(pid_t pid, size_t cpusetsize, cpu_set_t *mask);

