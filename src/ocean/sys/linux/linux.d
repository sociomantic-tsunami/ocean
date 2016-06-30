/*******************************************************************************

    Copyright:
        Copyright (c) 2004-2009 Tango contributors.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

*******************************************************************************/

module ocean.sys.linux.linux;


version (linux) {
    public import ocean.stdc.time;
    public import ocean.stdc.posix.dlfcn;
    public import ocean.stdc.posix.fcntl;
    public import ocean.stdc.posix.poll;
    public import ocean.stdc.posix.pwd;
    public import ocean.stdc.posix.time;
    public import ocean.stdc.posix.unistd;
    public import ocean.stdc.posix.sys.select;
    public import ocean.stdc.posix.sys.stat;
    public import ocean.stdc.posix.sys.types;
    public import ocean.sys.linux.epoll;
}
