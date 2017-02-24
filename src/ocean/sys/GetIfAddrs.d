/*******************************************************************************

    Functions to get IP address from the given interface.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.GetIfAddrs;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.stdc.errno;
import ocean.stdc.string;
import ocean.stdc.posix.arpa.inet;
import ocean.stdc.posix.netinet.in_: sockaddr_in, sockaddr_in6;
import ocean.stdc.posix.sys.socket;
import core.sys.linux.ifaddrs;
import ocean.sys.linux.consts.socket: AF_INET, AF_INET6;

import ocean.core.Test;
import ocean.core.TypeConvert;
import ocean.sys.ErrnoException;
import ocean.text.util.StringC;

debug import ocean.io.Stdout_tango;


/*******************************************************************************

    Exception type to be thrown when fetching the IP address(es) for the
    interface fails.

*******************************************************************************/

class ResolveIPException : ErrnoException
{
}

/*******************************************************************************

    Returns IP addresses for the network interface.

    Params:
        interface_name = Name of the interface (e.g. eth0)
        ipv6 = true: fetch IPv6 addresses, false: IPv4

    Returns:
        IP addresses of the interface for the given family as strings,
        if they could be resolved, otherwise an empty array.

*******************************************************************************/

istring[] getAddrsForInterface( cstring interface_name, bool ipv6 = false )
{
    istring[] addresses;
    bool delegate_called = false;

    auto ret = getAddrsForInterface(interface_name, ipv6,
        (cstring address, int getnameinfo_status)
        {
            delegate_called = true;

            if (getnameinfo_status != 0)
            {
                throw (new ResolveIPException).set(getnameinfo_status,
                                                   "getnameinfo failed");
            }

            if (address.length)
            {
                addresses ~= idup(address);
            }

            return false;
        });

    if (ret && !delegate_called)
    {
        throw (new ResolveIPException).useGlobalErrno("getifaddrs");
    }

    return addresses;
}


/*******************************************************************************

    Iterates over IP addresses for the network interface.

    Obtains the network address of the local system from getifaddrs() and calls
    dg with a host and service name string for each of these addresses. If host
    and service name string formatting failed for an address, dg is called with
    a null address and the status code of the conversion function,
    getnameinfo(). See the manpage of getnameinfo() for its status codes.

    dg should return false to continue or true to stop iteration.

    If dg isn't called and return value is true, getifaddrs() has failed;
    in this case check errno and see the getnameinfo() manpage.

    Params:
        interface_name = Name of the interface (e.g. eth0)
        ipv6 = true: fetch IPv6 addresses, false: IPv4
        dg = iteration delegate

    Returns:
        true if either dg returned true to stop the iteration or getifaddrs()
        failed or false if the iteration finished normally.

*******************************************************************************/

bool getAddrsForInterface( cstring interface_name, bool ipv6,
                           bool delegate ( cstring address,
                                           int    getnameinfo_status ) dg )
{
    ifaddrs* ifaddr;

    // Try to fetch a linked list of interfaces and their adresses
    if (getifaddrs(&ifaddr) == -1)
    {
        return true;
    }

    // ifaddr is allocated, and it needs to be freed!
    scope(exit) freeifaddrs(ifaddr);

    auto salen  = ipv6? sockaddr_in6.sizeof : sockaddr_in.sizeof,
         family = ipv6? AF_INET6 : AF_INET;

    // Iterate through each interface and check if the interface
    // is the one that we're looking for.

    for (auto ifa = ifaddr; ifa !is null; ifa = ifa.ifa_next)
    {
        /***********************************************************************

            From the `getifaddrs` man page:
            The ifa_addr field points to a structure containing the
            interface address. (The sa_family subfield should be consulted
            to determine the format of the address structure.) This field
            may contain a null pointer.

        ***********************************************************************/

        if(!ifa.ifa_addr)
        {
            continue;
        }

        if (interface_name != StringC.toDString(ifa.ifa_name))
        {
            continue;
        }

        if (ifa.ifa_addr.sa_family != family)
        {
            continue;
        }

        char[NI_MAXHOST] buffer;

        // Use getnameinfo to get the interface address

        auto result = getnameinfo(ifa.ifa_addr,
                                   castFrom!(size_t).to!(uint)(salen),
                                   buffer.ptr,
                                   buffer.length,
                                   null,
                                   0,
                                   NI_NUMERICHOST);

        // Check the result code and invoke the iteration delegate
        if (dg(result? null : StringC.toDString(buffer.ptr), result))
        {
            return true;
        }
    }

    return false;
}
