/*******************************************************************************

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/


module ocean.stdc.posix.sys.un;

public import core.sys.posix.sys.un;

extern (C):

const UNIX_PATH_MAX = 108;

align(1)
struct sockaddr_un
{
        align(1):
        ushort sun_family;
        char[UNIX_PATH_MAX] sun_path;
}
