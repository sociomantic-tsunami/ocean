/*******************************************************************************

    Test-suite for UnixSockets.

    The tests involve unix sockets and forking processes.

    FLAKY: the unittests in this module are very flaky, as they rely on making
    various system calls (fork(), waitpid(), epoll_wait(), epoll_ctl(), etc)
    which could, under certain environmental conditions, fail.

    Copyright:
        Copyright (c) 2016-2017 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module integrationtest.selectlistener.main;

import ocean.meta.types.Qualifiers;

import ocean.core.Enforce: enforce;
import Ocean = ocean.core.Test;
import ocean.io.select.EpollSelectDispatcher;
import ocean.time.timeout.TimeoutManager;
import ocean.stdc.posix.sys.un;
import ocean.sys.socket.UnixSocket;

import core.stdc.errno: ECONNREFUSED;
import core.stdc.stdlib;
import core.sys.posix.unistd: fork, unlink;
import core.sys.posix.sys.socket;
import core.sys.posix.sys.types : pid_t;
import core.sys.posix.sys.wait: waitpid;
import core.thread;
import core.time;

import integrationtest.selectlistener.UnixServer;


/*******************************************************************************

    Opens a client connection and issues a request. The reply must be exactly
    what was sent.

    Params:
        socket_path = the unix socket path.

    Returns:
        0 on success

    Throws:
        an exception if something goes wrong (could not connect, wrong reply, etc)

*******************************************************************************/

int run_client( istring socket_path)
{
    auto local_address = sockaddr_un.create(socket_path);
    auto client = new UnixSocket();

    scope (exit) client.close();

    auto socket_fd = client.socket();
    enforce(socket_fd >= 0, "socket() call failed!");

    auto connect_result = client.connect(&local_address);

    istring str1 = "HELLO, ... !\n";

    client.write(str1);

    auto read_buffer = new char[str1.length + 1];
    read_buffer[] = 0;
    auto buff = cast(void[])read_buffer;

    auto read_bytes = client.recv(buff, 0);
    enforce(read_bytes > 0);

    read_buffer.length = read_bytes;

    Ocean.test(read_buffer == str1);

    return 0;
}

/*******************************************************************************

    Makes a test. Starts the client in its own process, then starts the server
    in the current process and waits for them to finish.
    The client sends a message, gets an answer, compares the two strings and
    exits.
    The server opens the socket, accepts one request, reads the message,
    replies with the same message and exits (no more requests are handled).

    Params:
        socket_path = the unix socket path.

    Throws:
        an exception if something goes wrong

*******************************************************************************/

void run_test ( istring socket_path )
{
    auto timeout_mgr = new TimeoutManager;
    auto epoll = new EpollSelectDispatcher(timeout_mgr);

    unlink(socket_path.ptr);
    auto local_address = sockaddr_un.create(socket_path);
    auto unix_socket   = new UnixSocket;
    auto unix_server   = new UnixServer(cast(sockaddr*)&local_address,
            unix_socket, epoll);
    epoll.register(unix_server);

    // UnixServer should already bind and listen at this point,
    // so it is safe to connect from the client
    pid_t pid = fork();

    enforce(pid != -1);

    if (pid == 0)  // child
    {
        run_client(socket_path);
        _Exit(0);
    }

    epoll.eventLoop();

    enforce((socket_path[0] == '\0') || (unlink(socket_path.ptr) == 0),
        "Can't remove socket file.");

    int status;
    waitpid(pid, &status, 0);
    enforce(status == 0, "Child exit status should be 0");
}

/*******************************************************************************

    Makes two tests, one with standard UNIX socket and one with (LINUX) abstract
    namespace sockets.

*******************************************************************************/

version (unittest) {} else
int main ( )
{
    run_test("/tmp/ocean_socket_test");
    run_test("\0ocean_socket_test");

    return 0;
}
