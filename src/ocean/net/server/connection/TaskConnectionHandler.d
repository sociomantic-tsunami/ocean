/*******************************************************************************

    Base class for a connection handler for use with SelectListener, using
    tasks.

    Copyright:
        Copyright (c) 2017 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.net.server.connection.TaskConnectionHandler;

import ocean.net.server.connection.IConnectionHandler;
import ocean.util.container.pool.model.IResettable;

/// ditto

abstract class TaskConnectionHandler : IConnectionHandler, Resettable
{
    import ocean.sys.socket.model.ISocket;
    import ocean.io.select.protocol.task.TaskSelectTransceiver;
    import ocean.io.select.protocol.generic.ErrnoIOException: IOWarning;
    import ocean.task.Task: Task;
    import ocean.task.IScheduler: theScheduler;

    import ocean.transition;

    /***************************************************************************

        Reads data from and writes data to the connection socket.

    ***************************************************************************/

    protected TaskSelectTransceiver transceiver;

    /***************************************************************************

        IOWarning exception instance used by the reader/writer and subclass.

    ***************************************************************************/

    protected IOWarning io_warning;

    /***************************************************************************

        Connection handler task, runs the abstract `handle` method and calls the
        finalizer callback on termination.

    ***************************************************************************/

    private class ConnectionHandlerTask: Task
    {
        /// Constructor.
        private this ( )
        {
            this.terminationHook = &this.outer.finalize;
        }

        /// Task method, runs `TaskConnectionHandler.handle.`
        override protected void run ( )
        {
            this.outer.handle();
        }
    }

    /// ditto
    private Task task;

    /***************************************************************************

        Constructor

        Params:
            socket       = the socket
            error_dg_    = optional user-specified error handler, called when a
                           connection error occurs

     ***************************************************************************/

    protected this ( ISocket socket, scope ErrorDg error_dg_ = null )
    {
        this(socket, null, error_dg_);
    }

    /***************************************************************************

        Constructor

        Params:
            socket       = the socket
            finalize_dg_ = finalizer callback of the select listener, called
                           when the connection is shut down
            error_dg_    = optional user-specified error handler, called when a
                           connection error occurs

    ***************************************************************************/

    protected this ( ISocket socket, scope FinalizeDg finalize_dg_,
        scope ErrorDg error_dg_ = null )
    {
        super(socket, finalize_dg_, error_dg_);
        this.io_warning = new IOWarning(this.socket);
        this.transceiver = new TaskSelectTransceiver(
            this.socket, this.io_warning, this.socket_error
        );
        this.task = this.new ConnectionHandlerTask;
    }

    /**************************************************************************

        Called by `finalize` to unregister the connection socket from epoll
        before closing it. This is done because closing a socket does not always
        mean that it is unregistered from epoll -- in situations where the
        process has forked, the fork's reference to the underlying kernel file
        description will prevent it from being unregistered until the fork
        exits. Therefore, to be certain that the socket will not fire again in
        epoll, we need to explicitly unregister it.

    ***************************************************************************/

    protected override void unregisterSocket ()
    {
        this.transceiver.reset();
    }

    /***************************************************************************

        Called by the select listener right after the client connection has been
        assigned.
        If this method throws an exception, error() and finalize() will be
        called by the select listener.

    ***************************************************************************/

    override public void handleConnection ( )
    {
        theScheduler.schedule(this.task);
    }

    /***************************************************************************

        Connection handler method, called from a running task.

    ***************************************************************************/

    abstract protected void handle ( );

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

    override public bool io_error ( )
    {
        return !!this.socket.error;
    }
}
