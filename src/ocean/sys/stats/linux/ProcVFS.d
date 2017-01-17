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
