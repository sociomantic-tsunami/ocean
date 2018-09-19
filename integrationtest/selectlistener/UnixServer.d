/*******************************************************************************

    Sample unix socket server, which is based on fiber select listener.

    Copyright:
        Copyright (c) 2016-2017 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module integrationtest.selectlistener.UnixServer;

import ocean.io.select.EpollSelectDispatcher;
import ocean.io.select.protocol.fiber.FiberSelectReader;
import ocean.io.select.protocol.fiber.FiberSelectWriter;
import ocean.io.select.protocol.generic.ErrnoIOException : SocketError;
import ocean.net.server.SelectListener;
import ocean.net.server.connection.IFiberConnectionHandler;
import ocean.sys.socket.UnixSocket;


/*******************************************************************************

    The server is based on SelectListener.

*******************************************************************************/

public alias SelectListener!(UnixConnectionHandler, EpollSelectDispatcher) UnixServer;


/*******************************************************************************

    The connection handler is based on IFiberConnectionHandler

*******************************************************************************/

private class UnixConnectionHandler: IFiberConnectionHandler
{
    /***************************************************************************

        Keeps data between `consume` calls.

    ***************************************************************************/

    char[] buffer;


    /***************************************************************************

        Shuts down the server when one request is served.

    ***************************************************************************/

    EpollSelectDispatcher epoll;


    /***************************************************************************

        Consumer callback delegate type

        Params:
            data = data to consume

        Returns:
            - if finished, a value of [0, data.length] reflecting the number of
              elements (bytes) consumed or
            - a value greater than data.length if more data is required.

    ***************************************************************************/

    private size_t consume( void[] data )
    {
        char[] input = cast(char[])data;
        size_t n = 0;

        foreach ( size_t i, char c; input )
        {
            n++;
            if ( c == '\n' )
            {
                return n;
            }
            buffer ~= c;
        }

        // If we need more data, we must return a value greater than data.length.
        return data.length + 1;
    }


    /***************************************************************************

        Constructor

    ***************************************************************************/

    public this ( scope FinalizeDg finalize_dg, EpollSelectDispatcher epoll )
    {
        super(epoll, new UnixSocket, finalize_dg);

        this.epoll = epoll;
    }


    /***************************************************************************

        Connection handler method. If it catches exceptions, it must rethrow
        those of type KilledException.

    ***************************************************************************/

    protected override void handle ( )
    {
        auto exception = new SocketError(this.socket);

        FiberSelectReader reader = new FiberSelectReader(this.socket,
            this.fiber, exception, exception);
        this.reader.error_reporter = this;

        FiberSelectWriter writer = new FiberSelectWriter(this.socket,
            this.fiber, exception, exception);
        this.reader.error_reporter = this;

        scope(exit)
        {
            this.epoll.shutdown();
                // Is anything else needed?
        }

        // In production code, this may be to be wrapped in a `while`.
        buffer.length = 0;
        reader.readConsume(&this.consume);
        buffer ~= "\n";
        writer.send(buffer);
    }
}
