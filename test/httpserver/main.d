/*******************************************************************************

    Test-suite for the task based HTTP server.

    This test uses a TCP socket connection to `localhost:8080`.

    FLAKY: the unittests in this module are a bit flaky, as they rely on making
    various system calls (`socket`, `connect`, `read/write`, epoll API
    functions, etc) which could, under certain environmental conditions, fail.

    Copyright:      Copyright (c) 2017 sociomantic labs. All rights reserved

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module test.selectlistener.main;

import ocean.transition;

import ocean.net.http.TaskHttpConnectionHandler;
import ocean.net.http.HttpConst : HttpResponseCode;
import ocean.net.http.consts.HttpMethod;
import ocean.net.http.HttpException;
import ocean.net.server.SelectListener;
import ocean.task.Task;
import ocean.task.Scheduler;
import ocean.io.select.EpollSelectDispatcher;
import ocean.sys.socket.IPSocket;
import ocean.sys.ErrnoException;
import core.stdc.errno;
import core.stdc.stdlib;

/// The payload of the HTTP response.
static immutable response_payload = "Hello World!";

/// The server address, initialised in `main` and used by both the server and
/// the client.
IPSocket!().InetAddress srv_address;

/// Task-based HTTP connection handler supporting only HTTP GET with
/// `response_payload` as the response payload.
class TestHttpHandler: TaskHttpConnectionHandler
{
    import ocean.io.Stdout;

    public this ( FinalizeDg finalizer )
    {
        super(finalizer, HttpMethod.Get);
    }

    override protected HttpResponseCode handleRequest ( out cstring response_msg_body )
    {
        response_msg_body = response_payload;
        return HttpResponseCode.OK;
    }

    /// Print errors to make debugging easier. If the test succeeds then none of
    /// the following methods is called.
    override protected void notifyIOException ( ErrnoException e, bool is_error )
    {
        printEx(e);
    }

    override protected bool handleHttpServerException ( HttpServerException e )
    {
        printEx(e);
        return super.handleHttpServerException(e);
    }

    override protected bool handleHttpException ( HttpException e )
    {
        printEx(e);
        return super.handleHttpException(e);
    }

    static void printEx ( Exception e )
    {
        Stderr.formatln("{} @{}:{}", getMsg(e), e.file, e.line);
    }
}

/// HTTP client task. It sends one HTTP GET request and receives and parses the
/// response, expecting `response_payload` as the response payload.
class ClientTask: Task
{
    import ocean.io.select.protocol.task.TaskSelectTransceiver;
    import ocean.io.select.protocol.generic.ErrnoIOException: SocketError;
    import ocean.core.Test: test;

    TaskSelectTransceiver tst;
    IPSocket!() socket;
    SocketError e;
    Exception e_unhandled = null;

    this ( )
    {
        this.socket = new IPSocket!();
        this.e = new SocketError(socket);
        this.tst = new TaskSelectTransceiver(socket, e, e);
    }

    override void run ( )
    {
        try
        {
            this.e.enforce(this.socket.tcpSocket(true) >= 0, "", "socket");
            connect(this.tst,
                (IPSocket!() socket) {return !socket.connect(srv_address.addr);}
            );
            this.tst.write("GET / HTTP/1.1\r\nHost: example.net\r\n\r\n");
            scope parser = new ResponseParser(response_payload.length);
            this.tst.readConsume(&parser.consume);
            test!("==")(parser.payload, response_payload);
        }
        catch (TaskKillException e)
            throw e;
        catch (Exception e)
            this.e_unhandled = e;
    }
}

/*******************************************************************************

    Runs the server. The server is a simple echo server. It serves just
    one request and then it exits.

    Params:
        socket_path = the unix socket path.

    Returns:
        `EXIT_SUCCESS`

    Throws:
        `Exception` on error.

*******************************************************************************/

int main ( )
{
    initScheduler(SchedulerConfiguration.init);

    auto client = new ClientTask;
    auto srv_socket = new IPSocket!();
    alias SelectListener!(TestHttpHandler) Listener;
    auto listener = new Listener(srv_address("127.0.0.1", 8080), srv_socket);

    client.terminationHook = {theScheduler.epoll.unregister(listener);};

    with (theScheduler)
    {
        epoll.register(listener);
        schedule(client);
        eventLoop();
    }

    if (client.e_unhandled)
        throw client.e_unhandled;

    return EXIT_SUCCESS;
}

/// Stores and parses the response data which `readConsume` outputs.
static class ResponseParser
{
    /// Everything passed to `consume` is appended here.
    char[] response;
    /// The token that denotes the end of the HTTP header and the beginning of
    /// the payload.
    static immutable end_of_header_token = "\r\n\r\n";
    /// true if `end_of_header_token` has been fond in `response`.
    bool have_payload;
    /// The index in `response` after `end_of_header_token`.
    size_t payload_start;
    /// The expected payload length so that `consume` knows when to finish.
    /// The preferred way is to use the "Content-Length" HTTP response header
    /// line, but for simplicity we don't parse the full HTTP header here.
    size_t payload_length;

    this ( size_t payload_length )
    {
        this.payload_length = payload_length;
    }

    /// Returns the payload or `null` if `end_of_header_token` hasn't been
    /// found yet.
    char[] payload ( )
    {
        return this.have_payload
            ? this.response[this.payload_start .. $]
            : null;
    }

    /// `readConsume` callback, appends `data` to `this.response`, then looks
    /// for `end_of_header_token`. Returns `data.length` if finished or
    /// a greater value if the full payload isn't there yet.
    size_t consume ( void[] data )
    {
        this.response ~= cast(char[])data;
        if (!this.have_payload)
        {
            if (auto end_of_header = cast(char*)memmem(
                this.response.ptr, this.response.length,
                end_of_header_token.ptr, end_of_header_token.length
            ))
            {
                this.have_payload = true;
                this.payload_start = end_of_header - this.response.ptr
                    + end_of_header_token.length;
                assert(this.payload_start <= this.response.length);
                assert(
                    this.response[
                        this.payload_start - end_of_header_token.length
                        .. this.payload_start
                    ] == end_of_header_token
                );
            }
        }

        return data.length + (this.payload.length < this.payload_length);
    }

    unittest
    {
        {
            scope parser = new typeof(this)(3);
            assert(parser.consume("abcde".dup) == 6);
            assert(parser.consume("fgh\r\n\r\ni".dup) == 9);
            assert(parser.payload == "i".dup);
            assert(parser.consume("jk".dup) == 2);
            assert(parser.payload == "ijk".dup);
        }
        {
            scope parser = new typeof(this)(3);
            assert(parser.consume("abcd\r".dup) == 6);
            assert(parser.consume("\n\r\nef".dup) == 6);
            assert(parser.consume("g".dup) == 1);
            assert(parser.payload == "efg".dup);
        }
        {
            scope parser = new typeof(this)(3);
            assert(parser.consume("abc\r\n\r\n".dup) == 8);
            assert(parser.consume("efg".dup) == 3);
            assert(parser.payload == "efg".dup);
        }
    }
}

/// glibc function. Looks for b_ptr[0 .. b_len] in a_ptr[0 .. a_len] and returns
/// - a pointer to the first occurrence if found or
/// - null if not found or
/// - a_ptr if b_len == 0.
extern (C) Inout!(void)* memmem (
    Inout!(void)* a_ptr, size_t a_len, Const!(void)* b_ptr, size_t b_len
);
