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
import core.stdc.stdio;
import core.stdc.errno;
import ocean.core.Traits;
import ocean.core.Traits_tango;
import ocean.core.Tuple;
import ocean.io.device.File;
import ocean.text.Search;
import ocean.text.convert.Integer;
import ocean.core.Buffer;
import ocean.core.Enforce;

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
