/*******************************************************************************

    Unit tests for SelectListener.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.net.server.SelectListener_slowtest;


import ocean.transition;

import ocean.net.server.SelectListener;
import ocean.net.server.connection.IConnectionHandler;
import ocean.io.select.protocol.generic.ErrnoIOException: SocketError;
import ocean.util.log.Logger;

import ocean.core.Test;
import ocean.sys.socket.AddressIPSocket;
import ocean.sys.socket.UnixSocket;
import ocean.sys.socket.InetAddress;
import core.sys.posix.unistd: unlink;
import ocean.stdc.posix.sys.un;
import core.sys.posix.sys.socket;


/*******************************************************************************

    Static module logger

*******************************************************************************/

static private Logger log;
static this ( )
{
    log = Log.lookup("ocean.net.server.SelectListener_slowtest");
}

/*******************************************************************************

    IP unit tests

*******************************************************************************/

class DummyConHandler : IConnectionHandler
{
    this ( scope void delegate ( IConnectionHandler instance ) )
    {
        super(new AddressIPSocket!(), null, null);
    }
    override protected bool io_error() { return true; }
    override public void handleConnection () {}
    override public void unregisterSocket() {}
}

ushort testPort ( ushort port )
{
    InetAddress!(false) addr;

    auto socket = new AddressIPSocket!();

    auto listener = new SelectListener!(DummyConHandler)(
        addr(port), socket);

    scope (exit) listener.shutdown();

    test(!socket.updateAddress(), "socket.updateAddress() failed.");

    test(socket.port() != 0, "Did not correctly query bounded port from OS");

    test(port == 0 || socket.port() == port,
         "Didn't bind to expected port!");

    return socket.port();
}

unittest
{
    auto port = testPort(0);

    port++;

    // If the port we're testing happens to be taken, try the next one
    // give up after 10 tries
    for ( size_t i = 0; i < 10; ++i ) try
    {
        port = testPort(port);
        return;
    }
    catch ( SocketError e )
    {
        port += i;
    }

    log.warn("FLAKEY: Failed to perform test of binding to a "
        ~ "specific port after 10 tries");
}

/*******************************************************************************

    UNIX socket unit tests

*******************************************************************************/

class DummyConHandlerUnix : IConnectionHandler
{
    this ( scope void delegate ( IConnectionHandler instance ) )
    {
        super(new UnixSocket, null, null);
    }
    override protected bool io_error() { return true; }
    override public void handleConnection () {}
    override public void unregisterSocket() {}
}

void test_unix (istring path)
{
    // The following test will fail:
    // 1) during the socket creation if the socket file can not be created.
    // 2) during the socket termination, if the socket file can not be deleted.

    auto local_address = sockaddr_un.create(path);
    auto unix_socket = new UnixSocket;

    auto listener = new SelectListener!(DummyConHandlerUnix)(
        cast(sockaddr*)&local_address, unix_socket);

    test(unix_socket.error ==0, "Something wrong happened");

    scope (exit)
    {
        listener.shutdown();

        if ( (local_address.sun_path[0] != '\0')
            && unlink(local_address.sun_path.ptr) == -1 )
        {
            test(false, "Socket file '" ~ local_address.sun_path ~
                "' could not be unlinked (it may not exist or "
              ~ "the executable lacks permissions).");
        }
    }
}

unittest
{
    test_unix("\0ocean-unixsocket-test");
    test_unix("/tmp/ocean-unixsocket-test");
}
