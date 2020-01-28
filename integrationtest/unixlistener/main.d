/*******************************************************************************

    Test suite for the unix socket listener.

    Copyright:
        Copyright (c) 2009-2017 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module integrationtest.unixlistener.main;

import ocean.transition;

import core.thread;
import core.stdc.errno;
import core.stdc.stdio;
import core.sys.posix.stdlib;
import core.sys.posix.semaphore;
import core.sys.posix.sys.mman;
import core.sys.posix.unistd;
import core.sys.posix.sys.wait;

import ocean.core.Test;
import ocean.core.Enforce;
import ocean.core.Time;
import ocean.io.select.EpollSelectDispatcher;
import core.stdc.errno: ECONNREFUSED;
import ocean.stdc.posix.sys.un;
import ocean.sys.socket.UnixSocket;
import ocean.net.server.unix.UnixListener;
import Integer = ocean.text.convert.Integer_tango;
import ocean.text.util.SplitIterator: ChrSplitIterator;
import ocean.text.util.StringC;
import ocean.task.Task;
import ocean.task.Scheduler;
import ocean.sys.ErrnoException;
import core.stdc.string;

static if (!is(typeof(mkdtemp)))
{
    extern (C) char* mkdtemp(char*);
}

/*******************************************************************************

    Semaphore to synchronize child and parent process. The child process should
    connect to the unix domain socket, only after the parent one binded to it.

*******************************************************************************/

sem_t* start_semaphore;

/*******************************************************************************

    Helper function to wait for the start_semaphore.

*******************************************************************************/

void waitForSemaphore ()
{
    // Wait for the parent to send signals, then connect and start
    // issuing commands
    int ret;

    do
    {
        ret = sem_wait(start_semaphore);
    }
    while (ret == -1 && errno == EINTR);
    enforce (ret == 0);
}

/*******************************************************************************

    Body of a client process. Connects to the unix domain sockets and sends
    some commands, some of which are interactive.

    Params:
        socket_path = path to connect to.

*******************************************************************************/

void client_process (cstring socket_path)
{
    mstring read_buffer;
    UnixSocket client;

    cstring readData ()
    {
        read_buffer.length = 100;
        assumeSafeAppend(read_buffer);

        auto buff = cast(void[])read_buffer;

        // receive some data
        ssize_t read_bytes;

        do
        {
            read_bytes = client.recv(buff, 0);
        }
        while (read_bytes == -1 && errno == EINTR);

        enforce(read_bytes > 0);

        read_buffer.length = read_bytes;
        assumeSafeAppend(read_buffer);
        return read_buffer;
    }

    waitForSemaphore();

    // Connect to a listening socket and keep it open.
    auto local_sock_add = sockaddr_un.create(socket_path);
    client = new UnixSocket();

    auto socket_fd = client.socket();
    enforce(socket_fd >= 0, "socket() call failed!");

    auto connect_result = client.connect(&local_sock_add);
    enforce(connect_result == 0, "connect() call failed.");

    client.write("increment 2\n");
    client.write("increment 1\n");

    client.write("askMyName John Angie\n");
    test!("==")(readData(), "first name? ");
    client.write("John\n");
    test!("==")(readData(), "second name? ");
    client.write("Angie\n");

    client.write("askMeAgain John Angie");
    client.write("\n");
    test!("==")(readData(), "second name? ");
    client.write("Angie\n");
    test!("==")(readData(), "first name? ");
    client.write("John\n");

    client.write("echo Joseph\n");
    test!("==")(readData(), "Joseph");

    client.write("shutdown\n");
    client.close();
}

/*******************************************************************************

    Creates UnixListener, sends several commands, and confirms they were
    processed.

*******************************************************************************/

version (unittest) {} else
int main ( )
{
    // Since this is a one-off test, we will not care about destroying
    // these
    start_semaphore = cast(sem_t*)mmap(null,
            sem_t.sizeof, PROT_READ | PROT_WRITE,
            MAP_SHARED | MAP_ANON, -1, 0);

    if (start_semaphore is null)
    {
        return 1;
    }

    if (sem_init(start_semaphore, 1, 0) == -1)
    {
        return 1;
    }

    auto e = new ErrnoException;

    // Create a tmp directory
    mstring dir_name = "/tmp/ocean_socket_testXXXXXX".dup;
    char* tmp_dir = mkdtemp(dir_name.ptr);
    enforce(tmp_dir == dir_name.ptr);
    auto local_address = dir_name ~ "/ocean.socket";

    int child_pid = fork();
    enforce(child_pid >= 0);

    if (child_pid == 0)
    {
        client_process(local_address);
        return 0;
    }
    else
    {
        // Only parent cleans up
        scope (exit)
        {
            auto filename = StringC.toCString(local_address);
            if (access(filename, F_OK) != -1)
            {
                if (unlink(filename) != 0)
                {
                    throw e.useGlobalErrno("unlink");
                }
            }

            if (rmdir(tmp_dir) != 0)
            {
                throw e.useGlobalErrno("rmdir");
            }
        }

        auto epoll = new EpollSelectDispatcher();
        auto unix_socket   = new UnixSocket;

        // Value to be incremented via command to server
        // Needs to be 3 after end of tests.
        int expected_value = 0;

        scope handleIncrementCommand = ( cstring args,
                void delegate ( cstring response ) send_response,
                void delegate ( ref mstring response ) wait_reply )
        {
            expected_value += Integer.parse(args);
        };

        // Command shutting down the epoll
        scope handleShutdown = ( cstring args,
                void delegate ( cstring response ) send_response )
        {
            epoll.shutdown();
        };

        // test doesn't work in this callbacks, as the exceptions will be swallowed
        int success_count = 0;

        // Interactive callback. This will ask the client for the two names,
        // which should be the same as two arguments with which
        scope handleAskMyName = ( cstring args,
                void delegate ( cstring response ) send_response,
                void delegate ( ref mstring response ) wait_reply )
        {
            scope i = new ChrSplitIterator(' ');
            i.reset(args);
            cstring first = i.next();
            cstring second = i.remaining();
            mstring response;
            send_response("first name? "); wait_reply(response);
            success_count += first == response ? 1 : 0;
            send_response("second name? "); wait_reply(response);
            success_count += second == response ? 1 : 0;
        };

        // Interactive callback for the other command
        // Used to check if we can execute more handlers
        scope handleAskMyNameReverse = ( cstring args,
                void delegate ( cstring response ) send_response,
                void delegate ( ref mstring response ) wait_reply )
        {
            scope i = new ChrSplitIterator(' ');
            i.reset(args);
            cstring first = i.next();
            cstring second = i.remaining();
            mstring response;
            send_response("second name? "); wait_reply(response);
            success_count += second == response ? 1 : 0;
            send_response("first name? "); wait_reply(response);
            success_count += first == response ? 1 : 0;
        };

        // Simple echo command, non-interactive
        scope handleEcho = delegate ( cstring args,
                void delegate (cstring response) send_response)
        {
            send_response(args);
        };

        auto unix_server   = new UnixListener(idup(local_address), epoll,
                ["echo"[]: handleEcho,
                 "shutdown": handleShutdown],
                ["increment"[]: handleIncrementCommand,
                 "askMyName": handleAskMyName,
                 "askMeAgain": handleAskMyNameReverse]
        );

        epoll.register(unix_server);

        // let the child process know it may connect & start
        sem_post(start_semaphore);

        // Spin the server
        epoll.eventLoop();

        // This will be reached only if "shutdown" command was successful.
        test!("==")(expected_value, 3);
        test!("==")(success_count, 4);

        // Let's reap the zombies

        int ret;
        int status;

        do
        {
            ret = wait(&status);
        }
        while (ret == -1 && errno == EINTR);
        enforce (ret == child_pid);
    }

    return 0;
}
