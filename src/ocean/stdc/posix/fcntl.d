/*******************************************************************************

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/


module ocean.stdc.posix.fcntl;

public import core.sys.posix.fcntl;

import core.sys.posix.config;

enum { O_NOFOLLOW = 0x20000 } // 0400000
enum { O_DIRECT  = 0x4000 }

enum { POSIX_FADV_NORMAL = 0 }
enum { POSIX_FADV_RANDOM = 1 }
enum { POSIX_FADV_SEQUENTIAL = 2 }
enum { POSIX_FADV_WILLNEED = 3 }
enum { POSIX_FADV_DONTNEED = 4 }
enum { POSIX_FADV_NOREUSE = 5 }

static if( __USE_LARGEFILE64 )
{
    enum { O_LARGEFILE = 0x8000 }
    enum { F_GETLK = 12 }
    enum { F_SETLK = 13 }
    enum { F_SETLKW = 14 }
}
else
{
    enum { O_LARGEFILE = 0 }
    enum { F_GETLK = 5  }
    enum { F_SETLK = 6  }
    enum { F_SETLKW = 7 }
}
