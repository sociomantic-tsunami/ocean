/*******************************************************************************

    glibc socket functions.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

*******************************************************************************/

module ocean.stdc.posix.gnu.socket;

import core.sys.posix.sys.socket;

extern (C):

int accept4(int, sockaddr*, socklen_t*, int);
