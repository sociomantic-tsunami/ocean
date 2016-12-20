/*******************************************************************************

    Base class for a connection handler for use with SelectListener, using
    Fibers.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.net.server.connection.IFiberConnectionHandler;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.io.select.protocol.fiber.model.IFiberSelectProtocol,
       ocean.io.select.protocol.fiber.FiberSelectReader,
       ocean.io.select.protocol.fiber.FiberSelectWriter,
       ocean.io.select.protocol.fiber.BufferedFiberSelectWriter,
       ocean.io.select.protocol.generic.ErrnoIOException: IOWarning;

import ocean.net.server.connection.IConnectionHandler;

import ocean.sys.socket.model.ISocket;
import ocean.sys.socket.AddressIPSocket;
import ocean.sys.socket.model.IAddressIPSocketInfo;

import ocean.io.select.fiber.SelectFiber;
import ocean.util.container.pool.model.IResettable;

import ocean.sys.Epoll : epoll_event_t;

import ocean.text.convert.Format;

debug ( ConnectionHandler ) import ocean.io.Stdout : Stderr;


/*******************************************************************************

    Fiber connection handler base class -- creates a socket and a fiber
    internally, but does not contain reader / writer instances.

*******************************************************************************/

abstract class IFiberConnectionHandlerBase : IConnectionHandler
{
    /***************************************************************************

        Default fiber stack size (16K in 64-bit builds, 8K in 32-bit builds).

    ***************************************************************************/

    public static size_t default_stack_size = size_t.sizeof * 2 * 1024;

    /***************************************************************************

        Exception type alias. If handle() catches exceptions, it must rethrow
        these.

    ***************************************************************************/

    protected alias SelectFiber.KilledException KilledException;

    /***************************************************************************

        Fiber to handle an single connection.

    ***************************************************************************/

    protected SelectFiber fiber;

    /***************************************************************************

        Constructor

        Connects the socket, the asynchronous reader and writer, and the
        provided epoll select dispatcher.

        Params:
            epoll       = epoll select dispatcher
            stack_size  = fiber stack size
            socket      = the socket
            finalize_dg = user-specified finalizer, called when the connection
                          is shut down
            error_dg    = user-specified error handler, called when a connection
                          error occurs

    ***************************************************************************/

    protected this ( EpollSelectDispatcher epoll,
                     size_t stack_size,
                     ISocket socket,
                     FinalizeDg finalize_dg = null,
                     ErrorDg error_dg = null )
    {
        super(socket, finalize_dg, error_dg);

        this.fiber = new SelectFiber(epoll, &this.handleConnection_, stack_size);
    }

    /***************************************************************************

        Constructor, uses the default fiber stack size.

        Connects the socket, the asynchronous reader and writer, and the
        provided epoll select dispatcher.

        Params:
            epoll       = epoll select dispatcher
            socket      = the socket
            finalize_dg = user-specified finalizer, called when the connection
                          is shut down
            error_dg    = user-specified error handler, called when a connection
                          error occurs

    ***************************************************************************/

    protected this ( EpollSelectDispatcher epoll, ISocket socket,
                     FinalizeDg finalize_dg = null, ErrorDg error_dg = null )
    {
        this(epoll, this.default_stack_size, socket, finalize_dg, error_dg);
    }


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Called immediately when this instance is deleted.
            (Must be protected to prevent an invariant from failing.)

        ***********************************************************************/

        protected override void dispose ( )
        {
            super.dispose();

            delete this.fiber;
        }
    }


    /***************************************************************************

        Called by the select listener right after the client connection has been
        assigned.

        Note: fiber.start() may throw an exception if an exception instance is
        passed to the first suspend() call (e.g. the select reader encounters a
        socket error). In this case the select listener will call error() and
        finalize() which are usually called in handleConnection_() below.

    ***************************************************************************/

    public override void handleConnection ( )
    in
    {
        assert (!this.fiber.running);
    }
    body
    {
        this.fiber.start();
    }


    /***************************************************************************

        Formats information about the connection into the provided buffer. This
        method is called from the SelectListener in order to log information
        about the state of all connections in the pool.

        In addition to the information formatted by the super class, we also
        format the following here:
            * the events which the ISelectClient is registered with in epoll (in
              debug builds these are printed in a human-readable format)
            * (in debug builds) the id of the ISelectClient (a description
              string)

        Params:
            buf = buffer to format into

    ***************************************************************************/

    override public void formatInfo ( ref char[] buf )
    {
        super.formatInfo(buf);

        auto client = this.fiber.registered_client;
        auto events = client ? client.events : 0;

        debug
        {
            auto id = client ? client.id : "none";
            buf ~= ", events=";

            foreach ( event, name; epoll_event_t.event_to_name )
            {
                if ( events & event )
                {
                    buf ~= name;
                }
            }

            Format.format(buf, ", id={}", id);
        }
        else
        {
            Format.format(buf, ", events={}", events);
        }
    }

    /***************************************************************************

        Connection handler method. If it catches exceptions, it must rethrow
        those of type KilledException.

    ***************************************************************************/

    abstract protected void handle ( );

    /***************************************************************************

        Actual fiber method, started by handleConnection().

    ***************************************************************************/

    private void handleConnection_ ( )
    {
        try
        {
            debug ( ConnectionHandler ) Stderr.formatln("[{}]: Handling connection", this.connection_id);

            this.handle();
        }
        catch ( Exception e )
        {
            this.error(e);
        }
        finally
        {
            this.finalize();
        }
    }
}


/*******************************************************************************

    Standard fiber connection handler class using the basic FiberSelectReader
    and FiberSelectWriter.

*******************************************************************************/

abstract class IFiberConnectionHandler : IFiberConnectionHandlerBase, Resettable
{
    /***************************************************************************

        If true, a buffered writer is used by default.

    ***************************************************************************/

    public static bool use_buffered_writer_by_default = false;

    /***************************************************************************

        Local aliases for SelectReader and SelectWriter.

    ***************************************************************************/

    public alias .FiberSelectReader SelectReader;
    public alias .FiberSelectWriter SelectWriter;

    /***************************************************************************

        SelectReader and SelectWriter used for asynchronous protocol i/o.

    ***************************************************************************/

    protected SelectReader reader;
    protected SelectWriter writer;

    /***************************************************************************

        IOWarning exception instance used by the reader and writer.

    ***************************************************************************/

    protected IOWarning io_warning;

    /***************************************************************************

        Constructor

        Connects the socket, the asynchronous reader and writer, and the
        provided epoll select dispatcher.

        Params:
            epoll           = epoll select dispatcher which this connection
                              should use for i/o
            stack_size      = fiber stack size
            buffered_writer = set to true to use the buffered writer
            socket          = the socket
            finalize_dg     = user-specified finalizer, called when the
                              connection is shut down
            error_dg        = user-specified error handler, called when a
                              connection error occurs

    ***************************************************************************/

    protected this ( EpollSelectDispatcher epoll,
                     size_t stack_size, bool buffered_writer, ISocket socket,
                     FinalizeDg finalize_dg = null, ErrorDg error_dg = null )
    {
        this(epoll, buffered_writer?
                        new BufferedFiberSelectWriter(this.socket, this.fiber, this.io_warning, this.socket_error) :
                        new FiberSelectWriter(this.socket, this.fiber, this.io_warning, this.socket_error),
                    socket, finalize_dg, error_dg, stack_size);
    }

    /***************************************************************************

        Constructor, uses the default fiber stack size.

        Connects the socket, the asynchronous reader and writer, and the
        provided epoll select dispatcher.

        Params:
            epoll           = epoll select dispatcher which this connection
                              should use for i/o
            buffered_writer = set to true to use the buffered writer
            socket          = the socket
            finalize_dg     = user-specified finalizer, called when the
                              connection is shut down
            error_dg        = user-specified error handler, called when a
                              connection error occurs

    ***************************************************************************/

    protected this ( EpollSelectDispatcher epoll, bool buffered_writer,
                     ISocket socket,
                     FinalizeDg finalize_dg = null, ErrorDg error_dg = null )
    {
        this(epoll, this.default_stack_size, buffered_writer, socket,
             finalize_dg, error_dg);
    }

    /***************************************************************************

        Constructor, uses the default setting for buffered socket writing.

        Connects the socket, the asynchronous reader and writer, and the
        provided epoll select dispatcher.

        Params:
            epoll           = epoll select dispatcher which this connection
                              should use for i/o
            stack_size      = fiber stack size
            socket          = the socket
            finalize_dg     = user-specified finalizer, called when the
                              connection is shut down
            error_dg        = user-specified error handler, called when a
                              connection error occurs

    ***************************************************************************/

    protected this ( EpollSelectDispatcher epoll, size_t stack_size,
                     ISocket socket,
                     FinalizeDg finalize_dg = null, ErrorDg error_dg = null )
    {
        this(epoll, stack_size,
             this.use_buffered_writer_by_default, socket, finalize_dg, error_dg);
    }

    /***************************************************************************

        Constructor, uses the default fiber stack size and the default setting
        for buffered socket writing.

        Connects the socket, the asynchronous reader and writer, and the
        provided epoll select dispatcher.

        Params:
            epoll           = epoll select dispatcher which this connection
                              should use for i/o
            socket          = the socket
            finalize_dg     = user-specified finalizer, called when the
                              connection is shut down
            error_dg        = user-specified error handler, called when a
                              connection error occurs

    ***************************************************************************/

    protected this ( EpollSelectDispatcher epoll, ISocket socket,
                     FinalizeDg finalize_dg = null, ErrorDg error_dg = null )
    {
        this(epoll, this.use_buffered_writer_by_default, socket,
             finalize_dg, error_dg);
    }

    /***************************************************************************

        Constructor

        Connects the socket, the asynchronous reader and writer, and the
        provided epoll select dispatcher.

        Params:
            epoll       = epoll select dispatcher which this connection should
                          use for i/o
            writer      = SelectWriter instance to use
            socket      = the socket
            finalize_dg = user-specified finalizer, called when the connection
                          is shut down
            error_dg    = user-specified error handler, called when a connection
                          error occurs

        Note that writer must be lazy because it must be newed _after_ the super
        constructor has been called.

    ***************************************************************************/

    private this ( EpollSelectDispatcher epoll, lazy SelectWriter writer,
                   ISocket socket, FinalizeDg finalize_dg, ErrorDg error_dg,
                   size_t stack_size )
    {
        super(epoll, stack_size, socket, finalize_dg, error_dg);

        this.io_warning = new IOWarning(this.socket);

        this.reader = new SelectReader(this.socket, this.fiber, this.io_warning, this.socket_error);
        this.writer = writer;

        this.reader.error_reporter = this;
        this.writer.error_reporter = this;
    }

    /**************************************************************************

        Called immediately when this instance is deleted.
        (Must be protected to prevent an invariant from failing.)

     **************************************************************************/

    version (D_Version2) {}
    else
    protected override void dispose ( )
    {
        super.dispose();

        delete this.reader;
        delete this.writer;
    }

    /**************************************************************************

        Called by IConnectionHandler.finalize(), in order to determine if an I/O
        error was reported for the connection conduit which made the connection
        automatically being closed.
        (See comment for IConnectionHandler.finalize() method.)

        Returns:
            true if an I/O error was reported to the reader or the writer for
            the connection conduit which made the connection automatically being
            closed or false otherwise.

     **************************************************************************/

    protected override bool io_error ( )
    {
        return this.reader.io_error || this.writer.io_error;
    }

    /**************************************************************************

        Resettable interface method, resets the reader.

     **************************************************************************/

    public void reset ( )
    {
        this.reader.reset();
    }
}
