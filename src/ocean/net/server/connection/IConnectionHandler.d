/*******************************************************************************

    Base class for a connection handler for use with SelectListener.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.net.server.connection.IConnectionHandler;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.io.select.EpollSelectDispatcher;

import ocean.net.server.connection.IConnectionHandlerInfo;
import ocean.io.select.client.model.ISelectClient : IAdvancedSelectClient;

import ocean.io.select.protocol.generic.ErrnoIOException: SocketError;

import ocean.io.device.IODevice: IInputDevice, IOutputDevice;

import ocean.text.convert.Format;

import ocean.io.model.IConduit: ISelectable;

debug ( ConnectionHandler ) import ocean.io.Stdout : Stderr;


/*******************************************************************************

    Connection handler abstract base class.

*******************************************************************************/

abstract class IConnectionHandler : IConnectionHandlerInfo,
    IAdvancedSelectClient.IErrorReporter
{
    protected import ocean.sys.socket.model.ISocket;

    /***************************************************************************

        Object pool index.

    ***************************************************************************/

    public size_t object_pool_index;

    /***************************************************************************

        Local aliases to avoid public imports.

    ***************************************************************************/

    public alias .EpollSelectDispatcher EpollSelectDispatcher;

    protected alias IAdvancedSelectClient.Event Event;

    /***************************************************************************

        Client connection socket, exposed to subclasses downcast to Conduit.

    ***************************************************************************/

    protected ISocket socket;

    /***************************************************************************

        SocketError instance to throw on error and query the current socket
        error status.

    ***************************************************************************/

    protected SocketError socket_error;

    /***************************************************************************

        Alias for a finalizer delegate, which can be specified externally and is
        called when the connection is shut down.

    ***************************************************************************/

    public alias void delegate ( typeof (this) instance ) FinalizeDg;

    /***************************************************************************

        Finalizer delegate which can be specified externally and is called when
        the connection is shut down.

    ***************************************************************************/

    private FinalizeDg finalize_dg_ = null;

    /***************************************************************************

        Alias for an error delegate, which can be specified externally and is
        called when a connection error occurs.

    ***************************************************************************/

    public alias void delegate ( Exception exception, Event event,
        IConnectionHandlerInfo ) ErrorDg;

    /***************************************************************************

        Error delegate, which can be specified externally and is called when a
        connection error occurs.

    ***************************************************************************/

    private ErrorDg error_dg_ = null;

    /***************************************************************************

        Instance id number in debug builds.

    ***************************************************************************/

    debug
    {
        static private uint connection_count;
        public uint connection_id;
    }

    /***************************************************************************

        Constructor

        Params:
            socket       = the socket
            error_dg_    = optional user-specified error handler, called when a
                           connection error occurs

     ***************************************************************************/

    protected this ( ISocket socket, ErrorDg error_dg_ = null )
    {
        this(socket, null, error_dg_);
    }

    /***************************************************************************

        Constructor

        Params:
            socket       = the socket
            finalize_dg_ = optional user-specified finalizer, called when the
                           connection is shut down
            error_dg_    = optional user-specified error handler, called when a
                           connection error occurs

    ***************************************************************************/

    protected this ( ISocket socket, FinalizeDg finalize_dg_ = null,
        ErrorDg error_dg_ = null )
    {
        assert(socket !is null);

        this.finalize_dg_ = finalize_dg_;
        this.error_dg_ = error_dg_;

        this.socket = socket;

        this.socket_error = new SocketError(this.socket);

        debug this.connection_id = connection_count++;
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
            this.finalize_dg_ = null;
            this.error_dg_    = null;

            delete this.socket;
        }
    }


    /***************************************************************************

        Sets the finalizer callback delegate which is called when the
        connection is shut down. Setting to null disables the finalizer.

        Params:
            finalize_dg_ = finalizer callback delegate

        Returns:
            finalize_dg_

    ***************************************************************************/

    public FinalizeDg finalize_dg ( FinalizeDg finalize_dg_ )
    {
        return this.finalize_dg_ = finalize_dg_;
    }

    /***************************************************************************

        Sets the error handler callback delegate which is called when a
        connection error occurs. Setting to null disables the error handler.

        Params:
            error_dg_ = error callback delegate

        Returns:
            error_dg_

    ***************************************************************************/

    public ErrorDg error_dg ( ErrorDg error_dg_ )
    {
        return this.error_dg_ = error_dg_;
    }

    /***************************************************************************

        Returns:
            true if a client connection is currently established or false if
            not.

    ***************************************************************************/

    public bool connected ( )
    {
        return this.socket.fileHandle >= 0;
    }

    /***************************************************************************

        Returns:
            I/O device instance (file descriptor under linux)

    ***************************************************************************/

    public ISelectable.Handle fileHandle ( )
    {
        return this.socket.fileHandle;
    }

    /***************************************************************************

        Accepts a pending connection from listening_socket and assigns it to the
        socket of this instance.

        Params:
            listening_socket = the listening server socket for which a client
                               connection is pending

    ***************************************************************************/

    public void assign ( ISelectable listening_socket )
    in
    {
        assert (!this.connected, "client connection was open before assigning");
    }
    body
    {
        debug ( ConnectionHandler ) Stderr.formatln("[{}]: New connection", this.connection_id);

        if (this.socket.accept(listening_socket, true) < 0)
        {
            this.error(this.socket_error.setSock("error accepting connection", __FILE__, __LINE__));
        }
    }

    /***************************************************************************

        Called by the select listener right after the client connection has been
        assigned.
        If ths method throws an exception, error() and finalize() will be called
        by the select listener.

    ***************************************************************************/

    public abstract void handleConnection ( );

    /***************************************************************************

        Must be called by the subclass when finished handling the connection.
        Will be automatically called by the select listener if assign() or
        handleConnection() throws an exception.

        The closure of the socket after handling a connection is quite
        sensitive. If a connection has actually been assigned, the socket must
        be shut down *unless* an I/O error has been reported for the socket
        because then it will already have been shut down automatically. The
        abstract io_error() method is used to determine whether the an I/O error
        was reported for the socket or not.

    ***************************************************************************/

    public void finalize ( )
    {
        if ( this.connected )
        {
            debug ( ConnectionHandler ) Stderr.formatln("[{}]: Closing connection", this.connection_id);

            if (this.io_error) if (this.socket.shutdown())
            {
                this.error(this.socket_error.setSock("error closing connection", __FILE__, __LINE__));
            }

            this.socket.close();
        }

        if ( this.finalize_dg_ ) try
        {
            this.finalize_dg_(this);
        }
        catch ( Exception e )
        {
            this.error(e);
        }
    }

    /***************************************************************************

        IAdvancedSelectClient.IErrorReporter interface method. Called when a
        connection error occurs.

        Params:
            exception = exception which caused the error
            event = epoll select event during which error occurred, if any

    ***************************************************************************/

    public void error ( Exception exception, Event event = Event.init )
    {
        debug ( ConnectionHandler ) try if ( this.io_error )
        {
            Stderr.formatln("[{}]: Caught io exception while handling connection: '{}' @ {}:{}",
                    this.connection_id, exception.toString(), exception.file, exception.line);
        }
        else
        {
            debug ( ConnectionHandler ) Stderr.formatln("[{}]: Caught non-io exception while handling connection: '{}' @ {}:{}",
                    this.connection_id, exception.toString(), exception.file, exception.line);
        }
        catch { /* Theoretically io_error() could throw. */ }

        if ( this.error_dg_ )
        {
            this.error_dg_(exception, event, this);
        }
    }

    /***************************************************************************

        Formats information about the connection into the provided buffer. This
        method is called from the SelectListener in order to log information
        about the state of all connections in the pool.

        We format the following here:
            * the file descriptor of the socket of this connection
            * the remote ip and port of the socket
            * whether an I/O error has occurred for the socket since the last
              call to assign()

        Params:
            buf = buffer to format into

    ***************************************************************************/

    public void formatInfo ( ref char[] buf )
    {
        Format.format(buf, "fd={}, ioerr={}",
            this.fileHandle, this.io_error);
    }

    /***************************************************************************

        Tells whether an I/O error has been reported for the socket since the
        last assign() call.

        Returns:
            true if an I/O error has been reported for the socket or false
            otherwise.

    ***************************************************************************/

    protected abstract bool io_error ( );
}
