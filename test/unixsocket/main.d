/*******************************************************************************

    Copyright:      Copyright (c) 2015 sociomantic labs. All rights reserved

    Test-suite for UnixSockets.

    The tests involve unix sockets and forking
    processes, so are placed in this slowtest module.

    FLAKY: the unittests in this module are very flaky, as they rely on making
    various system calls (fork(), waitpid(), epoll_wait(), epoll_ctl(), etc)
    which could, under certain environmental conditions, fail.

*******************************************************************************/

import ocean.core.Enforce;
import ocean.core.Test;
import ocean.sys.socket.UnixSocket;

import ocean.transition;
import ocean.stdc.posix.sys.socket;
import ocean.stdc.posix.sys.un;
import ocean.stdc.posix.sys.wait;
import core.sys.posix.unistd;
import ocean.stdc.posix.stdlib : mkdtemp;
import core.stdc.stdio;
import ocean.math.Math;
import ocean.core.Thread;
import ocean.core.Time;
import ocean.stdc.string;
import core.stdc.errno;

import ocean.text.util.StringC;

const istring CLIENT_STRING = "Hello from the client";

const istring SERVER_STRING = "Hello from the server";

int runClient ( sockaddr_un* socket_address )
{
    auto client = new UnixSocket();

    scope (exit) client.close();

    auto socket_fd = client.socket();

    enforce(socket_fd >= 0, "socket() call failed!");

    auto connect_result = client.connect(socket_address);

    // Try to connect at most 5 times, do a simple backoff if the connection
    // fails to increase the time linearly (the sum of all retries is ~1.5s)
    int i;
    for (i = 1; i <= 5 && connect_result == ECONNREFUSED; i++)
    {
        Thread.sleep(seconds(0.1 * i));
        connect_result = client.connect(socket_address);
    }

    enforce(i <= 5 && connect_result == 0,
            "connect() call failed after 5 retries!");

    // send some data
    client.write(CLIENT_STRING);

    auto read_buffer = new char[max(SERVER_STRING.length,
                                    CLIENT_STRING.length) + 1];
    read_buffer[] = 0;

    auto buff = cast(void[])read_buffer;

    // receive some data
    auto read_bytes = client.recv(buff, 0);

    enforce(read_bytes > 0);

    read_buffer.length = read_bytes;

    test(read_buffer == SERVER_STRING);

    return 0;
}

int main ( )
{
    bool in_child = false;

    auto path = mkdtemp("/tmp/Dunittest-XXXXXX\0".dup.ptr);
    enforce(path !is null);

    auto test_dir = StringC.toDString(path);

    scope (exit)
    {
        if (!in_child)
        {
            auto r = rmdir(test_dir.ptr);
            assert(r == 0, "Couldn't remove the temporary directory " ~
                    test_dir ~ ": " ~ StringC.toDString(strerror(errno)));
        }
    }

    auto socket_path = test_dir ~ "/socket";

    auto socket_address = sockaddr_un.create(socket_path);

    pid_t pid = fork();

    enforce(pid != -1);

    if (pid == 0)  // client
    {
        in_child = true;
        return runClient(&socket_address);
    }

    auto server = new UnixSocket();

    // close the socket
    scope (exit) server.close();

    auto socket_fd = server.socket();
    enforce(socket_fd >= 0, "socket() call failed!");

    auto bind_result = server.bind(&socket_address);
    enforce(bind_result == 0, "bind() call failed!");

    scope (exit)
    {
        auto r = unlink(socket_path.ptr);
        assert(r == 0, "Couldn't remove the socket file " ~ socket_path ~
                ": " ~ StringC.toDString(strerror(errno)));
    }

    int backlog = 10;

    auto listen_result = server.listen(backlog);
    enforce(listen_result == 0, "listen() call failed!");

    int connection_fd;

    auto peer_socket = new UnixSocket();

    scope (exit) peer_socket.close();

    if (peer_socket.accept(server) != -1)
    {
        connection_handler(peer_socket);
    }

    int status;

    waitpid(pid, &status, 0);

    enforce(status == 0, "Child exit status should be 0");

    return 0;
}

void connection_handler ( UnixSocket peer_socket )
{
    auto read_buffer = new char[max(SERVER_STRING.length,
                                    CLIENT_STRING.length) + 1];
    read_buffer[] = '\0';

    auto buff = cast(void[])read_buffer;

    auto read_bytes = peer_socket.recv(buff, 0);

    enforce(read_bytes > 1);

    read_buffer.length = read_bytes;

    enforce(read_buffer == CLIENT_STRING,
            cast(istring) ("Expected: " ~ CLIENT_STRING ~ " Got: " ~ read_buffer));

    // send the response
    peer_socket.write(SERVER_STRING);
}
