/******************************************************************************

    Transparent Linux IP sockets interface wrapper.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.sys.socket.IPSocket;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.transition;

import ocean.stdc.posix.sys.socket;

import ocean.stdc.posix.netinet.in_: AF_INET, AF_INET6;

import ocean.stdc.posix.unistd: close;

import ocean.stdc.posix.sys.types: ssize_t;

import ocean.io.device.Conduit: ISelectable;

import ocean.io.device.IODevice: InputDevice, IOutputDevice;

import ocean.sys.socket.InetAddress;

import ocean.core.TypeConvert;

import ocean.sys.socket.model.ISocket;

import ocean.text.convert.Format;

deprecated("MSG_NOSIGNAL deprecated, please use the one in "
        "ocean.sys.socket.model.ISocket instead")
public alias ocean.sys.socket.model.ISocket.MSG_NOSIGNAL MSG_NOSIGNAL;

deprecated("SocketFlags deprecated, please use the one in "
        "ocean.sys.socket.model.ISocket instead")
public alias ocean.sys.socket.model.ISocket.SocketFlags SocketFlags;



/******************************************************************************

    TCP option codes supported by getsockopt()/setsockopt()
    (from <inet/netinet.h>).

 ******************************************************************************/

public enum TcpOptions
{
    None,
    TCP_NODELAY,       ///  1:  Don't delay send to coalesce packets
    TCP_MAXSEG,        ///  2:  Set maximum segment size
    TCP_CORK,          ///  3:  Control sending of partial frames
    TCP_KEEPIDLE,      ///  4:  Start keeplives after this period
    TCP_KEEPINTVL,     ///  5:  Interval between keepalives
    TCP_KEEPCNT,       ///  6:  Number of keepalives before death
    TCP_SYNCNT,        ///  7:  Number of SYN retransmits
    TCP_LINGER2,       ///  8:  Life time of orphaned FIN-WAIT-2 state
    TCP_DEFER_ACCEPT,  ///  9:  Wake up listener only when data arrive
    TCP_WINDOW_CLAMP,  /// 10:  Bound advertised window
    TCP_INFO,          /// 11:  Information about this connection.
    TCP_QUICKACK,      /// 12:  Bock/reenable quick ACKs.
    TCP_CONGESTION,    /// 13:  Congestion control algorithm.
    TCP_MD5SIG,        /// 14:  TCP MD5 Signature (RFC2385)

}


/******************************************************************************

    IP socket base class

 ******************************************************************************/

abstract class IIPSocket : ISocket
{
    version (D_Version2)
    {
        // add to overload set explicitly
        alias ISocket.socket socket;
    }

    /**************************************************************************

        Flags supported by accept4().

     **************************************************************************/

    alias .SocketFlags SocketFlags;

    alias .TcpOptions TcpOptions;


    /**************************************************************************

        true for IPv6, false for IPv4.

     **************************************************************************/

    public bool is_ipv6 ( )
    {
        return this._is_ipv6;
    }

    private bool _is_ipv6;

    /**************************************************************************

    public const socklen_t in_addrlen;
        Constructor.

        Params:
            is_ipv6    = true if this is an IPv6 socket or false if it is IPv4.
            in_addrlen = internet address struct length

     **************************************************************************/

    protected this ( bool is_ipv6, socklen_t in_addrlen )
    {
        super(in_addrlen);

        this._is_ipv6 = is_ipv6;
    }

    /**************************************************************************

        Creates an IP socket endpoint for communication and sets this.fd to the
        corresponding file descriptor.

        Params:
            type = desired socket type, which specifies the communication
                semantics.  Supported types are:

                SOCK_STREAM     Provides sequenced, reliable,  two-way,  connec‐
                                tion-based  byte  streams.   An out-of-band data
                                transmission mechanism may be supported.

                SOCK_DGRAM      Supports datagrams - connectionless,  unreliable
                                messages of a fixed maximum length.

                SOCK_SEQPACKET  Provides  a sequenced, reliable, two-way connec‐
                                tion-based data transmission path for  datagrams
                                of  fixed maximum length; a consumer is required
                                to read an entire packet with each input  system
                                call.

                SOCK_RAW        Provides raw network protocol access.

                Some  socket  types may not be implemented by all protocol fami‐
                lies;  for  example,  SOCK_SEQPACKET  is  not  implemented   for
                AF_INET (IPv4).

                Since  Linux  2.6.27, the type argument serves a second purpose:
                in addition to specifying a socket type, it may include the bit‐
                wise  OR  of any of the following values, to modify the behavior
                of socket():

                SOCK_NONBLOCK   Set the O_NONBLOCK file status flag on  the  new
                                open  file  description.   Using this flag saves
                                extra calls to  fcntl(2)  to  achieve  the  same
                                result.

                SOCK_CLOEXEC    Set  the  close-on-exec (FD_CLOEXEC) flag on the
                                new file descriptor.  See the description of the
                                O_CLOEXEC  flag  in open(2) for reasons why this
                                may be useful.

            protocol = desired protocol or 0 to use the default protocol for the
                specified type (e.g. TCP for `type == SOCK_STREAM` or UDP for
                `type == SOCK_DGRAM`).

                The protocol specifies a particular protocol to be used with the
                socket.   Normally  only  a  single protocol exists to support a
                particular socket type within a given protocol family, in  which
                case  protocol  can  be specified as 0.  However, it is possible
                that many protocols may exist, in which case a particular proto‐
                col  must  be  specified in this manner.  The protocol number to
                use is specific to the “communication domain” in which  communi‐
                cation  is  to take place; see protocols(5).  See getprotoent(3)
                on how to map protocol name strings to protocol numbers.

                Sockets of type SOCK_STREAM are full-duplex byte streams,  simi‐
                lar to pipes.  They do not preserve record boundaries.  A stream
                socket must be in a connected state before any data may be  sent
                or  received  on  it.  A connection to another socket is created
                with a connect(2) call.  Once connected, data may be transferred
                using  read(2) and write(2) calls or some variant of the send(2)
                and recv(2) calls.  When a session has been completed a close(2)
                may  be  performed.  Out-of-band data may also be transmitted as
                described in send(2) and received as described in recv(2).


        Returns:
            the socket file descriptor on success or -1 on failure. On failure
            errno is set appropriately and this.fd is -1.

        Errors:
            EACCES Permission  to  create  a socket of the specified type and/or
                   protocol is denied.

            EAFNOSUPPORT
                   The implementation does not  support  the  specified  address
                   family.

            EINVAL Unknown protocol, or protocol family not available.

            EINVAL Invalid flags in type.

            EMFILE Process file table overflow.

            ENFILE The  system  limit on the total number of open files has been
                   reached.

            ENOBUFS or ENOMEM
                   Insufficient memory is available.  The socket cannot be  cre‐
                   ated until sufficient resources are freed.

            EPROTONOSUPPORT
                   The  protocol type or the specified protocol is not supported
                   within this domain.

            Other errors may be generated by the underlying protocol modules.

     **************************************************************************/

    public int socket ( int type, int protocol = 0 )
    {
        this.fd = .socket(this.is_ipv6? AF_INET6 : AF_INET, type, protocol);

        this.close_in_destructor = (this.fd >= 0);

        return this.fd;
    }

    /**************************************************************************

        Calls socket() to create a TCP/IP socket, setting this.fd to the file
        descriptor.

        Params:
            nonblocking = true: make the socket nonblocking, false: make it
                          blocking

        Returns:
            the socket file descriptor on success or -1 on failure. On failure
            errno is set appropriately and this.fd is -1.

     **************************************************************************/

    public int tcpSocket ( bool nonblocking = false )
    {
        auto flags = SOCK_STREAM | (nonblocking ? SocketFlags.SOCK_NONBLOCK : 0);

        return this.socket(flags, IPPROTO_TCP);
    }
}

/******************************************************************************

    IP socket class, contains the IPv4/6 address specific parts.

    Template_Params:
        IPv6 = true: use IPv6, false: use IPv4

 ******************************************************************************/

class IPSocket ( bool IPv6 = false ) : IIPSocket
{
    alias .InetAddress!(IPv6) InetAddress;

    /**************************************************************************

        Type alias of the "sin" internet address struct type, sockaddr_in for
        IPv4 or sockaddr_in6 for IPv6.

     **************************************************************************/

    alias InetAddress.Addr InAddr;

    /**************************************************************************

        Constructor.

     **************************************************************************/

    public this ( )
    {
        super(IPv6, InAddr.sizeof);
    }

    /**************************************************************************

        Assigns a local address to this socket. This socket needs to have been
        created by socket().

        Params:
            local_address = local address

        Returns:
            0 on success or -1 on failure. On failure errno is set
            appropriately.

        Errors:
            EACCES The address is protected, and the user is not the superuser.

            EADDRINUSE
                   The given address is already in use.

            EBADF  sockfd is not a valid descriptor.

            EINVAL The socket is already bound to an address.

            ENOTSOCK
                   The file descriptor is a descriptor for a file, not a socket.

     **************************************************************************/

    public int bind ( InAddr local_address )
    {
        return super.bind(cast (sockaddr*) &local_address);
    }

    /**************************************************************************

        Assigns a local address and optionally a port to this socket.
        This socket needs to have been created by socket().

        Params:
            local_ip_address = local IP address
            local_port       = local port or 0 to use the wildcard "any" port

        Returns:
            0 on success or -1 on failure. On failure errno is set
            appropriately.

        Errors:
            as above but also sets errno to EAFNOSUPPORT if the address does not
            contain a valid IP address string.

     **************************************************************************/

    public int bind ( cstring local_ip_address, ushort local_port = 0 )
    {
        InetAddress in_address;

        sockaddr* local_address = in_address(local_ip_address, local_port);

        return local_address? super.bind(local_address) : -1;
    }

    /**************************************************************************

        Assigns the wildcard "any" local address and optionally a port to this
        socket. This socket needs to have been created by socket().

        Params:
            local_port = local port or 0 to use the wildcard "any" port

        Returns:
            0 on success or -1 on failure. On failure errno is set
            appropriately.

     **************************************************************************/

    public int bind ( ushort local_port = 0 )
    {
        InetAddress in_address;

        return super.bind(in_address(local_port));
    }

    /**************************************************************************

        Overriding wrapper to satisfy overload-override rules of D.

     **************************************************************************/

    public override int bind ( sockaddr* local_address )
    {
        return super.bind(local_address);
    }

    /**************************************************************************

        Accepts a connection from a listening socket and sets this.fd to the
        accepted socket file descriptor.

        The  accept()  system  call  is  used with connection-based socket types
        (SOCK_STREAM, SOCK_SEQPACKET).  It extracts the first connection request
        on  the  queue  of pending connections for the listening socket, creates
        a new connected socket, and returns a new file descriptor  referring  to
        that socket.  The newly  created socket  is not in the listening  state.
        The original socket is unaffected by this call.

        If  no  pending  connections are present on the queue, and the socket is
        not marked as nonblocking, accept() blocks the caller until a connection
        is  present.  If the socket is marked nonblocking and no pending connec‐
        tions are present on the queue, accept() fails with the error EAGAIN  or
        EWOULDBLOCK.

        In order to be notified of incoming connections on a socket, you can use
        select(2) or poll(2).  A readable event will be  delivered  when  a  new
        connection  is  attempted and you may then call accept() to get a socket
        for that connection.  Alternatively, you can set the socket  to  deliver
        SIGIO when activity occurs on a socket; see socket(7) for details.

        Params:
            listening_socket = the listening socket to accept the new connection
                               from
            remote_address   = filled in with the address of the peer socket, as
                               known to the communications layer
            flags =
                The following  values  can be bitwise ORed in flags:

                SOCK_NONBLOCK   Set the O_NONBLOCK file status flag on  the  new
                                open  file  description.   Using this flag saves
                                extra calls to  fcntl(2)  to  achieve  the  same
                                result.

                SOCK_CLOEXEC    Set  the  close-on-exec (FD_CLOEXEC) flag on the
                                new file descriptor.  See the description of the
                                O_CLOEXEC  flag  in open(2) for reasons why this
                                may be useful.



        Returns:
            the file descriptor of the accepted socket on success or -1 on
            failure. On failure errno is set appropriately.

        Errors:
            EAGAIN or EWOULDBLOCK
                   The  socket  is  marked  nonblocking  and  no connections are
                   present to be accepted.

            EBADF  The descriptor is invalid.

            ECONNABORTED
                   A connection has been aborted.

            EFAULT The  addr  argument  is  not  in  a writable part of the user
                   address space.

            EINTR  The system call was interrupted by a signal that  was  caught
                   before a valid connection arrived; see signal(7).

            EINVAL Socket  is  not  listening  for  connections,  or  addrlen is
                   invalid (e.g., is negative).

            EINVAL invalid value in flags.

            EMFILE The per-process limit  of  open  file  descriptors  has  been
                   reached.

            ENFILE The  system  limit on the total number of open files has been
                   reached.

            ENOBUFS, ENOMEM
                   Not enough free memory.  This often  means  that  the  memory
                   allocation is limited by the socket buffer limits, not by the
                   system memory.

            ENOTSOCK
                   The descriptor references a file, not a socket.

            EOPNOTSUPP
                   The referenced socket is not of type SOCK_STREAM.

            EPROTO Protocol error.

            In addition, Linux accept() may fail if:

            EPERM  Firewall rules forbid connection.

            In addition, network errors for the new socket and  as  defined  for
            the  protocol  may  be  returned.   Various Linux kernels can return
            other  errors  such  as  ENOSR,  ESOCKTNOSUPPORT,   EPROTONOSUPPORT,
            ETIMEDOUT.  The value ERESTARTSYS may be seen during a trace.

     **************************************************************************/

    public int accept ( ISelectable listening_socket,
                        ref InAddr remote_address, SocketFlags flags = SocketFlags.None )
    {
        socklen_t addrlen;

        return super.accept(listening_socket,
                            cast (sockaddr*) &remote_address, addrlen, flags);
    }

    /**************************************************************************

        Calls accept() to accept a connection from a listening socket, sets
        this.fd to the accepted socket file descriptor.

        Params:
            listening_socket = the listening socket to accept the new connection
                               from
            remote_address   = filled in with the address of the peer socket, as
                               known to the communications layer
            nonblocking      = true: make the accepted socket nonblocking,
                               false: leave it blocking

        Returns:
            the file descriptor of the accepted socket on success or -1 on
            failure. On failure errno is set appropriately.

     **************************************************************************/

    public int accept ( ISelectable listening_socket,
                        ref InAddr remote_address, bool nonblocking )
    {
        const SocketFlags[2] flags = [SocketFlags.None, SocketFlags.SOCK_NONBLOCK];

        return this.accept(listening_socket, remote_address, flags[nonblocking]);
    }

    /**************************************************************************

        Overriding wrapper to satisfy overload-override rules of D.

     **************************************************************************/

    public override int accept ( ISelectable listening_socket,
                                 sockaddr* remote_address, out socklen_t addrlen,
                                 SocketFlags flags = SocketFlags.None )
    {
        return super.accept(listening_socket, remote_address, addrlen, flags);
    }

    /**************************************************************************

        Connects this socket the specified address. This socket needs to have
        been created by socket().

        If  this socket is of type SOCK_DGRAM  then the  address  is the one  to
        which datagrams are sent by default, and the  only  address  from  which
        datagrams  are  received.   If  the  socket  is  of  type SOCK_STREAM or
        SOCK_SEQPACKET, this call attempts to make a connection  to  the  socket
        that is bound to the address specified by addr.

        Generally,  connection-based protocol sockets may successfully connect()
        only once; connectionless protocol sockets may  use  connect()  multiple
        times  to change their association.  Connectionless sockets may dissolve
        the association by connecting to an address with the sa_family member of
        sockaddr set to AF_UNSPEC (supported on Linux since kernel 2.2).

        Params:
            remote_address = remote address

        Returns:
            0 on success or -1 on failure. On error failure is set
            appropriately.

        Errors:
            The  following  are  general socket errors only.  There may be other
            domain-specific error codes.

            EACCES For Unix domain sockets, which are  identified  by  pathname:
                   Write permission is denied on the socket file, or search per‐
                   mission is denied for one of the directories in the path pre‐
                   fix.  (See also path_resolution(7).)

            EACCES, EPERM
                   The user tried to connect to a broadcast address without hav‐
                   ing the socket  broadcast  flag  enabled  or  the  connection
                   request failed because of a local firewall rule.

            EADDRINUSE
                   Local address is already in use.

            EAGAIN No more free local ports or insufficient entries in the rout‐
                   ing    cache.    For   AF_INET   see   the   description   of
                   /proc/sys/net/ipv4/ip_local_port_range ip(7) for  information
                   on how to increase the number of local ports.

            EALREADY
                   The  socket  is nonblocking and a previous connection attempt
                   has not yet been completed.

            EBADF  The file descriptor is not a valid index  in  the  descriptor
                   table.

            ECONNREFUSED
                   No-one listening on the remote address.

            EFAULT The  socket  structure  address is outside the user's address
                   space.

            EINPROGRESS
                   The socket is nonblocking and the connection cannot  be  com‐
                   pleted  immediately.   It is possible to select(2) or poll(2)
                   for completion by selecting the socket  for  writing.   After
                   select(2)  indicates  writability,  use getsockopt(2) to read
                   the SO_ERROR option at level SOL_SOCKET to determine  whether
                   connect() completed successfully (SO_ERROR is zero) or unsuc‐
                   cessfully (SO_ERROR is one of the usual  error  codes  listed
                   here, explaining the reason for the failure).

            EINTR  The  system call was interrupted by a signal that was caught;
                   see signal(7).

            EISCONN
                   The socket is already connected.

            ENETUNREACH
                   Network is unreachable.

            ENOTSOCK
                   The file descriptor is not associated with a socket.

            ETIMEDOUT
                   Timeout while attempting connection.  The server may  be  too
                   busy to accept new connections.  Note that for IP sockets the
                   timeout may be very long when syncookies are enabled  on  the
                   server.

     **************************************************************************/

    public int connect ( InAddr remote_address )
    {
        return super.connect(cast (sockaddr*) &remote_address);
    }

    /**************************************************************************

        Connects this socket the specified address and port. This socket needs
        to have been created by socket().

        Params:
            remote_ip_address = remote IP address
            remote_port       = remote port

        Returns:
            0 on success or -1 on failure. On failure errno is set
            appropriately.

        Errors:
            as above but also sets errno to EAFNOSUPPORT if the address does not
            contain a valid IP address string.

     **************************************************************************/

    public int connect ( cstring remote_ip_address, ushort remote_port )
    {
        InetAddress in_address;

        sockaddr* remote_address = in_address(remote_ip_address, remote_port);

        return remote_address? super.connect(remote_address) : -1;
    }

    /**************************************************************************

        Overriding wrapper to satisfy overload-override rules of D.

     **************************************************************************/

    public override int connect ( sockaddr* remote_address )
    {
        return super.connect(remote_address);
    }

    /**************************************************************************

        Obtains the current address to which this socket is bound.

        Params:
            local_address = filled in with the address of the local socket, as
                            known to the communications layer, depending on the
                            IP version of this class

        Returns:
            0 success or -1 on failure. On failure errno is set appropriately.

        Errors:
            EBADF The argument sockfd is not a valid descriptor.

            EFAULT The local_address argument points to memory not in a valid
                part of the process address space.

            ENOBUFS
                Insufficient resources were available in the system to perform
                the operation.

            ENOTSOCK
                this.fd is a file, not a socket.

     **************************************************************************/

    public int getsockname ( out InAddr local_address )
    {
        socklen_t addrlen;

        return super.getsockname(cast (sockaddr*) &local_address, addrlen);
    }

    /**************************************************************************

        Overriding wrapper to satisfy overload-override rules of D.

     **************************************************************************/

    public override int getsockname ( sockaddr* local_address, out socklen_t addrlen )
    {
        return super.getsockname(local_address, addrlen);
    }

    /**************************************************************************

        Obtains the address of the peer connected to this socket.

        Params:
            remote_address = filled in with the address of the remote socket, as
                             known to the communications layer, depending on the
                             IP version of this class

        Returns:
            0 success or -1 on failure. On failure errno is set appropriately.

        Errors:
            EBADF this.fg is not a valid descriptor.

            EFAULT The remote_address argument points to memory not in a valid
                part of the process address space.

            ENOBUFS
                Insufficient resources were available in the system to perform
                the operation.

            ENOTSOCK
                this.fd is a file, not a socket.

     **************************************************************************/

    public int getpeername ( out InAddr remote_address )
    {
        socklen_t addrlen;

        return super.getpeername(cast (sockaddr*) &remote_address, addrlen);
    }

    /**************************************************************************

        Overriding wrapper to satisfy overload-override rules of D.

     **************************************************************************/

    public override int getpeername ( sockaddr* remote_address, out socklen_t addrlen )
    {
        return super.getpeername(remote_address, addrlen);
    }

    /**************************************************************************

        Formats information about the socket into the provided buffer.

        Params:
            buf      = buffer to format into
            io_error = true if an I/O error has been reported

     **************************************************************************/

    override public void formatInfo ( ref char[] buf, bool io_error )
    {
        InetAddress in_address;
        char[in_address.addrstrlen] ip_address_;
        this.getpeername(in_address.addr);
        size_t ip_address_len = in_address.inet_ntop(ip_address_).length;

        Format.format(buf, "fd={}, remote={}:{}, ioerr={}",
            this.fileHandle, ip_address_[0 .. ip_address_len],
            in_address.port, io_error);
    }
}


/******************************************************************************/

version (UnitTest)
{
    import ocean.core.Test;
}

unittest
{
    auto socket = new IPSocket!();
    socket.tcpSocket();
    socket.setsockoptVal(SOL_SOCKET, SO_KEEPALIVE, true);
    socket.setsockoptVal(IPPROTO_TCP, socket.TcpOptions.TCP_KEEPIDLE, 5);
    socket.setsockoptVal(IPPROTO_TCP, socket.TcpOptions.TCP_KEEPCNT, 3);
    socket.setsockoptVal(IPPROTO_TCP, socket.TcpOptions.TCP_KEEPINTVL, 3);
}
