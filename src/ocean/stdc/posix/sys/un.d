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

import ocean.transition;

public import core.sys.posix.sys.un;
import core.sys.posix.sys.socket;

extern (C):

const UNIX_PATH_MAX = 108;

align(1)
struct sockaddr_un
{
        align(1):
        ushort sun_family;
        char[UNIX_PATH_MAX] sun_path;

        /***********************************************************************

            Creates the instance of sockaddr_un with the sun_path set
            and with the `sin_family` set to `AF_UNIX`.

            Params:
                path = path of the socket (can't be longer than 107 bytes)

        ***********************************************************************/

        public static sockaddr_un create (cstring path)
        in
        {
            assert(typeof(this).sun_path.length > path.length,
                    "Can't set path longer than UNIX_PATH_MAX.");
        }
        body
        {
            sockaddr_un addr;
            addr.sun_path[0..path.length] = path;
            addr.sun_path[path.length] = '\0';
            addr.sun_family = AF_UNIX;
            return addr;
        }
}
