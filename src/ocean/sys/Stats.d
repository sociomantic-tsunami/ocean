/*******************************************************************************

    Contains API to obtain various information about the running application.

    Copyright:
        Copyright (c) 2009-2017 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.Stats;

import ocean.transition;
import ocean.core.Enforce;
import ocean.core.array.Mutation;
import core.sys.posix.sys.resource;
import ProcVFS = ocean.sys.stats.linux.ProcVFS;
import ocean.sys.stats.linux.Queriable;
import ocean.util.log.Logger;
import ocean.meta.traits.Indirections;

/// Logger for logging errors
private Logger stats_module_logger;
static this ()
{
    stats_module_logger = Log.lookup("ocean.sys.Stats");
}

/***************************************************************************

    Convenience wrapper around stats about open/max file descriptors,
    useful for logging in stats log.

***************************************************************************/

public struct OpenFileStats
{
    /// Limit for the number of open fds.
    long open_fds_limit;
    /// Number of currently open fds in a process
    int open_fds_currently;
}

/***************************************************************************

    Gets the file descriptor stats for the process.

    Returns:
        instance of filled OpenFileStats

    Note:
        In order to get the number of open files, this method iterates
        through the directory entires in /proc VFS. This implies that it should
        not be called multiple times a second, as there might be performance
        implications. Ideally, it's called every 30 seconds, or so, just
        to generate the stats.log as needed.

    Throws:
        ErrnoException if the underlying system calls fail.

***************************************************************************/

public OpenFileStats getNumFilesStats ()
{
    OpenFileStats stats;
    stats.open_fds_limit = maximumProcessNumFiles().rlim_cur;
    stats.open_fds_currently = ProcVFS.getOpenFdCount();
    return stats;
}

/*******************************************************************************

    Class used for getting used CPU percentage and used memory for the
    current process.

*******************************************************************************/

public class CpuMemoryStats
{
    /***************************************************************************

        Structure representing recorded stats.

    ***************************************************************************/

    public struct Stats
    {
        /// Consumed CPU percentage in user mode
        public float cpu_user;

        /// Consumed CPU percentage in system mode
        public float cpu_system;

        /// Total consumed CPU percentage
        public float cpu_total;

        /// Virtual memory size
        public ulong vsz;

        /// Resident set size
        public ulong rss;

        /// Total memory usage in percents
        public float mem_percentage;
    }

    /// Previous recorded uptime, used for generating stats
    private ProcVFS.ProcUptime previous_uptime;

    /// Previous recorded /proc/self/stat, used for generating stats
    private ProcVFS.ProcStat previous_stat;

    /// Curent recorded uptime, used for generating stats, updated each cycle
    ProcVFS.ProcUptime current_uptime;

    /// Curent recorded /proc/self/stat, used for generating stats, updated each
    /// cycle
    ProcVFS.ProcStat current_stat;

    /// System configuration facts used for calculating stats
    private static long clock_ticks_per_second;

    /// System configuration facts used for calculating stats
    private static long page_size;

    /// System configuration facts used for calculating stats
    private static ulong total_memory;

    /***************************************************************************

        Constructor.

        Prepares CpuMemoryStats for recording stats.

    ***************************************************************************/

    public this ( )
    {
        this.clock_ticks_per_second = getClockTicksPerSecond();
        this.page_size = getPageSize();
        this.total_memory = ProcVFS.getTotalMemoryInBytes();

        this.previous_uptime = ProcVFS.getProcUptime();
        enforce(ProcVFS.getProcSelfStat(this.previous_stat));
    }

    /***************************************************************************

        Get's the cpu and memory stats for the current process.

        Returns:
            Stats instance recording the current stats.

    ***************************************************************************/

    public Stats collect ()
    {
        Stats stats;

        try
        {
            this.current_uptime = ProcVFS.getProcUptime();
            enforce(ProcVFS.getProcSelfStat(this.current_stat));
        }
        catch (Exception e)
        {
            .stats_module_logger.error("Couldn't get stats for the process: {}@{}:{}",
                getMsg(e), e.file, e.line);

            return stats;
        }

        auto uptime_diff = this.current_uptime.uptime - this.previous_uptime.uptime;

        // Safety check for divide by zero
        if (uptime_diff.seconds == 0 && uptime_diff.cents == 0)
        {
            stats.cpu_user = float.nan;
            stats.cpu_system = float.nan;
            stats.cpu_total = float.nan;
        }
        else
        {
            auto ticks_diff = convertToTicks(uptime_diff);

            stats.cpu_user = (this.current_stat.utime <= this.previous_stat.utime) ? 0 :
                ((this.current_stat.utime - this.previous_stat.utime) / ticks_diff * 100);

            stats.cpu_system = (this.current_stat.stime <= this.previous_stat.stime) ? 0 :
                ((this.current_stat.stime - this.previous_stat.stime) / ticks_diff * 100);

            auto previous_total = this.previous_stat.utime + this.previous_stat.stime;
            auto current_total = this.current_stat.utime + this.current_stat.stime;

            stats.cpu_total = (current_total <= previous_total) ? 0 :
                ((current_total - previous_total) / ticks_diff * 100);
        }

        stats.vsz = this.current_stat.vsize;
        stats.rss = this.current_stat.rss * this.page_size;
        stats.mem_percentage = cast(float)stats.rss / this.total_memory * 100;

        this.previous_uptime = current_uptime;
        foreach (idx, ref field; this.current_stat.tupleof)
        {
            static if (!hasIndirections!(typeof(field)))
                this.previous_stat.tupleof[idx] = field;
            else
                copy(this.previous_stat.tupleof[idx], field);
        }

        return stats;
    }

    /// ditto
    deprecated("ocean.sys.Stats.CpuMemoryStats.log is deprecated. Use collect instead.")
    public Stats log ()
    {
        return this.collect();
    }

    /***************************************************************************

        Converts the Uptime type to number of ticks.

        Params:
            time = time to convert

        Returns:
            time represented in ticks

    ***************************************************************************/

    private float convertToTicks (ProcVFS.ProcUptime.Time time)
    {
        return time.seconds * this.clock_ticks_per_second +
            time.cents * this.clock_ticks_per_second / 100.0f;
    }

}
