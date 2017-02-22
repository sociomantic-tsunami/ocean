/*******************************************************************************

    Internet address handling and conversion heper.

    Wraps a sockaddr_in or sockaddr_in6 struct instance together with the IP
    address network <-> presentation and port number network <-> host conversion
    functions.

    Aliases the following types and constants from <netinet/in.h>:

        Type                IPv4 name           IPv6 name           Alias name

        struct              sockaddr_in         sockaddr_in6        Addr
        const int           INET_ADDRSTRLEN     INET6_ADDRSTRLEN    addrstrlen
        const sa_family_t   AF_INET             AF_INET6            family

    Uses the following functions from <arpa/inet.h>:
        - inet_ntop, inet_pton (IP address network <-> presentation conversion),
        - htons, ntohs, htonl  (port number network <-> host conversion).

    For the whole misery see

    http://pubs.opengroup.org/onlinepubs/009604499/basedefs/netinet/in.h.html
    http://pubs.opengroup.org/onlinepubs/009604499/functions/inet_ntop.html
    http://pubs.opengroup.org/onlinepubs/009604499/functions/ntohs.html
    http://www.openisbn.com/isbn/0131411551/

    Important note: To reinitialise the address, use clear() (do not assign
                    .init).

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.socket.InetAddress;


/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.transition;

import ocean.stdc.posix.sys.socket: sockaddr;

import core.sys.posix.netinet.in_ :
           sockaddr_in,  AF_INET,  INET_ADDRSTRLEN,  INADDR_ANY,
           sockaddr_in6, AF_INET6, INET6_ADDRSTRLEN;

import core.sys.posix.netdb;

import core.sys.posix.arpa.inet: inet_ntop, inet_pton, ntohs, htons, htonl;

import core.stdc.string: strlen;

import core.stdc.errno: errno, EAFNOSUPPORT;

import ocean.core.TypeConvert;

/******************************************************************************

    Flags supported by getnameinfo().

 ******************************************************************************/

public enum GetNameInfoFlags : int
{
    None = 0,
    NI_NUMERICHOST              = 1 << 0, /// Don't try to look up hostname.
    NI_NUMERICSERV              = 1 << 1, /// Don't convert port number to name.
    NI_NOFQDN                   = 1 << 2, /// Only return nodename portion.
    NI_NAMEREQD                 = 1 << 3, /// Don't return numeric addresses.
    NI_DGRAM                    = 1 << 4, /// Look up UDP service rather than TCP.
    NI_IDN                      = 1 << 5, /// Convert name from IDN format.
    NI_IDN_ALLOW_UNASSIGNED     = 1 << 6, /// Don't reject unassigned Unicode code points.
    NI_IDN_USE_STD3_ASCII_RULES = 1 << 7  /// Validate strings according to STD3 rules.
}

/******************************************************************************/

struct InetAddress ( bool IPv6 = false )
{
    /**************************************************************************

        Constants and aliases.

            - Addr aliases the "sin" internet address struct type, sockaddr_in
              for IPv4 or sockaddr_in6 for IPv6, respectively.
            - addrstrlen is the maximum length of a presentation address string
              plus one (for the NUL-terminator).
            - family is the address family identifier.
            - addr_init is the initial value of an Addr instance with the family
              field set appropriately.

     **************************************************************************/

    static if (IPv6)
    {
        alias sockaddr_in6 Addr;

        const addrstrlen = INET6_ADDRSTRLEN,
              family     = AF_INET6;

        const Addr addr_init = {sin6_family: family};
    }
    else
    {
        alias sockaddr_in Addr;

        const addrstrlen = INET_ADDRSTRLEN,
              family     = AF_INET;

        const Addr addr_init = {sin_family: family};
    }

    /**************************************************************************

        Internet address struct instance.
        The address and port fields should be accessed by port() and
        inet_pton()/inet_ntop() unless they are copied from another instance.

     **************************************************************************/

    Addr addr = addr_init;

    /**************************************************************************

        Gets the port number from this.addr.

        Returns:
            the port number.

     **************************************************************************/

    ushort port ( )
    {
        static if (IPv6)
        {
            return .ntohs(this.addr.sin6_port);
        }
        else
        {
            return .ntohs(this.addr.sin_port);
        }
    }

    /**************************************************************************

        Sets the port field (sin_port/sin6_port) of this.addr to p.

        Params:
            p = port

        Returns:
            p.

     **************************************************************************/

    ushort port ( ushort p )
    {
        static if (IPv6)
        {
            this.addr.sin6_port = .htons(p);

        }
        else
        {
            this.addr.sin_port = .htons(p);
        }

        return p;
    }

    /**************************************************************************

        Sets the address field (sin_addr/sin6_addr) of this.addr to the address
        represented by the string in src. src is expected to contain a valid IP
        address.

        Params:
            ip_address_str = input IP address

        Returns:
            1 on success or 0 if src does not contain a valid IP address.

     **************************************************************************/

    int inet_pton ( cstring ip_address_str )
    {
        if (ip_address_str.length < this.addrstrlen)
        {
            char[this.addrstrlen] nultermbuf;

            nultermbuf[0 .. ip_address_str.length] = ip_address_str[];
            nultermbuf[ip_address_str.length]      = '\0';

            return this.inet_pton(nultermbuf.ptr);
        }
        else
        {
            return 0;
        }

    }

    /**************************************************************************

        Sets the address field (sin_addr/sin6_addr) of this.addr to the address
        in ip_address_str. ip_address_str is expected be a NUL-terminated
        string.

        Params:
            ip_address_str = input IP address string

        Returns:
            1 on success or 0 if src does not contain a valid IP address.

        (Note: The inet_pton() specs say it can return -1 with
        errno = EAFNOSUPPORT; this is not possible unless there is a bug in this
        struct template ;)

     **************************************************************************/

    int inet_pton ( in char* ip_address_str )
    {
        return .inet_pton(this.family, ip_address_str, this.address_n.ptr);
    }

    /**************************************************************************

        Sets this.addr to the wildcard "any" IP address.

        Returns:


     **************************************************************************/

    sockaddr* setAddressAny ( )
    {
        static if (IPv6)
        {
            this.addr.sin6_addr = this.addr.sin6_addr.init;
        }
        else
        {
            this.addr.sin_addr.s_addr = htonl(INADDR_ANY);
        }

        return cast (sockaddr*) &this.addr;
    }

    /**************************************************************************

        Renders the current address of this.addr as an IP address string,
        writing to dst. dst.length is expected to be at least this.addstrlength.

        Params:
            dst = destination string buffer

        Returns:
            a slice to valid data in dst on success or null on failure.

        Errors:
            ENOSPC - dst is too short.

        (Note: The inet_ntop() specs say it can fail with errno = EAFNOSUPPORT;
        this is not possible unless there is a bug in this struct template ;)

     **************************************************************************/

    mstring inet_ntop ( mstring dst )
    in
    {
        assert (dst.length >= this.addrstrlen,
                "dst.length expected to be at least addrstrlen");
    }
    body
    {
        auto address_p = .inet_ntop(this.family, this.address_n.ptr, dst.ptr,
            castFrom!(size_t).to!(int)(dst.length));

        return address_p? dst.ptr[0 .. strlen(dst.ptr)] : null;
    }

    /**************************************************************************

        Sets this.addr to the IP address in ip_address_str and the port to port.

        Params:
            ip_address_str = IP address string
            port           = port

        Returns:
            a sockaddr pointer to this.addr on success.
            If ip_address_str does not contain a valid IP address, null is
            returned and errno set to EAFNOSUPPORT (this error is reported by
            this wrapper, not the underlying system function).

     **************************************************************************/

    public sockaddr* opCall ( cstring ip_address_str, ushort port = 0 )
    {
        this.port = port;

        if (this.inet_pton(ip_address_str) == 1)
        {
            return cast (sockaddr*) &this.addr;
        }
        else
        {
            .errno = EAFNOSUPPORT;
            return null;
        }
    }

    /**************************************************************************

        Sets this.addr to the wildcard "any" IP address and the port to port.

        Params:
            port = input port

        Returns:
            a sockaddr pointer to this.addr.

     **************************************************************************/

    public sockaddr* opCall ( ushort port )
    {
        this.port = port;

        return this.setAddressAny();
    }

    /**************************************************************************

        Copies addr to this.addr.

        Params:
            addr = input address

        Returns:
            a sockaddr pointer to this.addr.

     **************************************************************************/

    public sockaddr* opAssign ( Addr addr )
    {
        this.addr = addr;

        return cast (sockaddr*) &this.addr;
    }

    /**************************************************************************

        Copies *addr to this.addr.

        Params:
            addr = input address

        Returns:
            a sockaddr pointer to this.addr.

        In:
            addr must not be null.

     **************************************************************************/

    public sockaddr* opAssign ( Addr* addr )
    in
    {
        assert (addr !is null);
    }
    body
    {
        this.addr = *addr;

        return cast (sockaddr*) &this.addr;
    }

    /**************************************************************************

        Clears this.addr.

     **************************************************************************/

    public void clear ( )
    {
        this.addr = this.addr_init;
    }

    /**************************************************************************

        Obtains a slice to the binary address in from this.addr, that is,
        for IPv4 the sin_addr or for IPv6 the sin6_addr field, respectively.

        Returns:
            a slice to the binary address data from this.addr.

     **************************************************************************/

    public void[] address_n ( )
    {
        with (this.addr) static if (IPv6)
        {
            return (cast (void*) &sin6_addr)[0 .. sin6_addr.sizeof];
        }
        else
        {
            return (cast (void*) &sin_addr)[0 .. sin_addr.sizeof];
        }
    }

    // TODO

    public int getnameinfo(mstring host, mstring serv,
                           GetNameInfoFlags flags = GetNameInfoFlags.None)
    {
        return core.sys.posix.netdb.getnameinfo(
            cast (sockaddr*) &this.addr, this.addr.sizeof,
            host.ptr, castFrom!(size_t).to!(int)(host.length), serv.ptr,
            castFrom!(size_t).to!(int)(serv.length), flags);
    }
}
