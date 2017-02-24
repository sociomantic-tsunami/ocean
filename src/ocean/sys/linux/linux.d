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
    public import core.stdc.time;
    public import core.sys.posix.dlfcn;
    public import core.sys.posix.fcntl;
    public import core.sys.posix.poll;
    public import core.sys.posix.pwd;
    public import core.sys.posix.time;
    public import core.sys.posix.unistd;
    public import core.sys.posix.sys.select;
    public import core.sys.posix.sys.stat;
    public import core.sys.posix.sys.types;
    public import core.sys.linux.epoll;
}
