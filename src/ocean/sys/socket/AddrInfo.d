/*******************************************************************************

    Declaration of and wrappers for the addrinfo address lookup API.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.socket.AddrInfo;

/*******************************************************************************

    Imports.

*******************************************************************************/

import ocean.transition;

import ocean.stdc.posix.netinet.in_: sockaddr, socklen_t,
                                     sockaddr_in,  AF_INET,  INET_ADDRSTRLEN,
                                     sockaddr_in6, AF_INET6, INET6_ADDRSTRLEN,
                                     SOCK_STREAM, IPPROTO_TCP;

import ocean.stdc.posix.arpa.inet: inet_ntop, inet_pton, ntohs, htons, htonl;

import core.stdc.errno: errno, EAFNOSUPPORT;

import core.stdc.string: strlen;

import ocean.core.Array: concat;

import ocean.core.TypeConvert;

/*******************************************************************************

    Address information struct as returned by getaddrinfo().

*******************************************************************************/

struct addrinfo
{
    /***************************************************************************

        getaddrinfo() flags.

    ***************************************************************************/

    enum Flags
    {
        None = 0,
        AI_PASSIVE                  = 1 << 0, /// Socket address is intended for `bind`.
        AI_CANONNAME                = 1 << 1, /// Request for canonical name.
        AI_NUMERICHOST              = 1 << 2, /// Don't use name resolution.
        AI_V4MAPPED                 = 1 << 3, /// IPv4 mapped addresses are acceptable.
        AI_ALL                      = 1 << 4, /// Return IPv4 mapped and IPv6 addresses.
        AI_ADDRCONFIG               = 1 << 5, /// Use configuration of this host to choose returned address type.
        AI_IDN                      = 1 << 6, /// IDN encode input (assuming it is encoded in the current locale's character set) before looking it up.
        AI_CANONIDN                 = 1 << 7, /// Translate canonical name from IDN format.
        AI_IDN_ALLOW_UNASSIGNED     = 1 << 8, /// Don't reject unassigned Unicode code points.
        AI_IDN_USE_STD3_ASCII_RULES = 1 << 9  /// Validate strings according to STD3 rules.

    }

    /***************************************************************************

        Error codes returned by getaddrinfo() (not passed via errno).

    ***************************************************************************/

    enum ErrorCode
    {
        Success = 0,
        EAI_BADFLAGS    = -1,     /// Invalid value for ai_flags field.
        EAI_NONAME      = -2,     /// NAME or SERVICE is unknown.
        EAI_AGAIN       = -3,     /// Temporary failure in name resolution.
        EAI_FAIL        = -4,     /// Non-recoverable failure in name res.
        EAI_FAMILY      = -6,     /// `ai_family` not supported.
        EAI_SOCKTYPE    = -7,     /// `ai_socktype` not supported.
        EAI_SERVICE     = -8,     /// SERVICE not supported for `ai_socktype`.
        EAI_MEMORY      = -10,    /// Memory allocation failure.
        EAI_SYSTEM      = -11,    /// System error returned in `errno`.
        EAI_OVERFLOW    = -12,    /// Argument buffer overflow.
        EAI_NODATA      = -5,     /// No address associated with NAME.
        EAI_ADDRFAMILY  = -9,     /// Address family for NAME not supported.
        EAI_INPROGRESS  = -100,   /// Processing request in progress.
        EAI_CANCELED    = -101,   /// Request canceled.
        EAI_NOTCANCELED = -102,   /// Request not canceled.
        EAI_ALLDONE     = -103,   /// All requests done.
        EAI_INTR        = -104,   /// Interrupted by a signal.
        EAI_IDN_ENCODE  = -105,   /// IDN encoding failed.
    }

    /***************************************************************************

        Data fields.

    ***************************************************************************/

    Flags           ai_flags;
    int             ai_family,
                    ai_socktype,
                    ai_protocol;
    socklen_t       ai_addrlen;               // The manpage says size_t: WRONG!
    sockaddr*       ai_addr;
    char*           ai_canonname;
    typeof (this)   ai_next;

    alias .INET6_ADDRSTRLEN INET6_ADDRSTRLEN;
    alias .INET_ADDRSTRLEN  INET_ADDRSTRLEN;

    /***************************************************************************

        Obtains the current IP address in standard notation.

        Params:
            dst = destination buffer

        Returns:
            a slice to the resulting IP address string in dst on success or null
            on error. On error errno is set appropriately.

        Errors:
            EAFNOSUPPORT: The address family is not supported (AF_INET/IPv4 or
                          AF_INET6/IPv6).

        In:
            - this.ai_addr must not be null: this instance should have been
              obtained by getaddrinfo() or manually initialised.
            - dst.length must be at least the required address length for the
              address family, INET_ADDRSTRLEN for IPv4 or INET6_ADDRSTRLEN for
              IPv6.

        Out:
            If the resulting slice is not null, it slices dst from the
            beginning.

    ***************************************************************************/

    mstring ipAddress ( mstring dst )
    in
    {
        assert (this.ai_addr !is null);

        switch (this.ai_family)
        {
            case AF_INET:
                assert (dst.length >= INET_ADDRSTRLEN,
                        "dst.length expected to be at least " ~ INET_ADDRSTRLEN.stringof);
                break;

            case AF_INET6:
                assert (dst.length >= INET6_ADDRSTRLEN,
                        "dst.length expected to be at least " ~ INET6_ADDRSTRLEN.stringof);

            default: // will fail with EAFNOSUPPORT anyway
        }
    }
    out (result)
    {
        if (result.length) assert (result.ptr is dst.ptr);
    }
    body
    {
        void* addr;

        switch (this.ai_family)
        {
            case AF_INET:
                addr = &(*cast (sockaddr_in*) this.ai_addr).sin_addr;
                break;

            case AF_INET6:
                addr = &(*cast (sockaddr_in6*) this.ai_addr).sin6_addr;
                break;

            default:
                .errno = EAFNOSUPPORT; // inet_ntop() would do the same
                return null;
        }

        auto address_p = .inet_ntop(this.ai_family, addr, dst.ptr,
            castFrom!(size_t).to!(int)(dst.length));
        // inet_ntop returns const pointer even if spec says it will always
        // use `dst` memory. Using `dst` directly to avoid casts.
        return address_p ? dst.ptr[0 .. strlen(dst.ptr)] : null;
    }

    /**************************************************************************

        Obtains the current port number.

        Returns:
            the current port number.

        Errors:
            EAFNOSUPPORT: The address family is not supported (AF_INET/IPv4 or
                          AF_INET6/IPv6).

        In:
            this.ai_addr must not be null: this instance should have been
            obtained by getaddrinfo() or manually initialised.

     **************************************************************************/

    ushort port ( )
    in
    {
        assert (this.ai_addr !is null);
    }
    body
    {
        .errno = 0;

        switch (this.ai_family)
        {
            case AF_INET:
                return .ntohs((cast (sockaddr_in*) this.ai_addr).sin_port);

            case AF_INET6:
                return .ntohs((cast (sockaddr_in6*) this.ai_addr).sin6_port);

            default:
                .errno = EAFNOSUPPORT;
                return 0;
        }
    }

    /**************************************************************************

        Obtains the current canonical name.

        Returns:
            the current canonical name or null.

     **************************************************************************/

    char[] canonname ( )
    {
        return this.ai_canonname? this.ai_canonname[0 .. strlen(this.ai_canonname)] : null;
    }

    /**************************************************************************

        'foreach' iteration over the linked list of instances of this struct;
        starting with this instance.

        Do not change any of the pointer struct members.

     **************************************************************************/

    int opApply ( int delegate ( ref typeof (*this) info ) dg )
    {
        int result = 0;

        for (typeof (this) info = this; info && !result; info = info.ai_next)
        {
            result = dg(*info);
        }

        return result;
    }
}

extern (C)
{
    /**************************************************************************

        Obtains the error message for errcode.

        Params:
            errcode = error code returned by getaddrinfo()

        Returns:
            the error message for errcode.

     **************************************************************************/

    public char* gai_strerror(addrinfo.ErrorCode errcode);

    /**************************************************************************

        Given node and service, which identify an Internet host and  a  service,
        getaddrinfo()  returns  one  or  more addrinfo structures, each of which
        contains an Internet address that can be specified in a call to  bind(2)
        or  connect(2).   The  getaddrinfo() function combines the functionality
        provided by the getservbyname(3) and getservbyport(3) functions  into  a
        single  interface,  but  unlike  the  latter functions, getaddrinfo() is
        reentrant and allows programs to  eliminate  IPv4-versus-IPv6  dependen‐
        cies.

        The  addrinfo  structure  used  by  getaddrinfo() contains the following
        fields:

            struct addrinfo {
                int              ai_flags;
                int              ai_family;
                int              ai_socktype;
                int              ai_protocol;
                size_t           ai_addrlen;
                struct sockaddr *ai_addr;
                char            *ai_canonname;
                struct addrinfo *ai_next;
            };

        The hints argument points to an addrinfo structure that specifies crite‐
        ria  for  selecting  the  socket address structures returned in the list
        pointed to by res.  If hints is not NULL it points to an addrinfo struc‐
        ture whose ai_family, ai_socktype, and ai_protocol specify criteria that
        limit the set of socket addresses returned by getaddrinfo(), as follows:

        ai_family   This field specifies the  desired  address  family  for  the
                    returned  addresses.   Valid  values  for this field include
                    AF_INET and AF_INET6.  The value  AF_UNSPEC  indicates  that
                    getaddrinfo() should return socket addresses for any address
                    family (either IPv4 or IPv6, for example) that can  be  used
                    with node and service.

        ai_socktype This  field specifies the preferred socket type, for example
                    SOCK_STREAM or SOCK_DGRAM.  Specifying 0 in this field indi‐
                    cates  that  socket addresses of any type can be returned by
                    getaddrinfo().

        ai_protocol This field specifies the protocol for  the  returned  socket
                    addresses.  Specifying 0 in this field indicates that socket
                    addresses with  any  protocol  can  be  returned  by  getad‐
                    drinfo().

        ai_flags    This  field  specifies  additional options, described below.
                    Multiple  flags  are  specified  by  bitwise   OR-ing   them
                    together.

        All  the  other fields in the structure pointed to by hints must contain
        either 0 or a null pointer, as appropriate.  Specifying hints as NULL is
        equivalent  to  setting  ai_socktype  and ai_protocol to 0; ai_family to
        AF_UNSPEC; and ai_flags to (AI_V4MAPPED | AI_ADDRCONFIG).

        node specifies either a numerical network address  (for  IPv4,  numbers-
        and-dots  notation  as  supported by inet_aton(3); for IPv6, hexadecimal
        string format as supported by  inet_pton(3)),  or  a  network  hostname,
        contains the AI_NUMERICHOST flag then node must be a  numerical  network
        address.   The  AI_NUMERICHOST  flag  suppresses any potentially lengthy
        network host address lookups.

        If the AI_PASSIVE flag is specified in hints.ai_flags, and node is NULL,
        then  the  returned  socket  addresses will be suitable for bind(2)ing a
        socket that will accept(2) connections.   The  returned  socket  address
        will  contain  the  "wildcard  address"  (INADDR_ANY for IPv4 addresses,
        IN6ADDR_ANY_INIT for IPv6 address).  The wildcard  address  is  used  by
        applications  (typically  servers)  that intend to accept connections on
        any of the hosts's network addresses.  If node is  not  NULL,  then  the
        AI_PASSIVE flag is ignored.

        If  the  AI_PASSIVE flag is not set in hints.ai_flags, then the returned
        socket addresses will be suitable for use with connect(2), sendto(2), or
        sendmsg(2).   If  node  is NULL, then the network address will be set to
        the loopback interface  address  (INADDR_LOOPBACK  for  IPv4  addresses,
        IN6ADDR_LOOPBACK_INIT  for  IPv6  address); this is used by applications
        that intend to communicate with peers running on the same host.

        service sets the port in each returned address structure.  If this argu‐
        ment is a service name (see services(5)), it is translated to the corre‐
        sponding port number.  This argument can also be specified as a  decimal
        number,  which  is simply converted to binary.  If service is NULL, then
        the port number of the returned socket addresses will be left uninitial‐
        ized.   If  AI_NUMERICSERV is specified in hints.ai_flags and service is
        not NULL, then service must point to a string containing a numeric  port
        number.   This  flag is used to inhibit the invocation of a name resolu‐
        tion service in cases where it is known not to be required.

        Either node or service, but not both, may be NULL.

        The getaddrinfo() function allocates and initializes a  linked  list  of
        addrinfo  structures, one for each network address that matches node and
        service, subject to any restrictions imposed by  hints,  and  returns  a
        pointer  to  the start of the list in res.  The items in the linked list
        are linked by the ai_next field.

        There are several reasons why the linked list may  have  more  than  one
        addrinfo  structure, including: the network host is multihomed, accessi‐
        ble over multiple protocols (e.g. both AF_INET  and  AF_INET6);  or  the
        same  service  is  available from multiple socket types (one SOCK_STREAM
        address and another SOCK_DGRAM address,  for  example).   Normally,  the
        application  should  try  using the addresses in the order in which they
        are returned.  The sorting function used within getaddrinfo() is defined
        in RFC 3484; the order can be tweaked for a particular system by editing
        /etc/gai.conf (available since glibc 2.5).

        If hints.ai_flags includes the AI_CANONNAME flag, then the  ai_canonname
        field  of  the  first of the addrinfo structures in the returned list is
        set to point to the official name of the host.

        The remaining fields of each returned addrinfo structure are initialized
        as follows:

        * The  ai_family,  ai_socktype, and ai_protocol fields return the socket
          creation parameters (i.e., these fields have the same meaning  as  the
          corresponding  arguments  of socket(2)).  For example, ai_family might
          return AF_INET or AF_INET6; ai_socktype  might  return  SOCK_DGRAM  or
          SOCK_STREAM; and ai_protocol returns the protocol for the socket.

        * A  pointer  to  the socket address is placed in the ai_addr field, and
          the length  of  the  socket  address,  in  bytes,  is  placed  in  the
          ai_addrlen field.

        If  hints.ai_flags  includes the AI_ADDRCONFIG flag, then IPv4 addresses
        are returned in the list pointed to by res only if the local system  has
        at  least  one  IPv4  address  configured,  and  IPv6 addresses are only
        returned if the local system has at least one IPv6 address configured.

        If hint.ai_flags specifies the AI_V4MAPPED flag, and hints.ai_family was
        specified  as  AF_INET6,  and no matching IPv6 addresses could be found,
        then return IPv4-mapped IPv6 addresses in the list pointed  to  by  res.
        If  both  AI_V4MAPPED  and  AI_ALL are specified in hints.ai_flags, then
        return both IPv6 and IPv4-mapped IPv6 addresses in the list  pointed  to
        by res.  AI_ALL is ignored if AI_V4MAPPED is not also specified.

        The  freeaddrinfo() function frees the memory that was allocated for the
        dynamically allocated linked list res.

        Extensions to getaddrinfo() for Internationalized Domain Names
        Starting with glibc 2.3.4, getaddrinfo() has  been  extended  to  selec‐
        tively  allow  the  incoming  and outgoing hostnames to be transparently
        converted to and from the Internationalized  Domain  Name  (IDN)  format
        (see  RFC 3490, Internationalizing Domain Names in Applications (IDNA)).
        Four new flags are defined:

        AI_IDN If this flag is specified, then the node name given  in  node  is
               converted  to  IDN  format  if necessary.  The source encoding is
               that of the current locale.

               If the input name contains non-ASCII  characters,  then  the  IDN
               encoding  is  used.   Those  parts of the node name (delimited by
               dots) that contain non-ASCII characters are encoded  using  ASCII
               Compatible Encoding (ACE) before being passed to the name resolu‐
               tion functions.

        AI_CANONIDN
               After a successful name lookup, and if the AI_CANONNAME flag  was
               specified,  getaddrinfo()  will  return the canonical name of the
               node corresponding to the addrinfo structure value  passed  back.
               The  return  value  is an exact copy of the value returned by the
               name resolution function.

               If the name is encoded using ACE, then it will contain  the  xn--
               prefix  for one or more components of the name.  To convert these
               components into a readable  form  the  AI_CANONIDN  flag  can  be
               passed  in  addition  to  AI_CANONNAME.   The resulting string is
               encoded using the current locale's encoding.

        AI_IDN_ALLOW_UNASSIGNED, AI_IDN_USE_STD3_ASCII_RULES
               Setting these flags will enable the IDNA_ALLOW_UNASSIGNED  (allow
               unassigned  Unicode  code  points)  and IDNA_USE_STD3_ASCII_RULES
               (check output to make sure it  is  a  STD3  conforming  hostname)
               flags respectively to be used in the IDNA handling.


        getaddrinfo()  returns 0 if it succeeds, or one of the following nonzero
        error codes:

        EAI_ADDRFAMILY
               The specified network host does not have any network addresses in
               the requested address family.

        EAI_AGAIN
               The  name  server  returned  a temporary failure indication.  Try
               again later.

        EAI_BADFLAGS
               hints.ai_flags  contains  invalid   flags;   or,   hints.ai_flags
               included AI_CANONNAME and name was NULL.

        EAI_FAIL
               The name server returned a permanent failure indication.

        EAI_FAMILY
               The requested address family is not supported.

        EAI_MEMORY
               Out of memory.

        EAI_NODATA
               The  specified network host exists, but does not have any network
               addresses defined.

        EAI_NONAME
               The node or service is not known; or both node  and  service  are
               NULL;  or AI_NUMERICSERV was specified in hints.ai_flags and ser‐
               vice was not a numeric port-number string.

        EAI_SERVICE
               The requested service is not available for the  requested  socket
               type.   It  may  be  available  through another socket type.  For
               example, this error could occur if service was "shell" (a service
               only  available  on stream sockets), and either hints.ai_protocol
               was IPPROTO_UDP, or  hints.ai_socktype  was  SOCK_DGRAM;  or  the
               error  could occur if service was not NULL, and hints.ai_socktype
               was SOCK_RAW (a socket type that does not support the concept  of
               services).

        EAI_SOCKTYPE
               The  requested  socket  type is not supported.  This could occur,
               for  example,  if  hints.ai_socktype  and  hints.ai_protocol  are
               inconsistent (e.g., SOCK_DGRAM and IPPROTO_TCP, respectively).

        EAI_SYSTEM
               Other system error, check errno for details.

        The  gai_strerror()  function  translates  these  error codes to a human
        readable string, suitable for error reporting.

     **************************************************************************/

    private addrinfo.ErrorCode getaddrinfo(char* node, char* service,
                                           addrinfo* hints, addrinfo** res);

    private void freeaddrinfo(addrinfo* res);

}

/******************************************************************************

    Wraps getaddrinfo()/freeaddrinfo() and manages an addrinfo instance.

 ******************************************************************************/

class AddrInfo : AddrInfoC
{
    /**************************************************************************

        String nul-termination buffers.

     **************************************************************************/

    private char[] node, service;


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Disposer.

        ***********************************************************************/

        protected override void dispose ( )
        {
            if (this.node)      delete this.node;
            if (this.service)   delete this.service;
        }
    }

    /**************************************************************************

        Returns:
            the current address info as most recently obtained.

     **************************************************************************/

    public override addrinfo* info ( )
    {
        return this.info_;
    }

    /**************************************************************************

        Gets the address info for a TCP/IP node and/or service.

        Params:
            node    = node name (may be null)
            service = service name (may be null)
            ipv6    = false: get the IPv4, true: get the IPv6 address
            flags   = getaddrinfo() flags

        Returns:
            0 on success or an error code on failure, see addrinfo.ErrorCode.

     **************************************************************************/

    public ErrorCode getTcpIp ( char[] node, char[] service, bool ipv6,
                                addrinfo.Flags flags = addrinfo.Flags.None )
    {
        return super.getTcpIp(this.node.toCstr(node),
                              this.service.toCstr(service), ipv6, flags);
    }

    /**************************************************************************

        Gets the address info for an IP node and/or service.

        Params:
            node     = node name (may be null)
            service  = service name (may be null)
            ipv6     = false: get the IPv4, true: get the IPv6 address
            type     = socket type (0 for any type)
            protocol = socket protocol (0 for any protocol)
            flags    = getaddrinfo() flags

        Returns:
            0 on success or an error code on failure, see addrinfo.ErrorCode.

     **************************************************************************/

    public ErrorCode getIp ( char[] node, char[] service,
                             bool ipv6, int type, int protocol,
                             addrinfo.Flags flags = addrinfo.Flags.None )
    {
        return super.getIp(this.node.toCstr(node), this.service.toCstr(service),
                           ipv6, type, protocol, flags);
    }

    /**************************************************************************

        Gets the address info for a node and/or service.

        Params:
            node     = node name (may be null)
            service  = service name (may be null)
            family   = socket family (0 for any family)
            type     = socket type (0 for any type)
            protocol = socket protocol (0 for any protocol)
            flags    = getaddrinfo() flags

        Returns:
            0 on success or an error code on failure, see addrinfo.ErrorCode.

     **************************************************************************/

    public ErrorCode get ( char[] node, char[] service,
                           int family, int type, int protocol,
                           addrinfo.Flags flags = addrinfo.Flags.None )
    {
        return super.get(this.node.toCstr(node), this.service.toCstr(service),
                         family, type, protocol, flags);
    }

    /**************************************************************************

        Gets the address info for a node and/or service.

        Params:
            node    = node name (may be null)
            service = service name (may be null)
            hints   = addrinfo instance specifying the socket family, type,
                      protocol and flags or null to get all available addresses

        Returns:
            0 on success or an error code on failure, see addrinfo.ErrorCode.

     **************************************************************************/

    public ErrorCode get ( char[] node, char[] service, addrinfo* hints = null )
    {
        return super.get(this.node.toCstr(node), this.service.toCstr(service),
                         hints);
    }
}

/**************************************************************************

    Appends a nul-terminator to src, storing the result in dst.

    Params:
        dst = destination string buffer
        src = string to nul-terminate

    Returns:
        dst.ptr or null if src is empty.

 **************************************************************************/

private char* toCstr ( ref char[] dst, char[] src )
{
    return src.length? dst.concat(src, "\0"[]).ptr : null;
}

/******************************************************************************

    Wraps getaddrinfo()/freeaddrinfo() and manages an addrinfo instance; uses
    C strings as arguments. This class is memory-friendly when used with 'scope'
    instances.

 ******************************************************************************/

class AddrInfoC
{
    alias addrinfo.Flags     Flags;
    alias addrinfo.ErrorCode ErrorCode;

    /**************************************************************************

        addrinfo instance.

     **************************************************************************/

    private addrinfo* info_ = null;

    /**************************************************************************

        IP address conversion buffer

     **************************************************************************/

    static assert (INET6_ADDRSTRLEN > INET_ADDRSTRLEN);

    char[INET6_ADDRSTRLEN] ip_address_buf;

    /**************************************************************************

        Destructor.

     **************************************************************************/

    ~this ( )
    {
        if (this.info_)
        {
            freeaddrinfo(this.info_);
        }
    }

    /**************************************************************************

        Gets the address info for a TCP/IP node and/or service.

        Params:
            node    = node name (may be null)
            service = service name (may be null)
            ipv6    = false: get the IPv4, true: get the IPv6 address
            flags   = getaddrinfo() flags

        Returns:
            0 on success or an error code on failure, see addrinfo.ErrorCode.

     **************************************************************************/

    public ErrorCode getTcpIp ( char* node, char* service, bool ipv6,
                                addrinfo.Flags flags = addrinfo.Flags.None )
    {
        return this.getIp(node, service, ipv6, SOCK_STREAM, IPPROTO_TCP, flags);
    }

    /**************************************************************************

        Gets the address info for an IP node and/or service.

        Params:
            node     = node name (may be null)
            service  = service name (may be null)
            ipv6     = false: get the IPv4, true: get the IPv6 address
            type     = socket type (0 for any type)
            protocol = socket protocol (0 for any protocol)
            flags    = getaddrinfo() flags

        Returns:
            0 on success or an error code on failure, see addrinfo.ErrorCode.

     **************************************************************************/

    public ErrorCode getIp ( char* node, char* service,
                             bool ipv6, int type, int protocol,
                             addrinfo.Flags flags = addrinfo.Flags.None )
    {
        return this.get(node, service, ipv6? AF_INET6 : AF_INET, type, protocol);
    }


    /**************************************************************************

        Gets the address info for a node and/or service.

        Params:
            node     = node name (may be null)
            service  = service name (may be null)
            family   = socket family (0 for any family)
            type     = socket type (0 for any type)
            protocol = socket protocol (0 for any protocol)
            flags    = getaddrinfo() flags

        Returns:
            0 on success or an error code on failure, see addrinfo.ErrorCode.

     **************************************************************************/

    public ErrorCode get ( char* node, char* service,
                           int family, int type, int protocol,
                           addrinfo.Flags flags = addrinfo.Flags.None )
    {
        auto hints = addrinfo(flags, family, type, protocol);

        return this.get(node, service, &hints);
    }

    /**************************************************************************

        Gets the address info for a node and/or service.

        Params:
            node    = node name (may be null)
            service = service name (may be null)
            hints   = addrinfo instance specifying the socket family, type,
                      protocol and flags or null to get all available addresses

        Returns:
            0 on success or an error code on failure, see addrinfo.ErrorCode.

     **************************************************************************/

    public ErrorCode get ( char* node, char* service, addrinfo* hints = null )
    {
        if (this.info_)
        {
            freeaddrinfo(this.info_);

            this.info_ = null;
        }

        return .getaddrinfo(node, service, hints, &this.info_);
    }

    /**************************************************************************

        Returns:
            the current address info as most recently obtained or null if the
            last get() failed or get() has not been called yet.

     **************************************************************************/

    public addrinfo* info ( )
    {
        return this.info_;
    }

    /***************************************************************************

        Obtains the current IP address in standard notation.

        Returns:
            a slice to the resulting IP address string in dst on success or null
            either on error or if the last get() failed or get() has not been
            called yet; errno is then 0. On success a nul-terminator follows the
            sliced string so its .ptr is a C string. On error errno is set
            appropriately.

        Errors:
            EAFNOSUPPORT: The address family is not supported (AF_INET/IPv4 or
                          AF_INET6/IPv6).

    ***************************************************************************/

    public char[] ip_address ( )
    {
        .errno = 0;

        return this.info_? this.info_.ipAddress(this.ip_address_buf) : null;
    }

    /***************************************************************************

        Returns:
            the current port or 0 if the last get() failed or get() has not been
            called yet.

    ***************************************************************************/

    public ushort port ( )
    {
        return this.info_? this.info_.port : cast(ushort) 0;
    }

    /***************************************************************************

        Returns:
            the official host name or null if the last get() failed or get() has
            not been called yet with Flags.AI_CANONNAME set. On success a
            nul-terminator follows the sliced string so its .ptr is a C string.

    ***************************************************************************/

    public char[] canonname ( )
    {
        return this.info_? this.info_.canonname : null;
    }

    /***************************************************************************

        Returns:
            the official host name as a nul-terminated C string or null if the
            last get() failed or get() has not been called yet with
            Flags.AI_CANONNAME set.

    ***************************************************************************/

    public char* canonname_c ( )
    {
        return this.info_? this.info_.ai_canonname : null;
    }
}
