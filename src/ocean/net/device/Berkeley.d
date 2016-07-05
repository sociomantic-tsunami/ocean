/*******************************************************************************

    Copyright:
        Copyright (c) 2004-2009 Tango contributors.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.
    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.
*******************************************************************************/


module ocean.net.device.Berkeley;

import ocean.transition;

import ocean.sys.Common;

import ocean.core.Exception_tango;

import ocean.stdc.string : strlen;
import ocean.stdc.stringz;

import ocean.stdc.posix.netdb;
import ocean.stdc.posix.sys.socket;
import ocean.stdc.posix.netinet.in_; // : sockaddr_in, sockaddr_in6

version (UnitTest)
{
    import ocean.core.Test;
}

/*******************************************************************************

*******************************************************************************/

enum {SOCKET_ERROR = ocean.stdc.posix.sys.socket.SOCKET_ERROR}

/*******************************************************************************

*******************************************************************************/

enum SocketOption
{
        DEBUG        =   .SO_DEBUG     ,       /* turn on debugging info recording */
        BROADCAST    =   .SO_BROADCAST ,       /* permit sending of broadcast msgs */
        REUSEADDR    =   .SO_REUSEADDR ,       /* allow local address reuse */
        LINGER       =   .SO_LINGER    ,       /* linger on close if data present */
        DONTLINGER   = ~(.SO_LINGER),

        OOBINLINE    =   .SO_OOBINLINE ,       /* leave received OOB data in line */
        ACCEPTCONN   =   .SO_ACCEPTCONN,       /* socket has had listen() */
        KEEPALIVE    =   .SO_KEEPALIVE ,       /* keep connections alive */
        DONTROUTE    =   .SO_DONTROUTE ,       /* just use interface addresses */
        TYPE         =   .SO_TYPE      ,       /* get socket type */

        /*
         * Additional options, not kept in so_options.
         */
        SNDBUF       = .SO_SNDBUF,               /* send buffer size */
        RCVBUF       = .SO_RCVBUF,               /* receive buffer size */
        ERROR        = .SO_ERROR ,               /* get error status and clear */

        // OptionLevel.IP settings
        MULTICAST_TTL   = .IP_MULTICAST_TTL  ,
        MULTICAST_LOOP  = .IP_MULTICAST_LOOP ,
        ADD_MEMBERSHIP  = .IP_ADD_MEMBERSHIP ,
        DROP_MEMBERSHIP = .IP_DROP_MEMBERSHIP,

        // OptionLevel.TCP settings
        TCP_NODELAY     = .TCP_NODELAY ,

        // Windows specifics
        WIN_UPDATE_ACCEPT_CONTEXT  = 0x700B,
        WIN_CONNECT_TIME           = 0x700C,
        WIN_UPDATE_CONNECT_CONTEXT = 0x7010,
}

/*******************************************************************************

*******************************************************************************/

enum SocketOptionLevel
{
        SOCKET = .SOL_SOCKET    ,
        IP     = .IPPROTO_IP    ,
        TCP    = .IPPROTO_TCP   ,
        UDP    = .IPPROTO_UDP   ,
}

/*******************************************************************************

*******************************************************************************/

enum SocketType
{
        STREAM    = .SOCK_STREAM   , /++ sequential, reliable +/
        DGRAM     = .SOCK_DGRAM    , /++ connectionless unreliable, max length +/
        SEQPACKET = .SOCK_SEQPACKET, /++ sequential, reliable, max length +/
}

/*******************************************************************************

*******************************************************************************/

enum ProtocolType
{
        IP   = .IPPROTO_IP   ,     /// default internet protocol (probably 4 for compatibility)
        IPV4 = .IPPROTO_IP   ,     /// internet protocol version 4
        IPV6 = .IPPROTO_IPV6 ,     /// internet protocol version 6
        ICMP = .IPPROTO_ICMP ,     /// internet control message protocol
        IGMP = .IPPROTO_IGMP ,     /// internet group management protocol
        TCP  = .IPPROTO_TCP  ,     /// transmission control protocol
        PUP  = .IPPROTO_PUP  ,     /// PARC universal packet protocol
        UDP  = .IPPROTO_UDP  ,     /// user datagram protocol
        IDP  = .IPPROTO_IDP  ,     /// Xerox NS protocol
}

/*******************************************************************************

*******************************************************************************/

enum AddressFamily
{
        UNSPEC    = .AF_UNSPEC   ,
        UNIX      = .AF_UNIX     ,
        INET      = .AF_INET     ,
        IPX       = .AF_IPX      ,
        APPLETALK = .AF_APPLETALK,
        INET6     = .AF_INET6    ,
}

/*******************************************************************************

*******************************************************************************/

enum SocketShutdown
{
        RECEIVE =  .SHUT_RD,
        SEND =     .SHUT_WR,
        BOTH =     .SHUT_RDWR,
}

/*******************************************************************************

*******************************************************************************/

enum SocketFlags
{
        NONE =           0,
        OOB =            .MSG_OOB,        /// out of band
        PEEK =           .MSG_PEEK,       /// only for receiving
        DONTROUTE =      .MSG_DONTROUTE,  /// only for sending
        NOSIGNAL =       0x4000,                /// inhibit signals
}

enum AIFlags: int
{
        PASSIVE = .AI_PASSIVE,            /// get address to use bind()
        CANONNAME = .AI_CANONNAME,        /// fill ai_canonname
        NUMERICHOST = .AI_NUMERICHOST,    /// prevent host name resolution
        NUMERICSERV = .AI_NUMERICSERV,    /// prevent service name resolution valid
                                                /// flags for addrinfo (not a standard def,
                                                /// apps should not use it)
        ALL = .AI_ALL,                    /// IPv6 and IPv4-mapped (with AI_V4MAPPED)
        ADDRCONFIG = .AI_ADDRCONFIG,      /// only if any address is assigned
        V4MAPPED = .AI_V4MAPPED,          /// accept IPv4-mapped IPv6 address special
                                                /// recommended flags for getipnodebyname
        MASK = .AI_MASK,
        DEFAULT = .AI_DEFAULT,
}

enum AIError
{
        BADFLAGS = .EAI_BADFLAGS,	        /// Invalid value for `ai_flags' field.
        NONAME = .EAI_NONAME,	        /// NAME or SERVICE is unknown.
        AGAIN = .EAI_AGAIN,	        /// Temporary failure in name resolution.
        FAIL = .EAI_FAIL,	                /// Non-recoverable failure in name res.
        NODATA = .EAI_NODATA,	        /// No address associated with NAME.
        FAMILY = .EAI_FAMILY,	        /// `ai_family' not supported.
        SOCKTYPE = .EAI_SOCKTYPE,	        /// `ai_socktype' not supported.
        SERVICE = .EAI_SERVICE,	        /// SERVICE not supported for `ai_socktype'.
        MEMORY = .EAI_MEMORY,	        /// Memory allocation failure.
}


enum NIFlags: int
{
        MAXHOST = .NI_MAXHOST,
        MAXSERV = .NI_MAXSERV,
        NUMERICHOST = .NI_NUMERICHOST,    /// Don't try to look up hostname.
        NUMERICSERV = .NI_NUMERICSERV,    /// Don't convert port number to name.
        NOFQDN = .NI_NOFQDN,              /// Only return nodename portion.
        NAMEREQD = .NI_NAMEREQD,          /// Don't return numeric addresses.
        DGRAM = .NI_DGRAM,                /// Look up UDP service rather than TCP.
}


/*******************************************************************************

        conversions for network byte-order

*******************************************************************************/

version(BigEndian)
{
        private ushort htons (ushort x)
        {
                return x;
        }

        private uint htonl (uint x)
        {
                return x;
        }
}
else
{
        import ocean.core.BitManip;

        private ushort htons (ushort x)
        {
                return cast(ushort) ((x >> 8) | (x << 8));
        }

        private uint htonl (uint x)
        {
                return bswap(x);
        }
}

/*******************************************************************************


*******************************************************************************/

private extern (C)
{
        import ocean.stdc.errno;

        mixin(Typedef!(int, "socket_t", -1));

        socket_t socket(int af, int type, int protocol);
        int fcntl(socket_t s, int f, ...);
        uint inet_addr(Const!(char)* cp);
        int bind(socket_t s, Address.sockaddr* name, int namelen);
        int connect(socket_t s, Address.sockaddr* name, int namelen);
        int listen(socket_t s, int backlog);
        socket_t accept(socket_t s, Address.sockaddr* addr, int* addrlen);
        int close(socket_t s);
        int shutdown(socket_t s, int how);
        int getpeername(socket_t s, Address.sockaddr* name, int* namelen);
        int getsockname(socket_t s, Address.sockaddr* name, int* namelen);
        int send(socket_t s, Const!(void)* buf, size_t len, int flags);
        int sendto(socket_t s, Const!(void)* buf, size_t len, int flags, Address.sockaddr* to, int tolen);
        int recv(socket_t s, void* buf, size_t len, int flags);
        int recvfrom(socket_t s, void* buf, size_t len, int flags, Address.sockaddr* from, int* fromlen);
        int select(int nfds, SocketSet.fd* readfds, SocketSet.fd* writefds, SocketSet.fd* errorfds, SocketSet.timeval* timeout);
        int getsockopt(socket_t s, int level, int optname, void* optval, int* optlen);
        int setsockopt(socket_t s, int level, int optname, void* optval, int optlen);
        int gethostname(void* namebuffer, int buflen);
        char* inet_ntoa(uint ina);
        NetHost.hostent* gethostbyname(Const!(char)* name);
        NetHost.hostent* gethostbyaddr(void* addr, int len, int type);

        /**
        Given node and service, which identify an Internet host and a service,
        getaddrinfo() returns one or more addrinfo structures, each of which
        contains an Internet address that can be specified in a call to bind or
        connect. The getaddrinfo() function combines the functionality provided
        by the getservbyname and getservbyport functions into a single interface,
        but unlike the latter functions, getaddrinfo() is reentrant and allows
        programs to eliminate IPv4-versus-IPv6 dependencies. (C) MAN
        */
        int getaddrinfo(Const!(char)* node, Const!(char)* service, Address.addrinfo* hints, Address.addrinfo** res);

        /**
        The freeaddrinfo() function frees the memory that was allocated for the
        dynamically allocated linked list res.  (C) MAN
        */
        void freeaddrinfo(Address.addrinfo *res);

        /**
        The getnameinfo() function is the inverse of getaddrinfo: it converts a socket
        address to a corresponding host and service, in a protocol-independent manner.
        It combines the functionality of gethostbyaddr and getservbyport, but unlike
        those functions, getaddrinfo is reentrant and allows programs to eliminate
        IPv4-versus-IPv6 dependencies. (C) MAN
        */
        int getnameinfo(Address.sockaddr* sa, int salen, char* host, int hostlen, char* serv, int servlen, int flags);

        /**
        The gai_strerror function translates error codes of getaddrinfo, freeaddrinfo
        and getnameinfo to a human readable string, suitable for error reporting. (C) MAN
        */
        char* gai_strerror(int errcode);

        char* inet_ntop(int af, void *src, char *dst, int len);
}

/*******************************************************************************

*******************************************************************************/

public struct Berkeley
{
        socket_t        sock;
        SocketType      type;
        AddressFamily   family;
        ProtocolType    protocol;

        enum : socket_t
        {
                INVALID_SOCKET = socket_t.init
        }

        enum
        {
                Error = -1
        }

        alias Error        ERROR;               // backward compatibility
        alias noDelay      setNoDelay;          // backward compatibility
        alias addressReuse setAddressReuse;     // backward compatibility


        /***********************************************************************

                Configure this instance

        ***********************************************************************/

        void open (AddressFamily family, SocketType type, ProtocolType protocol, bool create=true)
        {
                this.type = type;
                this.family = family;
                this.protocol = protocol;
                if (create)
                    reopen;
        }

        /***********************************************************************

                Open/reopen a native socket for this instance

        ***********************************************************************/

        void reopen (socket_t sock = sock.init)
        {
                if (this.sock != sock.init)
                    this.detach;

                if (sock is sock.init)
                   {
                   sock = cast(socket_t) socket (family, type, protocol);
                   if (sock is sock.init)
                       exception ("Unable to create socket: ");
                   }

                this.sock = sock;
        }

        /***********************************************************************

                calling shutdown() before this is recommended for connection-
                oriented sockets

        ***********************************************************************/

        void detach ()
        {
                if (sock != sock.init)
                    .close (sock);
                sock = sock.init;
        }

        /***********************************************************************

                Return the underlying OS handle of this Conduit

        ***********************************************************************/

        socket_t handle ()
        {
                return sock;
        }

        /***********************************************************************

                Return socket error status

        ***********************************************************************/

        int error ()
        {
                int errcode;
                getOption (SocketOptionLevel.SOCKET, SocketOption.ERROR, (&errcode)[0..1]);
                return errcode;
        }

        /***********************************************************************

                Return the last error

        ***********************************************************************/

        static int lastError ()
        {
               return errno;
        }

        /***********************************************************************

                Is this socket still alive? A closed socket is considered to
                be dead, but a shutdown socket is still alive.

        ***********************************************************************/

        bool isAlive ()
        {
                int type, typesize = type.sizeof;
                return getsockopt (sock, SocketOptionLevel.SOCKET,
                                   SocketOption.TYPE, cast(char*) &type,
                                   &typesize) != Error;
        }

        /***********************************************************************

        ***********************************************************************/

        AddressFamily addressFamily ()
        {
                return family;
        }

        /***********************************************************************

        ***********************************************************************/

        Berkeley* bind (Address addr)
        {
                if(Error == .bind (sock, addr.name, addr.nameLen))
                   exception ("Unable to bind socket: ");
                return this;
        }

        /***********************************************************************

        ***********************************************************************/

        Berkeley* connect (Address to)
        {
                if (Error == .connect (sock, to.name, to.nameLen))
                   {
                   if (! blocking)
                      {
                      auto err = lastError;
                      if (err is EINPROGRESS)
                          return this;
                      }
                   exception ("Unable to connect socket: ");
                   }
                return this;
        }

        /***********************************************************************

                need to bind() first

        ***********************************************************************/

        Berkeley* listen (int backlog)
        {
                if (Error == .listen (sock, backlog))
                    exception ("Unable to listen on socket: ");
                return this;
        }

        /***********************************************************************

                need to bind() first

        ***********************************************************************/

        void accept (ref Berkeley target)
        {
                auto newsock = .accept (sock, null, null);
                if (socket_t.init is newsock)
                    exception ("Unable to accept socket connection: ");

                target.reopen (newsock);
                target.protocol = protocol;            //same protocol
                target.family = family;                //same family
                target.type = type;                    //same type
        }

        /***********************************************************************

                The shutdown function shuts down the connection of the socket.
                Depending on the argument value, it will:

                    -   stop receiving data for this socket. If further data
                        arrives, it is rejected.

                    -   stop trying to transmit data from this socket. Also
                        discards any data waiting to be sent. Stop looking for
                        acknowledgement of data already sent; don't retransmit
                        if any data is lost.

        ***********************************************************************/

        Berkeley* shutdown (SocketShutdown how)
        {
                .shutdown (sock, how);
                return this;
        }

        /***********************************************************************

                set linger timeout

        ***********************************************************************/

        Berkeley* linger (int period)
        {
                alias uint attr;

                union linger
                {
                        struct {
                               attr l_onoff;            // option on/off
                               attr l_linger;           // linger time
                               };
                        attr[2] array;                  // combined
                }

                linger l;
                l.l_onoff = 1;                          // option on/off
                l.l_linger = cast(ushort) period;       // linger time

                return setOption (SocketOptionLevel.SOCKET, SocketOption.LINGER, l.array);
        }

        /***********************************************************************

                enable/disable address reuse

        ***********************************************************************/

        Berkeley* addressReuse (bool enabled)
        {
                int[1] x = enabled;
                return setOption (SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, x);
        }

        /***********************************************************************

                enable/disable noDelay option (nagle)

        ***********************************************************************/

        Berkeley* noDelay (bool enabled)
        {
                int[1] x = enabled;
                return setOption (SocketOptionLevel.TCP, SocketOption.TCP_NODELAY, x);
        }

        /***********************************************************************

                Helper function to handle the adding and dropping of group
                membership.

        ***********************************************************************/

        void joinGroup (IPv4Address address, bool onOff)
        {
                assert (address, "Socket.joinGroup :: invalid null address");

                struct ip_mreq
                {
                uint  imr_multiaddr;  /* IP multicast address of group */
                uint  imr_interface;  /* local IP address of interface */
                }

                ip_mreq mrq;

                auto option = (onOff) ? SocketOption.ADD_MEMBERSHIP : SocketOption.DROP_MEMBERSHIP;
                mrq.imr_interface = 0;
                mrq.imr_multiaddr = address.sin.sin_addr.s_addr;

                if (.setsockopt(sock, SocketOptionLevel.IP, option, &mrq, mrq.sizeof) == Error)
                    exception ("Unable to perform multicast join: ");
        }

        /***********************************************************************

        ***********************************************************************/

        Address newFamilyObject ()
        {
                if (family is AddressFamily.INET)
                   return new IPv4Address;
                if (family is AddressFamily.INET6)
		    return new IPv6Address;
		return new UnknownAddress;
        }

        /***********************************************************************

                return the hostname

        ***********************************************************************/

        static istring hostName ()
        {
                char[64] name;

                if(Error == .gethostname (name.ptr, name.length))
                   exception ("Unable to obtain host name: ");
                return idup(name [0 .. strlen(name.ptr)]);
        }

        /***********************************************************************

                return the default host address (IPv4)

        ***********************************************************************/

        static uint hostAddress ()
        {
                auto ih = new NetHost;
                ih.getHostByName (hostName);
                assert (ih.addrList.length);
                return ih.addrList[0];
        }

        /***********************************************************************

                return the remote address of the current connection (IPv4)

        ***********************************************************************/

        Address remoteAddress ()
        {
                auto addr = newFamilyObject;
                auto nameLen = addr.nameLen;
                if(Error == .getpeername (sock, addr.name, &nameLen))
                   exception ("Unable to obtain remote socket address: ");
                assert (addr.addressFamily is family);
                return addr;
        }

        /***********************************************************************

                return the local address of the current connection (IPv4)

        ***********************************************************************/

        Address localAddress ()
        {
                auto addr = newFamilyObject;
                auto nameLen = addr.nameLen;
                if(Error == .getsockname (sock, addr.name, &nameLen))
                   exception ("Unable to obtain local socket address: ");
                assert (addr.addressFamily is family);
                return addr;
        }

        /***********************************************************************

                Send data on the connection. Returns the number of bytes
                actually sent, or ERROR on failure. If the socket is blocking
                and there is no buffer space left, send waits.

                Returns number of bytes actually sent, or -1 on error

        ***********************************************************************/

        int send (Const!(void)[] buf, SocketFlags flags=SocketFlags.NONE)
        {
                if (buf.length is 0)
                    return 0;

                version (Posix)
                        {
                        auto ret = .send (sock, buf.ptr, buf.length,
                                          SocketFlags.NOSIGNAL + cast(int) flags);
                        if (errno is EPIPE)
                            ret = -1;
                        return ret;
                        }
                     else
                        return .send (sock, buf.ptr, buf.length, cast(int) flags);
        }

        /***********************************************************************

                Send data to a specific destination Address. If the
                destination address is not specified, a connection
                must have been made and that address is used. If the
                socket is blocking and there is no buffer space left,
                sendTo waits.

        ***********************************************************************/

        int sendTo (Const!(void)[] buf, SocketFlags flags, Address to)
        {
                return sendTo (buf, cast(int) flags, to.name, to.nameLen);
        }

        /***********************************************************************

                ditto

        ***********************************************************************/

        int sendTo (Const!(void)[] buf, Address to)
        {
                return sendTo (buf, SocketFlags.NONE, to);
        }

        /***********************************************************************

                ditto - assumes you connect()ed

        ***********************************************************************/

        int sendTo (Const!(void)[] buf, SocketFlags flags=SocketFlags.NONE)
        {
                return sendTo (buf, cast(int) flags, null, 0);
        }

        /***********************************************************************

                Send data to a specific destination Address. If the
                destination address is not specified, a connection
                must have been made and that address is used. If the
                socket is blocking and there is no buffer space left,
                sendTo waits.

        ***********************************************************************/

        private int sendTo (Const!(void)[] buf, int flags, Address.sockaddr* to, int len)
        {
                if (buf.length is 0)
                    return 0;

                version (Posix)
                        {
                        auto ret = .sendto (sock, buf.ptr, buf.length,
                                            flags | SocketFlags.NOSIGNAL, to, len);
                        if (errno is EPIPE)
                            ret = -1;
                        return ret;
                        }
                     else
                        return .sendto (sock, buf.ptr, buf.length, flags, to, len);
        }

        /***********************************************************************
                Receive data on the connection. Returns the number of
                bytes actually received, 0 if the remote side has closed
                the connection, or ERROR on failure. If the socket is blocking,
                receive waits until there is data to be received.

                Returns number of bytes actually received, 0 on connection
                closure, or -1 on error

        ***********************************************************************/

        int receive (void[] buf, SocketFlags flags=SocketFlags.NONE)
        {
                if (!buf.length)
                     badArg ("Socket.receive :: target buffer has 0 length");

                return .recv(sock, buf.ptr, buf.length, cast(int)flags);
        }

        /***********************************************************************

                Receive data and get the remote endpoint Address. Returns
                the number of bytes actually received, 0 if the remote side
                has closed the connection, or ERROR on failure. If the socket
                is blocking, receiveFrom waits until there is data to be
                received.

        ***********************************************************************/

        int receiveFrom (void[] buf, SocketFlags flags, Address from)
        {
                if (!buf.length)
                     badArg ("Socket.receiveFrom :: target buffer has 0 length");

                assert(from.addressFamily() == family);
                int nameLen = from.nameLen();
                return .recvfrom(sock, buf.ptr, buf.length, cast(int)flags, from.name(), &nameLen);
        }

        /***********************************************************************

                ditto

        ***********************************************************************/

        int receiveFrom (void[] buf, Address from)
        {
                return receiveFrom(buf, SocketFlags.NONE, from);
        }

        /***********************************************************************

                ditto - assumes you connect()ed

        ***********************************************************************/

        int receiveFrom (void[] buf, SocketFlags flags = SocketFlags.NONE)
        {
                if (!buf.length)
                     badArg ("Socket.receiveFrom :: target buffer has 0 length");

                return .recvfrom(sock, buf.ptr, buf.length, cast(int)flags, null, null);
        }

        /***********************************************************************

                returns the length, in bytes, of the actual result - very
                different from getsockopt()

        ***********************************************************************/

        int getOption (SocketOptionLevel level, SocketOption option, void[] result)
        {
                int len = cast(int) result.length;
                if(Error == .getsockopt (sock, cast(int)level, cast(int)option, result.ptr, &len))
                   exception ("Unable to get socket option: ");
                return len;
        }

        /***********************************************************************

        ***********************************************************************/

        Berkeley* setOption (SocketOptionLevel level, SocketOption option, void[] value)
        {
                if(Error == .setsockopt (sock, cast(int)level, cast(int)option, value.ptr, cast(int) value.length))
                   exception ("Unable to set socket option: ");
                return this;
        }

        /***********************************************************************

                getter

        ***********************************************************************/

        bool blocking()
        {
                return !(fcntl(sock, F_GETFL, 0) & O_NONBLOCK);
        }

        /***********************************************************************

                setter

        ***********************************************************************/

        void blocking(bool yes)
        {
                int x = fcntl(sock, F_GETFL, 0);
                if(yes)
                   x &= ~O_NONBLOCK;
                else
                   x |= O_NONBLOCK;
                if(fcntl(sock, F_SETFL, x) is ERROR)
                   exception("Unable to set socket blocking: ");
                return;
        }

        /***********************************************************************

        ***********************************************************************/

        static void exception (istring msg)
        {
                throw new SocketException (msg ~ SysError.lookup(lastError));
        }

        /***********************************************************************

        ***********************************************************************/

        protected static void badArg (istring msg)
        {
                throw new IllegalArgumentException (msg);
        }
}



/*******************************************************************************


*******************************************************************************/

public abstract class Address
{
        public alias .sockaddr sockaddr;

        public alias .addrinfo addrinfo;

        abstract sockaddr*      name();
        abstract int            nameLen();

        /***********************************************************************

                Internal usage

        ***********************************************************************/

        private static ushort ntohs (ushort x)
        {
                return htons(x);
        }

        /***********************************************************************

                Internal usage

        ***********************************************************************/

        private static uint ntohl (uint x)
        {
                return htonl(x);
        }

        /***********************************************************************

                Internal usage

        ***********************************************************************/

        private static char[] fromInt (char[] tmp, int i)
        {
                size_t j = tmp.length;
                do {
                   tmp[--j] = cast(char)(i % 10 + '0');
                   } while (i /= 10);
                return tmp [j .. $];
        }

        /***********************************************************************

                Internal usage

        ***********************************************************************/

        private static int toInt (istring s)
        {
                uint value;

                foreach (c; s)
                         if (c >= '0' && c <= '9')
                             value = value * 10 + (c - '0');
                         else
                            break;
                return value;
        }

        /***********************************************************************

                Tango: added this common function

        ***********************************************************************/

        static void exception (istring msg)
        {
                throw new SocketException (msg);
        }

        /***********************************************************************

                Address factory

        ***********************************************************************/

        static Address create (sockaddr* sa)
        {
                switch  (sa.sa_family)
                        {
                        case AddressFamily.INET:
                             return new IPv4Address(sa);
                        case AddressFamily.INET6:
                             return new IPv6Address(sa);
                        default:
                             return null;
                        }
        }

        /***********************************************************************

        ***********************************************************************/

        static Address resolve (istring host, istring service = null,
                                AddressFamily af = AddressFamily.UNSPEC,
                                AIFlags flags = cast(AIFlags)0)
        {
                return resolveAll (host, service, af, flags)[0];
        }

        /***********************************************************************

        ***********************************************************************/

        static Address resolve (istring host, ushort port,
                                AddressFamily af = AddressFamily.UNSPEC,
                                AIFlags flags = cast(AIFlags)0)
        {
                return resolveAll (host, port, af, flags)[0];
        }

        /***********************************************************************

        ***********************************************************************/

        static Address[] resolveAll (istring host, istring service = null,
                                     AddressFamily af = AddressFamily.UNSPEC,
                                     AIFlags flags = cast(AIFlags)0)
        {
                Address[] retVal;

                addrinfo* info;
                addrinfo hints;
                hints.ai_flags = flags;
                hints.ai_family = (flags & AIFlags.PASSIVE && af == AddressFamily.UNSPEC) ? AddressFamily.INET6 : af;
                hints.ai_socktype = SocketType.STREAM;
                int error = getaddrinfo(toStringz(host), service.length == 0 ? null : toStringz(service), &hints, &info);
                if (error != 0)
                    throw new AddressException("couldn't resolve " ~ host);

                retVal.length = 16;
                retVal.length = 0;
                while (info)
                      {
                      if (auto addr = create(info.ai_addr))
                          retVal ~= addr;
                      info = info.ai_next;
                      }
                freeaddrinfo (info);
                return retVal;
        }

        /***********************************************************************

        ***********************************************************************/

        static Address[] resolveAll (istring host, ushort port,
                                     AddressFamily af = AddressFamily.UNSPEC,
                                     AIFlags flags = cast(AIFlags)0)
        {
                char[16] buf;
                return resolveAll (host, idup(fromInt(buf, port)), af, flags);
        }

        /***********************************************************************

        ***********************************************************************/

        static Address passive (istring service,
                                AddressFamily af = AddressFamily.UNSPEC,
                                AIFlags flags = cast(AIFlags)0)
        {
                return resolve (null, service, af, flags | AIFlags.PASSIVE);
        }

        /***********************************************************************

         ***********************************************************************/

        static Address passive (ushort port, AddressFamily af = AddressFamily.UNSPEC,
                                AIFlags flags = cast(AIFlags)0)
        {
                return resolve (null, port, af, flags | AIFlags.PASSIVE);
        }

        /***********************************************************************

        ***********************************************************************/

        istring toAddrString()
        {
                char[1025] host = void;
                // Getting name info. Don't look up hostname, returns
                // numeric name. (NIFlags.NUMERICHOST)
                getnameinfo (name, nameLen, host.ptr, host.length, null, 0, NIFlags.NUMERICHOST);
                return idup(fromStringz (host.ptr));
        }

        /***********************************************************************

         ***********************************************************************/

        istring toPortString()
        {
                char[32] service = void;
                // Getting name info. Returns port number, not
                // service name. (NIFlags.NUMERICSERV)
                getnameinfo (name, nameLen, null, 0, service.ptr, service.length, NIFlags.NUMERICSERV);
                foreach (i, c; service)
                         if (c == '\0')
                             return idup(service[0..i]);
                return null;
        }

        /***********************************************************************

        ***********************************************************************/

        override istring toString()
        {
                return toAddrString ~ ":" ~ toPortString;
        }

        /***********************************************************************

         ***********************************************************************/

        AddressFamily addressFamily()
        {
                return cast(AddressFamily)name.sa_family;
        }
}


/*******************************************************************************

*******************************************************************************/

public class UnknownAddress : Address
{
        sockaddr sa;

        /***********************************************************************

        ***********************************************************************/

        override sockaddr* name()
        {
                return &sa;
        }

        /***********************************************************************

        ***********************************************************************/

        override int nameLen()
        {
                return sa.sizeof;
        }

        /***********************************************************************

        ***********************************************************************/

        override AddressFamily addressFamily()
        {
                return cast(AddressFamily) sa.sa_family;
        }

        /***********************************************************************

        ***********************************************************************/

        override istring toString()
        {
                return "Unknown";
        }
}


/*******************************************************************************


*******************************************************************************/

public class IPv4Address : Address
{
        /***********************************************************************

        ***********************************************************************/

        enum
        {
                ADDR_ANY = 0,
                ADDR_NONE = cast(uint)-1,
                PORT_ANY = 0
        }

        /***********************************************************************

        ***********************************************************************/

        alias .sockaddr_in sockaddr_in;

        private sockaddr_in sin;

        /***********************************************************************

        ***********************************************************************/

        this ()
        {
                sin.sin_family = AddressFamily.INET;
        }

        /***********************************************************************

        ***********************************************************************/

        this (ushort port)
        {
                sin.sin_family = AddressFamily.INET;
                sin.sin_addr.s_addr = 0; //any, "0.0.0.0"
                sin.sin_port = htons(port);
        }

        /***********************************************************************

        ***********************************************************************/

        this (uint addr, ushort port)
        {
                sin.sin_family = AddressFamily.INET;
                sin.sin_addr.s_addr = htonl(addr);
                sin.sin_port = htons(port);
        }

        /***********************************************************************

                -port- can be PORT_ANY
                -addr- is an IP address or host name

        ***********************************************************************/

        this (istring addr, ushort port = PORT_ANY)
        {
                sin.sin_family = AddressFamily.INET;
                uint uiaddr = parse(addr);
                if (ADDR_NONE == uiaddr)
                   {
                   auto ih = new NetHost;
                   if (!ih.getHostByName(addr))
                      {
                      char[16] tmp = void;
                      exception ("Unable to resolve "~addr~":"~idup(fromInt(tmp, port)));
                      }
                   uiaddr = ih.addrList[0];
                   }
                sin.sin_addr.s_addr = htonl(uiaddr);
                sin.sin_port = htons(port);
        }

        /***********************************************************************

        ***********************************************************************/

        this (sockaddr* addr)
        {
                sin = *(cast(sockaddr_in*)addr);
        }

        /***********************************************************************

        ***********************************************************************/

        override sockaddr* name()
        {
                return cast(sockaddr*)&sin;
        }

        /***********************************************************************

        ***********************************************************************/

        override int nameLen()
        {
                return sin.sizeof;
        }

        /***********************************************************************

        ***********************************************************************/

        override AddressFamily addressFamily()
        {
                return AddressFamily.INET;
        }

        /***********************************************************************

        ***********************************************************************/

        ushort port()
        {
                return ntohs(sin.sin_port);
        }

        /***********************************************************************

        ***********************************************************************/

        uint addr()
        {
                return ntohl(sin.sin_addr.s_addr);
        }

        /***********************************************************************

        ***********************************************************************/

        override istring toAddrString()
        {
                char[16] buff = 0;
                return idup(fromStringz(inet_ntop(AddressFamily.INET,
                    &sin.sin_addr.s_addr, buff.ptr, 16)));
        }

        /***********************************************************************

        ***********************************************************************/

        override istring toPortString()
        {
                char[8] _port;
                return idup(fromInt (_port, port()));
        }

        /***********************************************************************

        ***********************************************************************/

        override istring toString()
        {
                return toAddrString() ~ ":" ~ toPortString();
        }

        /***********************************************************************

                -addr- is an IP address in the format "a.b.c.d"
                returns ADDR_NONE on failure

        ***********************************************************************/

        static uint parse(istring addr)
        {
                char[64] tmp;
                return ntohl(inet_addr(toStringz(addr, tmp)));
        }
}

/*******************************************************************************

*******************************************************************************/

unittest
{
    IPv4Address ia = new IPv4Address("63.105.9.61", 80);
    test!("==")(ia.toString(), "63.105.9.61:80"[], "Address not properly set");
    test!("==")(ia.sin.sin_family, AF_INET, "Family not properly set");
}

/*******************************************************************************

        IPv6 is the next-generation Internet Protocol version
        designated as the successor to IPv4, the first
        implementation used in the Internet that is still in
        dominant use currently.

        More information: http://ipv6.com/

        IPv6 supports 128-bit address space as opposed to 32-bit
        address space of IPv4.

        IPv6 is written as 8 blocks of 4 octal digits (16 bit)
        separated by a colon (":"). Zero block can be replaced by "::".

        For example:
        ---
        0000:0000:0000:0000:0000:0000:0000:0001
        is equal
        ::0001
        is equal
        ::1
        is analogue IPv4 127.0.0.1
        ---

        ---
        0000:0000:0000:0000:0000:0000:0000:0000
        is equal
        ::
        is analogue IPv4 0.0.0.0
        ---

        ---
        2001:cdba:0000:0000:0000:0000:3257:9652
        is equal
        2001:cdba::3257:9652
        ---

        IPv4 address can be submitted through IPv6 as ::ffff:xx.xx.xx.xx,
        where xx.xx.xx.xx 32-bit IPv4 addresses.

        ---
        ::ffff:51b0:ec6d
        is equal
        ::ffff:81.176.236.109
        is analogue IPv4 81.176.236.109
        ---

        The URL for the IPv6 address will be of the form:
        http://[2001:cdba:0000:0000:0000:0000:3257:9652]/

        If needed to specify a port, it will be listed after the
        closing square bracket followed by a colon.

        ---
        http://[2001:cdba:0000:0000:0000:0000:3257:9652]:8080/
        address: "2001:cdba:0000:0000:0000:0000:3257:9652"
        port: 8080
        ---

        IPv6Address can be used as well as IPv4Address.

        ---
        scope addr = new IPv6Address(8080);
        address: "::"
        port: 8080
        ---

        ---
        scope addr_2 = new IPv6Address("::1", 8081);
        address: "::1"
        port: 8081
        ---

        ---
        scope addr_3 = new IPv6Address("::1");
        address: "::1"
        port: PORT_ANY
        ---

        Also in the IPv6Address constructor can specify the service name
        or port as string

        ---
        scope addr_3 = new IPv6Address("::", "ssh");
        address: "::"
        port: 22 (ssh service port)
        ---

        ---
        scope addr_4 = new IPv6Address("::", "8080");
        address: "::"
        port: 8080
        ---

*******************************************************************************/

class IPv6Address : Address
{
protected:
        /***********************************************************************

        ***********************************************************************/

        alias .sockaddr_in6 sockaddr_in6;

        sockaddr_in6 sin;

        /***********************************************************************

         ***********************************************************************/

        this ()
        {
                sin.sin6_family = AddressFamily.INET6;
        }

        /***********************************************************************

        ***********************************************************************/

        this (sockaddr* sa)
        {
                sin = *cast(sockaddr_in6*)sa;
        }

        /***********************************************************************

        ***********************************************************************/

        override sockaddr* name()
        {
                return cast(sockaddr*)&sin;
        }

        /***********************************************************************

        ***********************************************************************/

        override int nameLen()
        {
                return sin.sizeof;
        }

 public:

        /***********************************************************************

        ***********************************************************************/

        override AddressFamily addressFamily()
        {
                return AddressFamily.INET6;
        }


        const ushort PORT_ANY = 0;

        /***********************************************************************

         ***********************************************************************/

        ushort port()
        {
                return ntohs(sin.sin6_port);
        }

        /***********************************************************************

                Create IPv6Address with zero address

        ***********************************************************************/

        this (int port)
        {
          this ("::", port);
        }

        /***********************************************************************

                -port- can be PORT_ANY
                -addr- is an IP address or host name

        ***********************************************************************/

        this (istring addr, int port = PORT_ANY)
        {
                addrinfo* info;
                addrinfo hints;
                hints.ai_family = AddressFamily.INET6;
                int error = getaddrinfo((addr ~ '\0').ptr, null, &hints, &info);
                if (error != 0)
                    exception("failed to create IPv6Address: ");

                sin = *cast(sockaddr_in6*)(info.ai_addr);
                sin.sin6_port = htons(cast(ushort) port);
        }

        /***********************************************************************

                -service- can be a port number or service name
                -addr- is an IP address or host name

        ***********************************************************************/

        this (istring addr, istring service)
        {
                addrinfo* info;
                addrinfo hints;
                hints.ai_family = AddressFamily.INET6;
                int error = getaddrinfo((addr ~ '\0').ptr, (service ~ '\0').ptr, &hints, &info);
                if (error != 0)
                    exception ("failed to create IPv6Address: ");
                sin = *cast(sockaddr_in6*)(info.ai_addr);
        }

        /***********************************************************************

        ***********************************************************************/

        ubyte[] addr()
        {
                return sin.sin6_addr.s6_addr;
        }

        /***********************************************************************

        ***********************************************************************/

        version (Posix)
        override istring toAddrString()
        {

                char[100] buff = 0;
                return idup(fromStringz(inet_ntop(AddressFamily.INET6, &sin.sin6_addr, buff.ptr, 100)));
        }

        /***********************************************************************

        ***********************************************************************/

        override istring toPortString()
        {
                char[8] _port;
                return idup(fromInt (_port, port()));
        }

        /***********************************************************************

        ***********************************************************************/

        override istring toString()
        {
                return "[" ~ toAddrString ~ "]:" ~ toPortString;
        }
}

/*******************************************************************************

*******************************************************************************/

unittest
{
    IPv6Address ia = new IPv6Address("7628:0d18:11a3:09d7:1f34:8a2e:07a0:765d", 8080);
    test!("==")(ia.toString(), "[7628:d18:11a3:9d7:1f34:8a2e:7a0:765d]:8080"[],
            "Address not properly set");
    test!("==")(ia.sin.sin6_family, AF_INET6, "Family not properly set"[]);
}

/*******************************************************************************


*******************************************************************************/

public class NetHost
{
        istring          name;
        istring[]        aliases;
        uint[]          addrList;

        /***********************************************************************

        ***********************************************************************/

        struct hostent
        {
                char* h_name;
                char** h_aliases;
                int h_addrtype;
                int h_length;
                char** h_addr_list;

                char* h_addr()
                {
                        return h_addr_list[0];
                }
        }

        /***********************************************************************

        ***********************************************************************/

        protected void validHostent(hostent* he)
        {
                if (he.h_addrtype != AddressFamily.INET || he.h_length != 4)
                    throw new SocketException("Address family mismatch.");
        }

        /***********************************************************************

        ***********************************************************************/

        void populate (hostent* he)
        {
                int i;
                char* p;

                auto mkey = fromStringz(he.h_name);
                name = assumeUnique(mkey);

                for (i = 0;; i++)
                    {
                    p = he.h_aliases[i];
                    if(!p)
                        break;
                    }

                if (i)
                   {
                   aliases = new istring[i];
                   for (i = 0; i != aliases.length; i++)
                   {
                        auto malias = fromStringz(he.h_aliases[i]);
                        aliases[i] = assumeUnique(malias);
                   }
                   }
                else
                   aliases = null;

                for (i = 0;; i++)
                    {
                    p = he.h_addr_list[i];
                    if(!p)
                        break;
                    }

                if (i)
                   {
                   addrList = new uint[i];
                   for (i = 0; i != addrList.length; i++)
                        addrList[i] = Address.ntohl(*(cast(uint*)he.h_addr_list[i]));
                   }
                else
                   addrList = null;
        }

        /***********************************************************************

        ***********************************************************************/

        bool getHostByName(istring name)
        {
                char[1024] tmp;

                auto he = gethostbyname(toStringz(name, tmp));
                if(!he)
                   return false;
                validHostent(he);
                populate(he);
                return true;
        }

        /***********************************************************************

        ***********************************************************************/

        bool getHostByAddr(uint addr)
        {
                uint x = htonl(addr);
                auto he = gethostbyaddr(&x, 4, cast(int)AddressFamily.INET);
                if(!he)
                    return false;
                validHostent(he);
                populate(he);
                return true;
        }

        /***********************************************************************

        ***********************************************************************/

        //shortcut
        bool getHostByAddr(istring addr)
        {
                char[64] tmp;

                uint x = inet_addr(toStringz(addr, tmp));
                auto he = gethostbyaddr(&x, 4, cast(int)AddressFamily.INET);
                if(!he)
                    return false;
                validHostent(he);
                populate(he);
                return true;
        }
}


/*******************************************************************************

*******************************************************************************/

// disabled because it expect working DNS resolver in the environment
version(none)
unittest
{
    NetHost ih = new NetHost;
    ih.getHostByName(Berkeley.hostName());
    assert(ih.addrList.length > 0);
    IPv4Address ia = new IPv4Address(ih.addrList[0], IPv4Address.PORT_ANY);
    assert(ih.getHostByAddr(ih.addrList[0]));
}

/*******************************************************************************

        a set of sockets for Berkeley.select()

*******************************************************************************/

public class SocketSet
{
        import ocean.stdc.config;

        struct timeval
        {
                c_long  seconds, microseconds;
        }

        private uint  nbytes; //Win32: excludes uint.size "count"
        private byte* buf;

        struct fd {}

        version (Posix)
        {
                import ocean.core.BitManip;

                uint nfdbits;
                socket_t _maxfd = 0;

                uint fdelt(socket_t s)
                {
                        return cast(uint)s / nfdbits;
                }


                uint fdmask(socket_t s)
                {
                        return 1 << cast(uint)s % nfdbits;
                }


                uint* first()
                {
                        return cast(uint*)buf;
                }

                public socket_t maxfd()
                {
                        return _maxfd;
                }
        }


        public:

        this (uint max)
        {
                version (Posix)
                {
                        if (max <= 32)
                            nbytes = 32 * uint.sizeof;
                        else
                            nbytes = cast(uint) (max * uint.sizeof);

                        buf = (new byte[nbytes]).ptr;
                        nfdbits = nbytes * 8;
                        //clear(); //new initializes to 0
                }
                else
                {
                        static assert(0);
                }
        }

        this (SocketSet o)
        {
                nbytes = o.nbytes;
                auto size = nbytes;

                version (Posix)
                        {
                        nfdbits = o.nfdbits;
                        _maxfd = o._maxfd;
                        }

                auto b = new byte[size];
                b[] = o.buf[0..size];
                buf = b.ptr;
        }

        this()
        {
                version (Posix)
                {
                        this(32);
                }
                else
                {
                        static assert(0);
                }
        }

        SocketSet dup()
        {
                return new SocketSet (this);
        }

        SocketSet reset()
        {
                version (Posix)
                {
                        buf[0 .. nbytes] = 0;
                        _maxfd = 0;
                }
                else
                {
                        static assert(0);
                }
                return this;
        }

        void add(socket_t s)
        {
                version (Posix)
                {
                        if (s > _maxfd)
                                _maxfd = s;

                        bts(cast(size_t*)&first[fdelt(s)], cast(size_t)s % nfdbits);
                }
                else
                {
                        static assert(0);
                }
        }

        void add(Berkeley* s)
        {
                add(s.handle);
        }

        void remove(socket_t s)
        {
                version (Posix)
                {
                        btr(cast(size_t*)&first[fdelt(s)], cast(size_t)s % nfdbits);

                        // If we're removing the biggest file descriptor we've
                        // entered so far we need to recalculate this value
                        // for the socket set.
                        if (s == _maxfd)
                        {
                                while (--_maxfd >= 0)
                                {
                                        if (isSet(_maxfd))
                                        {
                                                break;
                                        }
                                }
                        }
                }
                else
                {
                        static assert(0);
                }
        }

        void remove(Berkeley* s)
        {
                remove(s.handle);
        }

        int isSet(socket_t s)
        {
                version (Posix)
                {
                        //return bt(cast(uint*)&first[fdelt(s)], cast(uint)s % nfdbits);
                        int index = cast(uint)s % nfdbits;
                        return (cast(uint*)&first[fdelt(s)])[index / (uint.sizeof*8)] & (1 << (index & ((uint.sizeof*8) - 1)));
                }
                else
                {
                        static assert(0);
                }
        }

        int isSet(Berkeley* s)
        {
                return isSet(s.handle);
        }

        uint max()
        {
                return cast(uint) (nbytes / socket_t.sizeof);
        }

        fd* toFd_set()
        {
                return cast(fd*)buf;
        }

        /***********************************************************************

                SocketSet's are updated to include only those sockets which an
                event occured.

                Returns the number of events, 0 on timeout, or -1 on error

                for a connect()ing socket, writeability means connected
                for a listen()ing socket, readability means listening

                Winsock: possibly internally limited to 64 sockets per set

        ***********************************************************************/

        static int select (SocketSet checkRead, SocketSet checkWrite, SocketSet checkError, timeval* tv)
        {
                fd* fr, fw, fe;

                //make sure none of the SocketSet's are the same object
                if (checkRead)
                   {
                   assert(checkRead !is checkWrite);
                   assert(checkRead !is checkError);
                   }

                if (checkWrite)
                    assert(checkWrite !is checkError);

                fr = checkRead ? checkRead.toFd_set() : null;
                fw = checkWrite ? checkWrite.toFd_set() : null;
                fe = checkError ? checkError.toFd_set() : null;

                int result;

                version (Posix)
                {
                        socket_t maxfd = 0;

                        if (checkRead)
                                maxfd = checkRead.maxfd;

                        if (checkWrite && checkWrite.maxfd > maxfd)
                                maxfd = checkWrite.maxfd;

                        if (checkError && checkError.maxfd > maxfd)
                                maxfd = checkError.maxfd;

                        while ((result = .select (maxfd + 1, fr, fw, fe, tv)) == -1)
                        {
                                if(errno() != EINTR)
                                   break;
                        }
                }
                else
                {
                        static assert(0);
                }

                return result;
        }

        /***********************************************************************

                select with specified timeout

        ***********************************************************************/

        static int select (SocketSet checkRead, SocketSet checkWrite, SocketSet checkError, long microseconds)
        {
                timeval tv = {
                             cast(typeof(timeval.seconds)) (microseconds / 1000000),
                             cast(typeof(timeval.microseconds)) (microseconds % 1000000)
                             };
                return select (checkRead, checkWrite, checkError, &tv);
        }

        /***********************************************************************

                select with maximum timeout

        ***********************************************************************/

        static int select (SocketSet checkRead, SocketSet checkWrite, SocketSet checkError)
        {
                return select (checkRead, checkWrite, checkError, null);
        }
}


