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
import core.sys.posix.sys.resource;
import ProcVFS = ocean.sys.stats.linux.ProcVFS;
import ocean.sys.stats.linux.Queriable;

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
