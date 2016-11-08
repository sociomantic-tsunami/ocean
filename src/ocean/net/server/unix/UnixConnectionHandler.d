/*******************************************************************************

    Unix domain socket connection handler

    The connection handler expects the client to send UTF-8 text data in the
    form of '\n'-separated lines. Each line starts with a command. The command
    is terminated with either a linebreak '\n' or a space ' '. If it is
    terminated with a space then the rest of the line are the arguments for the
    command. Whitespace at the beginning of the line, command and arguments is
    trimmed. Examples:

        "my-cmd\n" -- command = "my-cmd", arguments = ""
        " my-cmd \n" -- ditto
        "my-cmd arg1 arg2\n" -- command = "my-cmd", arguments = "arg1 arg2"
        " my-cmd   arg1 arg2 \n" -- ditto

    Empty lines or lines containing only white space are ignored.

    The constructor receives a map (associative array) of handler delegates by
    supported command. This map determins which commands are supported. For each
    received line the connection handler does a lookup in this map using the
    command from the line as the key and, if found, obtaining a handler delegate
    as the value. If found, it calls the handler delegate, if not, the
    connection handler sends the string "Command not found\n" to the client.

    A handler delegate is of the type

    ```
        void delegate ( cstring request_args,
                        void delegate ( cstring response ) send_response )
    ```

    where `request_args` is the string of request arguments (as explained
    above), and `send_response` sends the `response` string to the client. Note
    that the response should end in a '\n' newline character, which is not
    automatically added.

    For a server that supports one command, "my-cmd", the associative array of
    handler delegates would be set up as follows:

    ```
        void handleMyCmd ( cstring request_args,
                           void delegate ( cstring response ) send_response )
        {
            // Just send a silly response
            send_response("Hello client, this is the response!\n");
        }

        auto map_of_handlers = ["my-cmd": &handleMyCmd];
    ```

    Passing `map_of_handlers` to the `UnixListener` constructor creates a server
    that supports this one command and responds as shown.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.net.server.unix.UnixConnectionHandler;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.net.server.connection.IFiberConnectionHandler;

import ocean.transition;

/******************************************************************************/

public class UnixConnectionHandler : IFiberConnectionHandler
{
    import ocean.io.select.EpollSelectDispatcher;
    import ocean.io.select.protocol.fiber.FiberSelectReader;
    import ocean.io.select.protocol.fiber.FiberSelectWriter;
    import ocean.io.select.protocol.generic.ErrnoIOException : SocketError;
    import ocean.sys.socket.UnixSocket;

    import ocean.text.util.SplitIterator: ChrSplitIterator;
    import ocean.core.Array: copy;

    import ocean.util.log.Log;

    /***************************************************************************

        Handler delegate type alias.

    ***************************************************************************/

    public alias void delegate (
        cstring request_args, void delegate ( cstring response ) send_response
    ) Handler;


    /***************************************************************************

        Client connection reader

    ***************************************************************************/

    private FiberSelectReader reader;

    /***************************************************************************

        Client connection writer

    ***************************************************************************/

    private FiberSelectWriter writer;

    /***************************************************************************

        Buffer to store the partial line that followed the last occurrence of
        '\n' in the most recently read input data.

    ***************************************************************************/

    private char[] remaining_request_ln;

    /***************************************************************************

        The map of handler delegates by command.

    ***************************************************************************/

    private Handler[istring] handlers;

    /***************************************************************************

        The Unix domain server socket address for logging.

    ***************************************************************************/

    private istring address_path;

    /***************************************************************************

        Logger.

    ***************************************************************************/

    private static Logger log;
    static this ( )
    {
        log = Log.lookup("ocean.net.server.unixsocket");
    }

    /***************************************************************************

        Constructor.

        Params:
            finalize_dg  = internal select listener parameter for super class
            epoll        = epoll select dispatcher to use for I/O
            handlers     = the map of handler delegates by command, see the
                           documentation on the top of this module
            address_path = the path of the server socket address, for logging

    ***************************************************************************/

    public this ( FinalizeDg finalize_dg, EpollSelectDispatcher epoll,
                  Handler[istring] handlers, istring address_path )
    {
        super(epoll, new UnixSocket, finalize_dg);

        auto e = new SocketError(this.socket);
        this.reader = new FiberSelectReader(this.socket, this.fiber, e, e);
        this.writer = new FiberSelectWriter(this.socket, this.fiber, e, e);

        this.handlers = handlers.rehash;
        this.address_path = address_path;
    }

    /***************************************************************************

        Request handler. Reads socket input data in an endless loop. Each chunk
        of input data is processed by `parseLinesAndHandle()`.

    ***************************************************************************/

    protected override void handle ( )
    {
        log.info("{} - client connected", this.address_path);
        scope (exit)
            log.info("{} - client disconnected", this.address_path);

        this.remaining_request_ln.length = 0;
        enableStomping(this.remaining_request_ln);
        this.reader.readConsume(&this.parseLinesAndHandle);
    }

    /***************************************************************************

        `FiberSelectReader.readConsume()` callback. Splits `data` into lines by
        '\n' newline characters and calls `handleCmd()` for each line. Prepends
        `this.remaining_request_ln` to `data` initially, and finally copies the
        end of `data` that follows the last newline character to
        `this.remaining_request_ln`.

        Params:
            data = socket input data

        Returns:
            A value greater than `data.length` so that `this.reader.readConsume`
            continues reading from the socket.

    ***************************************************************************/

    private size_t parseLinesAndHandle ( void[] data )
    {
        scope split = new ChrSplitIterator('\n');
        split.include_remaining = false;
        split.reset(cast(char[])data);

        if (this.remaining_request_ln.length)
        {
            this.remaining_request_ln ~= split.next();
            this.handleCmd(this.remaining_request_ln);
        }

        foreach (request_ln; split)
        {
            this.handleCmd(request_ln);
        }

        this.remaining_request_ln.copy(split.remaining);

        return data.length + 1;
    }

    /***************************************************************************

        Splits `request_ln` into command and arguments, and calls the handler
        for the command, if there is one in the map of handlers.

        The arguments passed to the handler are
         1. the white space-trimmed string of command arguments and
         2. a delegate to write to the client socket.

        See the documentation on top of the module for details and examples.
        If no handler for the command was found, the string
        "Command not found\n" is sent to the client. If `request_ln` is empty or
        contains only white space, nothing is done.

        Params:
            request_ln = one line of text data read from the socket

    ***************************************************************************/

    private void handleCmd ( cstring request_ln )
    {
        auto trimmed_request_ln = ChrSplitIterator.trim(request_ln);

        if (!trimmed_request_ln.length)
            return;

        scope split_cmd = new ChrSplitIterator(' ');
        split_cmd.reset(trimmed_request_ln);

        cstring cmd = split_cmd.trim(split_cmd.next());

        if (auto handler = cmd in this.handlers)
        {
            (*handler)(split_cmd.trim(split_cmd.remaining), &this.sendResponse);
        }
        else
        {
            this.writer.send("Command not found\n");
        }
    }

    /***************************************************************************

        Writes `response` to the client socket. This method is passed to the
        user's command handler as a delegate.

        Params:
            response = a string to write to the client socket.

    ***************************************************************************/

    private void sendResponse ( cstring response )
    {
        this.writer.send(response);
    }
}
