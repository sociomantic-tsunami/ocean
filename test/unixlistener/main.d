/*******************************************************************************

    Test suite for the unix socket listener.

    Copyright:
        Copyright (c) 2009-2017 sociomantic labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

import ocean.transition;

import core.thread;
import ocean.core.Test;
import ocean.core.Enforce;
import ocean.core.Time;
import ocean.io.select.EpollSelectDispatcher;
import core.stdc.errno: ECONNREFUSED;
import ocean.stdc.posix.sys.un;
import ocean.sys.socket.UnixSocket;
import ocean.net.server.unix.UnixListener;
import Integer = ocean.text.convert.Integer_tango;



/*******************************************************************************

    Opens a client connection and issues a request.

    Params:
        socket_path = the unix socket path.
        command = command to be sent

    Throws:
        an exception if something goes wrong (could not connect,  etc)

*******************************************************************************/

void writeToClient( cstring socket_path, cstring command )
{
    auto local_address = sockaddr_un.create(socket_path);
    auto client = new UnixSocket();

    scope (exit) client.close();

    auto socket_fd = client.socket();
    enforce(socket_fd >= 0, "socket() call failed!");

    auto connect_result = client.connect(&local_address);
    enforce(connect_result == 0, "connect() call failed.");

    client.write(command);
}


/*******************************************************************************

    Creates UnixListener, sends several commands, and confirms they were
    processed.

*******************************************************************************/

int main ( )
{
    auto local_address = "/tmp/ocean_unixsocket_test.socket";
    auto epoll = new EpollSelectDispatcher();
    auto unix_socket   = new UnixSocket;

    // Value to be incremented via command to server
    // Needs to be 3 after end of tests.
    int expected_value = 0;

    void handleIncrementCommand ( cstring args,
            scope void delegate ( cstring response ) send_response )
    {
        expected_value += Integer.parse(args);
    }

    void handleShutdown ( cstring args,
            scope void delegate ( cstring response ) send_response )
    {
        epoll.shutdown();
    }

    auto unix_server   = new UnixListener(local_address, epoll,
            ["shutdown"[]: &handleShutdown,
             "increment": &handleIncrementCommand]
    );

    epoll.register(unix_server);

    // Write all to the socket, including shutdown, so we can just eventLoop
    // and collect what's there

    // Example passing arguments to handler:
    writeToClient(local_address, "increment 2\n");
    writeToClient(local_address, "increment 1\n");
    writeToClient(local_address, "shutdown\n");

    // Spin the server
    epoll.eventLoop();

    // This will be reached only if "shutdown" command was successful.
    test!("==")(expected_value, 3);

    return 0;
}
