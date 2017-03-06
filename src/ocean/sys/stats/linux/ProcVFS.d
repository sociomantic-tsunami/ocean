/*******************************************************************************

    Contains API to obtain various information about the running application
    from /proc VFS.

    Copyright:
        Copyright (c) 2009-2017 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.stats.linux.ProcVFS;

import ocean.transition;
import Path = ocean.io.Path;
import ocean.sys.ErrnoException;
import core.sys.posix.stdio;
import core.stdc.errno;
import ocean.core.Traits;
import ocean.core.Tuple;
import ocean.io.device.File;
import ocean.text.Search;
import ocean.text.convert.Integer;
import ocean.core.Buffer;
import ocean.core.Enforce;
import core.stdc.stdlib;

version (UnitTest)
{
    import ocean.core.Test;
}

private
{
    // TODO: use druntime bindings when available
    extern (C) ssize_t getline (char** lineptr, size_t* n, FILE* stream);
}

/*******************************************************************************

    Reusable procvfs_exception instance.

*******************************************************************************/

private ErrnoException procvfs_exception;

/*******************************************************************************

    Buffer for processing files.

*******************************************************************************/

private Buffer!(char) procvfs_file_buf;

/***************************************************************************

    Gets the number of the fd open in a process.

    Note:
        In order to get the number of open files, this method iterates
        through the directory entires in /proc VFS. This implies that it should
        not be called multiple times a second, as there might be performance
        implications. Ideally, it's called every 30 seconds, or so, just
        to generate the stats.log as needed.

    Returns:
        number of the open file descriptors

***************************************************************************/

public int getOpenFdCount ()
{
    int count;

    foreach (c; Path.children("/proc/self/fdinfo"))
    {
        count++;
    }

    return count;
}

/*******************************************************************************

    Information reported by /proc/pid/stat file

    Information about individual fields can be found in `man 5 proc`:
    http://man7.org/linux/man-pages/man5/proc.5.html

*******************************************************************************/

struct ProcStat
{
    int pid;
    mstring cmd;
    char state;
    int ppid;
    int pgrp;
    int session;
    int tty_nr;
    int tpgid;
    uint flags;
    ulong minflt;
    ulong cminflt;
    ulong majflt;
    ulong cmajflt;
    ulong utime;
    ulong stime;
    long cutime;
    long cstime;
    long priority;
    long nice;
    long num_threads;
    long itrealvalue;
    ulong starttime;
    ulong vsize;
    ulong rss;
    ulong rsslim;
    ulong startcode;
    ulong endcode;
    ulong startstack;
    ulong kstkesp;
    ulong kstkeip;
    ulong signal;
    ulong blocked;
    ulong sigingore;
    ulong sigcatch;
    ulong wchan;
    ulong nswap;
    ulong cnswap;
    int exit_signal;
    int processor;
    uint rt_priority;
    uint policy;
    ulong delayacct_blkio_ticks;
    ulong guest_time;
    long cguest_time;
    ulong start_data;
    ulong end_data;
    ulong start_brk;
    ulong arg_start;
    ulong arg_end;
    ulong env_start;
    ulong env_end;
    int exit_code;
}


/*******************************************************************************

    Parses /proc/<pid>/stat and extracts the data.

    Params:
        path = path of the file to query

    Returns:
        filled ProcStat structure based on /proc/self/stat or empty
        ProcStat instance in case parsing has failed.

*******************************************************************************/

public ProcStat getProcStat (cstring path)
{
    ProcStat s;

    cstring space = " ";
    cstring parenth = ")";

    auto space_it = find(space);
    auto parenth_it = find(parenth);

    // Get the data from file
    scope file = new File(path);

    // stat(2) generally on the special files returns 0,
    // so we can't figure out in advance how much to allocate
    procvfs_file_buf.length = 8192; // Should be enough to cover maximum path of the
                            // executable stored in the file
    auto num_read = file.read(procvfs_file_buf[]);
    enforce(*procvfs_file_buf[num_read-1] == '\n');

    char[] data = procvfs_file_buf[0..num_read];

    // The /proc/self/stat file is based on the following format
    // (consult the man proc(5) page for details):
    // pid (<cmd>) C # # # # .... #
    // Where pid is a number, cmd is a file name, with arbitrary amount of
    // spaces, but always with parentheses,
    // C being the character describing the status of the program
    // and # being again numbers, for every of the entries in the ProcStat

    // consume pid
    auto pid_pos = space_it.forward(data);
    toInteger(data[0..pid_pos], s.pid);

    // chop pid
    data = data[pid_pos+1..$];

    // chop the left bracket from cmd name
    data = data[1 .. $];

    // Find the last closing bracket (as the process name can contain bracket
    // itself.
    auto last_bracket = parenth_it.reverse(data);
    s.cmd.length = last_bracket;
    s.cmd[] = data[0..last_bracket];

    // chop last bracket and space
    data = data[last_bracket+2..$];

    s.state = data[0];

    // chop status and the space
    data = data[2..$];

    foreach (i, ref field; s.tupleof)
    {
        static if (i > 2)
        {
            static assert (isIntegerType!(typeof(field)));
            auto next_space = space_it.forward(data);
            toInteger(data[0..next_space], field);

            // Last field doesn't have space after it
            if (next_space < data.length)
            {
                data = data[next_space+1..$];
            }
        }
    }

    return s;
}

/*******************************************************************************


    Parses /proc/self/stat and extracts the data.

    Returns:
        filled ProcStat structure based on /proc/self/stat or empty
        ProcStat instance in case parsing has failed.

*******************************************************************************/

public ProcStat getProcSelfStat ()
{
    return getProcStat("/proc/self/stat");
}

/*******************************************************************************

    Structure representing data found in /proc/uptime.

    Contains the uptime of the system and the amount of time spent in idle
    process, both in seconds.

*******************************************************************************/

public struct ProcUptime
{
    /***************************************************************************

        Helper struct containing whole and fractional part of the second.

    ***************************************************************************/

    public struct Time
    {
        import ocean.math.Math: abs;

        /// Whole part of seconds
        public long seconds;
        /// Fractional part of the second
        public long cents;

        /***********************************************************************

            Returns:
                Floating point representation of the Time struct

        ***********************************************************************/

        public double as_double ()
        {
            return seconds + cents / 100.0;
        }


        /***********************************************************************

            Params:
                rhs = Time value to subtract

            Returns:
                current time subtracted by rhs

        ***********************************************************************/

        Time opSub(Time rhs)
        {
            Time res_time;

            auto t = (this.seconds * 100 + this.cents) -
                (rhs.seconds * 100 + rhs.cents);

            res_time.seconds = t / 100;
            res_time.cents = abs(t) % 100;
    
            return res_time;
        }

        unittest
        {
            auto t1 = Time(2, 0);
            auto t2 = Time(1, 0);
            test!("==")(t1 - t2, Time(1, 0));

            t1 = Time(2, 0);
            t2 = Time(2, 0);
            test!("==")(t1 - t2, Time(0, 0));

            t1 = Time(1, 0);
            t2 = Time(2, 0);
            test!("==")(t1 - t2, Time(-1, 0));

            t1 = Time(2, 50);
            t2 = Time(2, 30);
            test!("==")(t1 - t2, Time(0, 20));

            t1 = Time(2, 30);
            t2 = Time(1, 50);
            test!("==")(t1 - t2, Time(0, 80));

            t1 = Time(2, 50);
            t2 = Time(1, 50);
            test!("==")(t1 - t2, Time(1, 0));

            t1 = Time(1, 30);
            t2 = Time(2, 50);
            test!("==")(t1 - t2, Time(-1, 20));

        }
    }

    /// Uptime time
    public Time uptime;

    /// Idle time
    public Time idle;
}

unittest
{
    auto t = ProcUptime.Time(1, 50);
    test!("==")(t.as_double(), 1.5);
    t.cents = 25;
    test!("==")(t.as_double(), 1.25);
    t.cents = 0;
    test!("==")(t.as_double, 1.0);
}

/*******************************************************************************

    Parses and returns data found in /proc/uptime.

    Returns:
        ProcUptime instance representing /proc/uptime

    Throws:
        ErrnoException on failure to parse this file.

*******************************************************************************/

public ProcUptime getProcUptime ()
{
    auto f = fopen("/proc/uptime".ptr, "r".ptr);

    if (!f)
    {
        throwException("fopen");
    }

    scope (exit) fclose(f);

    ProcUptime t;
    if (fscanf(f, "%lld.%lld %lld.%lld\n".ptr,
                &t.uptime.seconds,
                &t.uptime.cents,
                &t.idle.seconds,
                &t.idle.cents) != 4)
    {
        throwException("fscanf");
    }

    return t;
}

/*******************************************************************************

    Information reported by /proc/meminfo file

    Information about individual fields can be found in `man 5 proc`:
    http://man7.org/linux/man-pages/man5/proc.5.html

*******************************************************************************/

struct ProcMemInfo
{
    ulong MemTotal;
    ulong MemFree;
    ulong MemAvailable;
    ulong Buffers;
    ulong Cached;
    ulong SwapCached;
    ulong Active;
    ulong Inactive;
    ulong Unevictable;
    ulong Mlocked;
    ulong HighTotal;
    ulong HighFree;
    ulong LowTotal;
    ulong LowFree;
    ulong MmapCopy;
    ulong SwapTotal;
    ulong SwapFree;
    ulong Dirty;
    ulong Writeback;
    ulong AnonPages;
    ulong Mapped;
    ulong Shmem;
    ulong Slab;
    ulong SReclaimable;
    ulong SUnreclaim;
    ulong KernelStack;
    ulong PageTables;
    ulong QuickList;
    ulong NFS_Unstable;
    ulong Bounce;
    ulong WritebackTmp;
    ulong CommitLimit;
    ulong Committed_As;
    ulong VmallocTotal;
    ulong VmallocUsed;
    ulong VmallocChunk;
}

/*******************************************************************************

    Returns:
        Filled in ProcMemInfo structure

    Throws:
        ErrnoException on failure to parse this file.

*******************************************************************************/

public ProcMemInfo getProcMemInfo ()
{
    /***************************************************************************

        Buffer used for getline reading. Since getline may reallocate buffer,
        this must be heap allocate and managed with malloc/free.

    ***************************************************************************/

    static struct getline_buffer_t
    {
        /// Pointer to the buffer
        char* ptr;
        /// size of the buffer
        size_t length;
    }

    // Instance of the getline_buffer_t.
    static getline_buffer_t getline_buf;


    ProcMemInfo meminfo;

    ulong res;

    auto f = fopen("/proc/meminfo".ptr, "r".ptr);

    if (!f)
    {
        throwException("fopen");
    }

    scope (exit) fclose(f);

    cstring colon = ":";
    cstring space = " ";
    auto colon_it = find(colon);
    auto space_it = find(space);

    while (true)
    {
        ssize_t read = getline(&getline_buf.ptr, &getline_buf.length, f);

        if (read <= 0)
        {
            break;
        }

        // getline gets the last \n
        auto data = getline_buf.ptr[0 .. read - 1];

        // MemTotal:          32 kB
        auto colon_pos = colon_it.forward(data);
        auto field_name = data[0..colon_pos];

        // Swallow all spaces between colon and number
        data = data[colon_pos..$];
        enforce(data.length);

        while (data[0] == ' ')
        {
            data = data[1..$];
        }

        // Find separator between value and units
        auto space_pos = space_it.forward(data);
        auto field_value = data[0..space_pos];
        auto field_units = space_pos < data.length ?
            data[space_pos + 1 .. $] : "";

        /***********************************************************************

            Multiplies value by the power of two derived from units.

            Params:
                value = value to adjust
                units = units to take in acount

        ***********************************************************************/

        static void adjustUnits (ref ulong value, cstring units)
        {
            if (units.length == 0)
                return;

            switch (units[0])
            {
                case 'k':
                    value *= 1024;
                    break;
                case 'M':
                    value *= 1024 * 1024;
                    break;
                case 'G':
                    value *= 1024 * 1024 * 1024;
                    break;
                case 'T':
                    value *= 1024 * 1024 * 1024 * 1024;
                    break;
                default:
                    break;
            }
        }

        switch (field_name)
        {
            foreach (i, ref field; meminfo.tupleof)
            {
                case FieldName!(i, typeof(meminfo.init)):
                    // Using tupleof[i] instead of field
                    // as a workaround for
                    // https://issues.dlang.org/show_bug.cgi?id=16521
                    toInteger(field_value, meminfo.tupleof[i]);
                    adjustUnits(meminfo.tupleof[i], field_units);
                    break;
            }

            default:
                break;
        }
    }

    return meminfo;
}

/*******************************************************************************

    Returns:
        size of machine's RAM in bytes, as reported in /proc/meminfo

    Throws:
        ErrnoException on failure to parse this file.

*******************************************************************************/

public ulong getTotalMemoryInBytes ()
{
    return getProcMemInfo().MemTotal;
}

/*******************************************************************************

    Initializes .exception object if necessary and throws it, carrying the
    last errno.

    Params:
        name = name of the method that failed

*******************************************************************************/

private void throwException( istring name )
{
    auto saved_errno = .errno;

    if (.procvfs_exception is null)
    {
        .procvfs_exception = new ErrnoException();
    }

    throw .procvfs_exception.set(saved_errno, name);
}
