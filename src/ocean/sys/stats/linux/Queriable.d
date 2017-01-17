/*******************************************************************************

    Contains API to obtain various information about the running application
    which are available through system APIs.

    Copyright:
        Copyright (c) 2009-2017 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.stats.linux.Queriable;

import ocean.transition;
import ocean.sys.ErrnoException;
import core.sys.posix.sys.resource;
import core.stdc.errno;

/*******************************************************************************

    Reusable exception instance.

*******************************************************************************/

private ErrnoException exception;

/*******************************************************************************

    Gets maximum core size allowed for the process to generate.

    Returns:
        maximum core size allowed for the process to generate.

    Throws:
        Reusable ErrnoException instance on error.

*******************************************************************************/

public rlimit maximumProcessCoreSize ()
{
    return getLimit(RLIMIT_CORE);
}

/*******************************************************************************

    Gets maximum CPU time in seconds process is allowed to use.

    Returns:
        maximum CPU time in seconds the process is allowed to use.

    Throws:
        Reusable ErrnoException instance on error.

*******************************************************************************/

public rlimit maximumProcessCPUTime ()
{
    return getLimit(RLIMIT_CPU);
}

/*******************************************************************************

    Gets maximum allowed stack size for the process.

    Returns:
        maximum allowed stack size.

    Throws:
        Reusable ErrnoException instance on error.

*******************************************************************************/

public rlimit maximumProcessStackSize ()
{
    return getLimit(RLIMIT_STACK);
}

/*******************************************************************************

    Gets maximum allowed data segment size for the process.

    Returns:
        maximum data segment size for the process

    Throws:
        Reusable ErrnoException instance on error.

*******************************************************************************/

public rlimit maximumProcessDataSize ()
{
    return getLimit(RLIMIT_DATA);
}

/*******************************************************************************

    Gets maximum file size allowed for the process to create

    Returns:
        maximum file size allowed for the process to create

    Throws:
        Reusable ErrnoException instance on error.

*******************************************************************************/

public rlimit maximumProcessFileSize ()
{
    return getLimit(RLIMIT_FSIZE);
}

/*******************************************************************************

    Gets maximum file descriptors allowed for the process to have open

    Returns:
        maximum file descriptors allowed for the process to have open

    Throws:
        Reusable ErrnoException instance on error.

*******************************************************************************/

public rlimit maximumProcessNumFiles ()
{
    return getLimit(RLIMIT_NOFILE);
}

/*******************************************************************************

    Gets maximum amount of address space allowed for the process to allocate.

    Returns:
        maximum amount of address space allowed for the process to allocate.

    Throws:
        Reusable ErrnoException instance on error.

*******************************************************************************/

public rlimit maximumProcessAddressSpace ()
{
    return getLimit(RLIMIT_AS);
}

/*******************************************************************************

    Wrapper around getrlimit, checking the return code and
    throwing an exception if failed.

    Params:
        limit_type = limit to query

    Returns:
        rlimit struct describing soft and hard limit

    Throws:
        Reusable ErrnoException if failed.

*******************************************************************************/

private rlimit getLimit (int limit_type)
{
    rlimit ret;

    if (getrlimit(limit_type, &ret) == -1)
    {
        auto saved_errno = .errno;

        if (.exception is null)
        {
            .exception = new ErrnoException();
        }

        throw .exception.set(saved_errno, "getrlimit");
    }

    return ret;
}
