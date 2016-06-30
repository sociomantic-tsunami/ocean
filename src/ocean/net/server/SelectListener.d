/******************************************************************************

    Server socket listener using multiplexed non-blocking socket I/O

    Creates a server socket and a pool of connection handlers and registers
    the server socket for incoming connection in a provided SelectDispatcher
    instance. When a connection comes in, takes an IConnectionHandler instance
    from the pool and assigns the incoming connection to the handler's socket.

    Usage example:

    ---

        import ocean.io.select.EpollSelector;
        import ocean.io.select.SelectDispatcher;

        import ocean.net.server.SelectListener;
        import ocean.net.server.connection.IConnectionHandler;

        class MyConnectionHandler : IConnectionHandler
        {
            this ( SelectDispatcher dispatcher, FinalizeDg finalize_dg,         // for IConnectionHandler constructor
                   int x, char[] str )                                          // additional for this constructor
            {
                super(dispatcher, finalize_dg);                                 // mandatory IConnectionHandler
                                                                                // constructor call
                // ...
            }
        }

        void main ( )
        {
            char[] address = "localhost";
            ushort port    = 4711;

            int x = 4;
            char[] str = "Hello World!";

            scope dispatcher = new SelectDispatcher(new EpollSelector,
                                                    EpollSelector.DefaultSize,
                                                    EpollSelector.DefaultMaxEvents);

            scope listener = new SelectListener!(MyConnectionHandler,
                                                 int, char[])                   // types of additional MyConnectionHandler
                                                (address, port, dispatcher,     // constructor arguments x and str
                                                 x, str);
        }

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.net.server.SelectListener;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.transition;

import ocean.io.select.client.model.ISelectClient;
import ocean.net.server.connection.IConnectionHandler;
import ocean.net.server.connpool.SelectListenerPool;
import ocean.net.server.connpool.ISelectListenerPoolInfo;

import ocean.util.container.pool.model.IPoolInfo;

import ocean.text.convert.Format;

import ocean.stdc.errno:            errno;

import ocean.sys.socket.model.ISocket;

import ocean.io.select.protocol.generic.ErrnoIOException: SocketError;


import ocean.util.log.Log;

/*******************************************************************************

    Static module logger

*******************************************************************************/

static private Logger log;
static this ( )
{
    log = Log.lookup("ocean.net.server.SelectListener");
}

/******************************************************************************

    SelectListener base class

    Contains all base functionality which is not related to the particular
    IConnectionHandler subclass used in SelectListener.

 ******************************************************************************/

abstract class ISelectListener : ISelectClient
{
    import ocean.stdc.posix.sys.socket: accept, SOL_SOCKET, SO_ERROR,
                                        SO_REUSEADDR, sockaddr;
    import ocean.stdc.posix.netinet.in_: SOCK_STREAM;
    import ocean.stdc.posix.unistd:     close;

    /**************************************************************************

        Socket, memorises the address most recently passed to bind() or
        connect() or obtained by accept().

     **************************************************************************/

    private ISocket socket;

    /**************************************************************************

        Termination flag; true prevents accepting new connections

     **************************************************************************/

    private bool terminated = false;

    /**************************************************************************

        Exception instance thrown in case of socket errors.

     **************************************************************************/

    private SocketError e;

    /**************************************************************************

        Constructor

        Creates the server socket -- a streaming socket of the family (aka
        "domain") specified in `address` and the protocol according to
        `protocol` -- and registers it for incoming connections.

        `address.sa_family` and `protocol` are passed to `socket(2)` together
        with the `SOCK_STREAM` type, so the socket family defined by
        `address.sa_family` is required to support streaming, and `protocol`
        needs to be a streaming protocol. Socket families supporting streaming
        include IPv4/IPv6 and UNIX domain sockets (`AF_LOCAL`).
        `protocol == 0` makes `socket(2)` pick the default streaming protocol
        for `address.sa_family`. For IPv4/IPv6 the default protocol is TCP.
        UNIX domain sockets and some other families support only one streaming
        protocol so for those the default is unambiguous.

        Standards:
        Posix = http://pubs.opengroup.org/onlinepubs/9699919799/functions/socket.html
        Linux = http://linux.die.net/man/2/socket

        Params:
            address    = the socket address and family, must support streaming
            socket     = the server socket
            backlog    = the maximum length to which the queue of pending
                connections for sockfd may grow. If a connection request arrives
                when the queue is full, the client may receive an error with an
                indication of ECONNREFUSED or, if the underlying protocol
                supports retransmission, the request may be ignored so that a
                later reattempt at connection succeeds.
                (from http://linux.die.net/man/2/listen)
            protocol   = the socket protocol, for a streaming socket of the
                family specified in address, or 0 to use the default protocol
                for a streaming socket of the specified family

     **************************************************************************/

    protected this ( sockaddr* address, ISocket socket, int backlog = 32,
        int protocol= 0)
    {
        this.socket = socket;

        this.e = new SocketError(this.socket);

        // SOCK_NONBLOCK is a Linux extension, which can be combined with the
        // actual second argument (SOCK_STREAM) in order to mark the
        // I/O operations to the socket as non-blocking.
        this.e.enforce(
            this.socket.socket(address.sa_family,
                SOCK_STREAM | SocketFlags.SOCK_NONBLOCK,
                protocol) >= 0,
            "error creating socket"
        );

        this.e.enforce(
            !this.socket.setsockoptVal(SOL_SOCKET, SO_REUSEADDR, true),
            "error enabling reuse of address"
        );

        this.e.assertExSock(!this.socket.bind(address),
                            "error binding socket", __FILE__, __LINE__);

        this.e.assertExSock(!this.socket.listen(backlog),
                            "error listening on socket", __FILE__, __LINE__);
    }

    /**************************************************************************

        Implements ISelectClient abstract method.

        Returns:
            events to register the conduit for.

     **************************************************************************/

    public override Event events ( )
    {
        return Event.EPOLLIN;
    }

    /**************************************************************************

        Implements ISelectClient abstract method.

        Returns:
            conduit's OS file handle (fd)

     **************************************************************************/

    public override Handle fileHandle ( )
    {
        return this.socket.fileHandle;
    }

    /**************************************************************************

        I/O event handler

        Called from SelectDispatcher during event loop.

        Params:
             event = identifier of I/O event that just occured on the device

        Returns:
            true if the handler should be called again on next event occurrence
            or false if this instance should be unregistered from the
            SelectDispatcher (this is effectively a server shutdown).

        TODO: accept() could be called in a loop in this method, in order to
        accept as many connections as possible each time the EPOLLIN event fires
        for the listening socket

     **************************************************************************/

    final override bool handle ( Event event )
    {
        if (!this.terminated)
        {
            try
            {
                IConnectionHandler handler = this.getConnectionHandler();
                this.acceptConnection(handler);
            }
            catch
            {
                /* Catch an exception (or object) thrown by
                   getConnectionHandler() to prevent it from falling through
                   to the dispatcher which would unregister the server socket. */
                this.declineConnection();
            }
        }

        return !this.terminated;
    }

    /**************************************************************************

        Closes the server socket and sets this instance to terminated mode.

        TODO: Make it possible to reopen the server socket and resume operation?

        Returns:
            true if this instance was already in to terminated mode or false
            otherwise

     **************************************************************************/

    final bool terminate ( )
    {
        if (!this.terminated)
        {
            this.terminated = true;

            try
            {
                this.e.enforce(
                    !this.socket.shutdown(),
                    "error on socket shutdown"
                );
            }
            finally
            {
                this.socket.close();
            }
            return false;
        }

        return true;
    }

    /**************************************************************************

        Returns:
            information interface to the connections pool

     **************************************************************************/

    abstract IPoolInfo poolInfo ( );

    /**************************************************************************

        Sets the limit of the number of connections. 0 disables the limitation.

        Notes:
            - If limit is set to something other than 0, limit connection
              handler objects will be created (so set it to a realistic value).
            - If not 0, limit must be at least the number of currently busy
              connections.

        Returns:
            connection limit

     **************************************************************************/

    abstract size_t connection_limit ( size_t limit ) ;

    /**************************************************************************

        Returns:
            the limit of the number of connections or 0 if limitation is
            disabled.

     **************************************************************************/

    public size_t connection_limit ( )
    {
        auto n = this.poolInfo.limit;

        return (n == n.max)? 0 : n;
    }

    /**************************************************************************

        Closes all connections and terminates the listener.

     **************************************************************************/

    abstract public void shutdown ( );

    /**************************************************************************

        Obtains a connection handler instance from the pool.

        Returns:
            connection handler

     **************************************************************************/

    abstract protected IConnectionHandler getConnectionHandler ( );

    /**************************************************************************

        Accepts the next pending incoming client connection and assigns it to
        a connection handler.

        Params:
            handler = handler to assign connection to

     **************************************************************************/

    private void acceptConnection ( IConnectionHandler handler )
    {
        try
        {
            handler.assign(this.socket);

            handler.handleConnection();
        }
        catch (Exception e)
        {
            /* Catch an exception thrown by accept() or handleConnection()
               (or noDelay()/blocking()) to prevent it from falling through
               to the select dispatcher which would unregister the server
               socket.

               'Too many open files' will be caught here.

               FIXME: If noDelay() or blocking() fails, the handler will
               incorrectly assume that the connection is not open and will
               not close it. Is this a relevant case? */
            handler.error(e);   // will never throw exceptions

            handler.finalize();
        }
    }

    /**************************************************************************

        Accepts the next pending incoming client connection and closes it.

     **************************************************************************/

    private void declineConnection ( )
    {
        // This is using the C binding
        if (close(accept(this.socket.fileHandle, null, null))) // returns non-zero on failure
        {
            .errno = 0;
        }
    }
}

/******************************************************************************

    SelectListener class template

    The additional T constructor argument parameters must appear after those for
    the mandatory IConnectionHandler constructor.

    Template_Params:
        T    = connection handler class
        Args = additional constructor arguments for T

    TODO: try using the non-auto ctor pool, for template simplicity!

 ******************************************************************************/

public class SelectListener ( T : IConnectionHandler, Args ... ) : ISelectListener
{
    /**************************************************************************

        ObjectPool of connection handlers

     **************************************************************************/

    private alias SelectListenerPool!(T, Args) ConnPool;

    private ConnPool receiver_pool;

    /**************************************************************************

        String buffer used for connection logging.

     **************************************************************************/

    private mstring connection_log_buf;

    /**************************************************************************

        Constructor

        Creates the server socket and registers it for incoming connections.

        Params:
            address    = the addres of the socket
            socket     = the server socket
            dispatcher = SelectDispatcher instance to use
            args       = additional T constructor arguments, might be empty
            backlog    = (see ISelectListener ctor)

     **************************************************************************/

    public this ( sockaddr* address, ISocket socket, Args args, int backlog = 32 )
    {
        super(address, socket, backlog);

        this.receiver_pool = new ConnPool(&this.returnToPool, args);
    }

    /**************************************************************************

        Obtains a connection handler instance from the pool.

        Returns:
            connection handler

     **************************************************************************/

    protected override IConnectionHandler getConnectionHandler ( )
    {
        return this.receiver_pool.get();
    }

    /**************************************************************************

        Sets the limit of the number of connections. 0 disables the limitation.

        Notes:
            - If limit is set to something other than 0, limit connection
              handler objects will be created (so set it to a realistic value).
            - If not 0, limit must be at least the number of currently busy
              connections.

        Returns:
            limit

     **************************************************************************/

    public override size_t connection_limit ( size_t limit )
    in
    {
        assert (!(limit && limit < this.poolInfo.num_busy),
                typeof(this).stringof ~ ".connection_limit: limit already exceeded");
    }
    body
    {
        if (limit)
        {
            this.receiver_pool.setLimit(limit);
        }
        else
        {
            this.receiver_pool.limited = false;
        }

        return limit;
    }

    /**************************************************************************

        (Overriding wrapper to fix method matching.)

        Returns:
            new limit of number of connections or 0 if unlimited.

     **************************************************************************/

    public override size_t connection_limit ( )
    {
        return super.connection_limit;
    }

    /**************************************************************************

        Minimizes the connection pool to n connections by deleting idle
        connection objects. If more than n connections are currently busy,
        all idle connections are deleted.

        Params:
            n = minimum number of connection objects to keep in the pool.

        Returns:
            the number of connection object in the pool after minimizing, which
            is the greater of n and the number of currently busy connections.

     **************************************************************************/

    public size_t minimize ( uint n = 0 )
    out (still_existent)
    {
        assert (still_existent >= n);
    }
    body
    {
        size_t limit = this.receiver_pool.limit,
               busy = this.receiver_pool.num_busy;

        scope (exit) this.receiver_pool.setLimit(limit);

        return this.receiver_pool.setLimit((n > busy)? n : busy);
    }

    /**************************************************************************

        Returns:
            information interface to the connections pool

     **************************************************************************/

    public override ISelectListenerPoolInfo poolInfo ( )
    {
        return this.receiver_pool;
    }

    /***************************************************************************

        Writes connection information to log file.

    ***************************************************************************/

    public void connectionLog ( )
    {
        auto conns = this.poolInfo;

        log.info("Connection pool: {} busy, {} idle", conns.num_busy,
            conns.num_idle);

        foreach ( i, conn; conns )
        {
            this.connection_log_buf.length = 0;
            Format.format(this.connection_log_buf, "{}: ", i);

            conn.formatInfo(this.connection_log_buf);

            log.info(this.connection_log_buf);
        }
    }

    /**************************************************************************

        Closes all connections and terminates the listener.

     **************************************************************************/

    public override void shutdown ( )
    {
        scope busy_connections = this.receiver_pool.new BusyItemsIterator;
        foreach ( busy_connection; busy_connections )
        {
            /* FIXME: calling finalize here will cause errors in any connection
             * handlers which are currently selected in epoll, as they will
             * subsequently attempt to finalize themselves again.
             *
             * In practice this is of little import however, as the whole server
             * is being shut down. It may be nice to find a clean way to avoid
             * this though.
             */
            busy_connection.finalize();
        }

        super.terminate();
    }

    /**************************************************************************

        Called as the finalizer of class T. Returns connection into the object
        pool.

        Params:
            connection = connection hander instance to return into pool

     **************************************************************************/

    private void returnToPool ( IConnectionHandler connection )
    in
    {
        assert (cast (T) connection !is null,
                typeof(this).stringof ~ ".returnToPool: connection is null");
    }
    body
    {
        debug ( ConnectionHandler )
            log.trace("[{}]: Returning to pool", connection.connection_id);

        this.receiver_pool.recycle(cast (T) connection);
    }
}
