/*******************************************************************************

    Sample unix socket server, which is based on fiber select listener.

    Copyright:      Copyright (c) 2016 sociomantic labs. All rights reserved

*******************************************************************************/

module test.selectlistener.UnixServer;


/*******************************************************************************

    Imports

*******************************************************************************/

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

    The conection handler is based on IFiberConnectionHandler

*******************************************************************************/

private class UnixConnectionHandler: IFiberConnectionHandler
{
    /***************************************************************************

        Keeps data between `consume` calls.

    ***************************************************************************/

    char[] buffer;


    /***************************************************************************

        Shutdowns the server when ore request is served.

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

    public this ( FinalizeDg finalize_dg, EpollSelectDispatcher epoll )
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
