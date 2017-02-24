/*******************************************************************************

    Base class for a non-blocking socket connection select client using a
    fiber/coroutine to suspend operation while waiting for the connection to be
    established and resume on that event (a Write event signifies that the
    connection has been established).

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.protocol.fiber.FiberSocketConnection;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.io.select.protocol.fiber.model.IFiberSelectProtocol;

import ocean.io.select.EpollSelectDispatcher;

import ocean.core.Array : copy;

import ocean.sys.socket.AddressIPSocket,
       ocean.sys.socket.InetAddress,
       ocean.sys.socket.IPSocket: IIPSocket;


import ocean.io.select.protocol.generic.ErrnoIOException: SocketError;

import ocean.stdc.posix.sys.socket: SOL_SOCKET, IPPROTO_TCP, SO_KEEPALIVE;

import core.stdc.errno: errno, EINPROGRESS, EINTR, EALREADY, EISCONN;

debug ( EpollTiming ) import ocean.time.StopWatch;
debug ( ISelectClient )
{
    import ocean.io.Stdout : Stderr;
    import ocean.stdc.stringz;
}



public class FiberSocketConnection ( bool IPv6 = false ) : IFiberSocketConnection
{
    /**************************************************************************

        Alias of the address struct type.

     **************************************************************************/

    alias .InetAddress!(IPv6) InetAddress;

    /**************************************************************************

        Alias of the binary address type, sockaddr_in for IPv4 (IPv6 = false)
        or sockaddr_in6 for IPv6 (IPv6 = true).

     **************************************************************************/

    alias InetAddress.Addr InAddr;

    /**************************************************************************

        Socket

     **************************************************************************/

    alias AddressIPSocket!(IPv6) IPSocket;

    protected IPSocket socket;

    /**************************************************************************

        Constructor.

        Params:
            socket = IPSocket instance to use internally
            fiber = fiber to be suspended when socket connection does not
                immediately succeed or fail

     **************************************************************************/

    public this ( IPSocket socket, SelectFiber fiber )
    {
        this.socket = socket;

        super(this.socket, fiber);
    }

    /**************************************************************************

        Constructor.

        warning_e and socket_error may be the same object.

        Params:
            socket       = IPSocket instance to use internally
            fiber        = fiber to be suspended when socket connection does not
                           immediately succeed or fail
            warning_e    = exception to be thrown when the remote hung up
            socket_error = exception to be thrown on socket error

     **************************************************************************/

    public this ( IPSocket socket, SelectFiber fiber,
                  IOWarning warning_e, SocketError socket_error )
    {
        super(this.socket = socket, fiber, warning_e, socket_error);
    }

    /**************************************************************************

        Attempts to connect to the remote host, suspending the fiber if
        establishing the connection does not immediately succeed or fail. If a
        connection to the same address and port is already established, the
        Already flag is set in the return value. If a connection to a different
        address and port is already established, this connection is closed and a
        new connection is opened.

        Params:
            address = remote IP address
            port    = remote TCP port
            force   = false: don't call connect() if currently connected to the
                      same address and port; true: always call connect()
        Returns:
            ConnectionStatus.Connected if the connection was newly established
            or ConnectionStatus.Connected | ConnectionStatus.Already if the
            connection was already established.

        Throws:
            - SocketError (IOException) on fatal I/O error,
            - IOWarning if the remote hung up.

     **************************************************************************/

    override public ConnectionStatus connect ( cstring address, ushort port, bool force = false )
    {
        if (!this.sameAddress(address, port))
        {
            this.disconnect();
        }

        return this.connect_(!this.socket.connect(address, port), force);
    }

    /***************************************************************************

        Ditto.

        Params:
            address = remote address
            force   = false: don't call connect() if currently connected to the
                      same address and port; true: always call connect()

        Returns:
            see connect() above.

    ***************************************************************************/

    public ConnectionStatus connect ( InAddr address, bool force = false )
    {
        if (this.in_addr != address)
        {
            this.disconnect();
        }

        return this.connect_(!this.socket.connect(address), force);
    }

    /**************************************************************************

        Returns:
            the remote address of the connected socket, or the last attempted
            connection, or an empty address if no connection has been attempted

     **************************************************************************/

    public InAddr in_addr ( )
    {
        return this.connected_? this.socket.in_addr : InetAddress.addr_init;
    }

    /***************************************************************************

        Returns:
            the remote IP address of the connected socket, or the last attempted
            connection, or "" if no connection has been attempted

    ***************************************************************************/

    override protected cstring address_ ( )
    {
        return this.socket.address;
    }

    /***************************************************************************

        Returns:
            the remote TCP port of the connected socket, or the last attempted
            connection, or ushort.init if no connection has been attempted

    ***************************************************************************/

    override protected ushort port_ ( )
    {
        return this.socket.port;
    }

    /***************************************************************************

        Compares ip_address_str and port with the current address and port.

        Params:
            ip_address_str = string with the IP address to compare with the
                             current address
            port           = port to compare with the current

        Returns:
            true if ip_address_str and port are the same as the current or false
            if not.

        Throws:
            SocketError if ip_address_str does not contain a valid IP address.

     ***************************************************************************/

    public bool sameAddress ( InAddr addr )
    {
        return addr == this.socket.in_addr;
    }

    /***************************************************************************

        Compares ip_address_str and port with the current address and port.

        Params:
            ip_address_str = string with the IP address to compare with the
                             current address
            port           = port to compare with the current

        Returns:
            true if ip_address_str and port are the same as the current or false
            if not.

        Throws:
            SocketError if ip_address_str does not contain a valid IP address.

    ***************************************************************************/

    public bool sameAddress ( cstring ip_address_str, ushort port )
    {
        InetAddress address;

        this.socket_error.enforce(address.inet_pton(ip_address_str) == 1,
            "invalid IP address");

        address.port = port;

        return this.sameAddress(address.addr);
    }
}

///
unittest
{
    alias FiberSocketConnection!(true) IPV6;
    alias FiberSocketConnection!(false) IPV4;
}


public class IFiberSocketConnection : IFiberSelectProtocol
{
    /**************************************************************************

        This alias for chainable methods

     **************************************************************************/

    public alias typeof (this) This;

    /**************************************************************************

        Connection status as returned by connect() and disconnect().

     **************************************************************************/

    public enum ConnectionStatus : uint
    {
        Disconnected = 0,
        Connected    = 1 << 0,
        Already      = 1 << 1
    }

    /**************************************************************************

        Socket

     **************************************************************************/

    protected IIPSocket socket;

    /**************************************************************************

        Socket error exception

     **************************************************************************/

    private SocketError socket_error;

    /**************************************************************************

        Current connection status

     **************************************************************************/

    protected bool connected_ = false;

    /**************************************************************************

        Count of the number of times transmit() has been invoked since the call
        to super.transmitLoop.

     **************************************************************************/

    private uint transmit_calls;

    /**************************************************************************

        Delegate which is called (in EpollTiming debug mode) after a socket
        connection is established.

        FIXME: the logging of connection times was intended to be done directly
        in this module, not via a delegate, but dmd bugs with varargs made this
        impossible. The delegate solution is ok though.

     **************************************************************************/

    debug ( EpollTiming )
    {
        private alias void delegate ( ulong microsec ) ConnectionTimeDg;
        public ConnectionTimeDg connection_time_dg;
    }

    /**************************************************************************

        Constructor.

        warning_e and socket_error may be the same object.

        Params:
            socket       = IPSocket instance to use internally
            fiber        = fiber to be suspended when socket connection does not
                           immediately succeed or fail
            warning_e    = exception to be thrown when the remote hung up
            socket_error = exception to be thrown on socket error

     **************************************************************************/

    protected this ( IIPSocket socket, SelectFiber fiber,
                     IOWarning warning_e, SocketError socket_error )
    {
        this.socket = socket;

        this.socket_error = socket_error;

        super(socket, Event.EPOLLOUT, fiber, warning_e, socket_error);
    }

    /**************************************************************************

        Constructor.

        Params:
            socket       = IPSocket instance to use internally
            fiber        = fiber to be suspended when socket connection does not
                           immediately succeed or fail

     **************************************************************************/

    protected this ( IIPSocket socket, SelectFiber fiber )
    {
        this(socket, fiber, new IOWarning(socket), new SocketError(socket));
    }

    /**************************************************************************

        Returns:
            true if the socket is currently connected or false if not.

     **************************************************************************/

    public bool connected ( )
    {
        return this.connected_;
    }

    /***************************************************************************

        Returns:
            the IP address of the connected socket, or the last attempted
            connection, or "" if no connection has been attempted

     ***************************************************************************/

    public cstring address ( )
    {
        return this.connected_? this.address_ : "";
    }

    /***************************************************************************

        Returns:
            the TCP port of the connected socket, or the last attempted
            connection, or ushort.init if no connection has been attempted

     ***************************************************************************/

    public ushort port ( )
    {
        return this.connected_? this.port_ : ushort.init;
    }

    /**************************************************************************

        Attempts to connect to the remote host, suspending the fiber if
        establishing the connection does not immediately succeed or fail. If a
        connection to the same address and port is already established, the
        Already flag is set in the return value. If a connection to a different
        address and port is already established, this connection is closed and a
        new connection is opened.

        Params:
            address = remote IP address
            port    = remote TCP port
            force   = false: don't call connect() if currently connected to the
                      same address and port; true: always call connect()

        Returns:
            ConnectionStatus.Connected if the connection was newly established
            or ConnectionStatus.Connected | ConnectionStatus.Already if the
            connection was already established.

        Throws:
            - SocketError (IOException) on fatal I/O error,
            - IOWarning if the remote hung up.

     **************************************************************************/

    abstract public ConnectionStatus connect ( cstring address, ushort port, bool force = false );

    /**************************************************************************

        Disconnects from provided address (if connected).

        Params:
            force = false: disconnect only if connected; true: force disconnect

        Returns:
            the connection status before disconnecting.

     **************************************************************************/

    public ConnectionStatus disconnect ( bool force = false )
    out
    {
        assert (!this.connected_);
    }
    body
    {
        if (this.connected_ || force)
        {
            this.onDisconnect();
            this.socket.shutdown();
            this.socket.close();
        }

        scope (exit) this.connected_ = false;

        with (ConnectionStatus) return this.connected_?
                                    Disconnected :
                                    Already | Disconnected;
    }

    /**************************************************************************

        Establishes a non-blocking socket connection according to the POSIX
        specification for connect():

            "If the connection cannot be established immediately and O_NONBLOCK
            is set for the file descriptor for the socket, connect() shall fail
            and set errno to [EINPROGRESS], but the connection request shall not
            be aborted, and the connection shall be established asynchronously.
            [...]
            When the connection has been established asynchronously, select()
            and poll() shall indicate that the file descriptor for the socket is
            ready for writing."

        Calls connect_syscall, which should forward to connect() to establish a
        connection. If connect_syscall returns false, errno is evaluated to
        obtain the connection status.
        If it is EINPROGRESS (or EINTR, see below) the fiber is suspended so
        that this method returns when the socket is ready for writing or throws
        when a connection error was detected.

        Params:
            connect_syscall = should call connect() and return true if connect()
                              returns 0 or false otherwise

            force           = false: don't call connect_syscall if currently
                              connected to the same address and port; true:
                              always call connect_syscall

        Returns:
            - ConnectionStatus.Connected if the connection was newly
              established, either because connect_syscall returned true or after
              the socket became ready for writing,
            - ConnectionStatus.Connected | ConnectionStatus.Already if connect()
              failed with EISCONN.

        Throws:
            - SocketError (IOException) if connect_syscall fails with an error
              other than EINPROGRESS/EINTR or EISCONN or if a socket error was
              detected,
            - IOWarning if the remote hung up.

        Out:
            The socket is connected, the returned status is never Disconnected.

        Note: The POSIX specification says about connect() failing with EINTR:

            "If connect() is interrupted by a signal that is caught while
            blocked waiting to establish a connection, connect() shall fail and
            set errno to EINTR, but the connection request shall not be aborted,
            and the connection shall be established asynchronously."

        It remains unclear whether a nonblocking connect() can also fail with
        EINTR or not. Assuming that, if it is possible, it has the same meaning
        as for blocking connect(), we handle EINTR in the same way as
        EINPROGRESS. TODO: Remove handling of EINTR or this note when this is
        clarified.

     **************************************************************************/

    protected ConnectionStatus connect_ ( lazy bool connect_syscall, bool force )
    out (status)
    {
        assert (this.connected_);
        assert (status);
    }
    body
    {
        // Create a socket if it is currently closed.
        if (this.socket.fileHandle < 0)
        {
            this.connected_ = false;

            this.socket_error.assertExSock(this.socket.tcpSocket(true) >= 0,
                "error creating socket", __FILE__, __LINE__);

            this.initSocket();
        }

        if (!this.connected_ || force)
        {
            debug ( EpollTiming )
            {
                StopWatch sw;
                sw.start;

                scope ( success )
                {
                    if ( this.connection_time_dg )
                    {
                        this.connection_time_dg(sw.microsec);
                    }
                }
            }

            if ( connect_syscall )
            {
                debug ( ISelectClient ) Stderr.formatln("[{}:{}]: Connected to socket",
                    this.address, this.port).flush();
                this.connected_ = true;
                return ConnectionStatus.Connected;
            }
            else
            {
                int errnum = .errno;

                debug ( ISelectClient )
                {
                    Stderr.formatln("[{}:{}]: {}",
                        this.address_, this.port_, fromStringz(this.socket_error.strerror(errnum))).flush();
                }

                switch (errnum)
                {
                    case EISCONN:
                        this.connected_ = true;
                        return ConnectionStatus.Already;

                    case EINTR, // TODO: Might never be reported, see note above.
                         EINPROGRESS,
                         EALREADY:
                         debug ( ISelectClient )
                         {
                             Stderr.formatln("[{}:{}]: waiting for the socket to become writable",
                                 this.address_, this.port_).flush();

                             scope (failure) Stderr.formatln("[{}:{}]: error while waiting for the socket to become writable",
                                                            this.address_, this.port_).flush();

                             scope (success) Stderr.formatln("[{}:{}]: socket has become writable",
                                                            this.address_, this.port_).flush();
                         }
                        this.transmit_calls = 0;
                        this.transmitLoop();
                        this.connected_ = true;
                        return ConnectionStatus.Connected;

                    default:
                        throw this.socket_error.setSock(errnum,
                            "error establishing connection", __FILE__, __LINE__);
                }
            }
        }
        else
        {
            return ConnectionStatus.Already;
        }
    }

    /***************************************************************************

        Returns:
            the IP address of the connected socket, or the last attempted
            connection, or "" if no connection has been attempted

     ***************************************************************************/

    abstract protected cstring address_ ( );

    /***************************************************************************

        Returns:
            the TCP port of the connected socket, or the last attempted
            connection, or ushort.init if no connection has been attempted

     ***************************************************************************/

    abstract protected ushort port_ ( );

    /***************************************************************************

        Called just before the socket is connected. The base class
        implementation does nothing, but derived classes may override to add any
        desired initialisation logic.

    ***************************************************************************/

    protected void initSocket ( )
    {
    }

    /**************************************************************************

        Disconnection cleanup handler for a subclass

     **************************************************************************/

    protected void onDisconnect ( )
    {
    }

    /***************************************************************************

        Called from super.transmitLoop() in two circumstances:
            1. Upon the initial call to transmitLoop() in connect(), above.
            2. After an epoll wait, upon receipt of one or more registered
               events.

        Params:
            events = events reported for socket

        Returns:
            Upon first invocation (which occurs automatically when
            super.transmitLoop() is called, in connect(), above):
                * false if connect() returned a code denoting either an error or
                  a successful connection (meaning there's no need to go into
                  epoll wait).
                * true otherwise, to go into epoll wait.

            Upon second invocation:
                * false to not return to epoll wait.

    ***************************************************************************/

    protected override bool transmit ( Event events )
    in
    {
        assert(this.transmit_calls <= 1);
    }
    body
    {
        scope ( exit ) this.transmit_calls++;

        if ( this.transmit_calls > 0 )
        {
            this.warning_e.enforce(!(events & Event.EPOLLHUP),
                                   "Hangup on connect");
            return false;
        }
        else
        {
            return true;
        }
    }
}
