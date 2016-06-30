/*******************************************************************************

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.linux.ifaddrs;

import ocean.stdc.posix.sys.socket;

version (linux)
{
    extern (C):

    struct ifaddrs
    {
        ifaddrs*         ifa_next;
        char*            ifa_name;
        uint      ifa_flags;
        sockaddr* ifa_addr;
        sockaddr* ifa_netmask;

        union
        {
            sockaddr* ifu_broadaddr;
            sockaddr* if_dstaddr;
        }

        void* ifa_data;
    };

    int getifaddrs(ifaddrs** );
    void freeifaddrs(ifaddrs* );
}

