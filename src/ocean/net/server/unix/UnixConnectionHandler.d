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

    The constructor takes a command handler that must contain a method matching

    ```
        void handle ( cstring command, cstring args,
                      void delegate ( cstring response ) send_response )

    ```

    where `command` is the name of the command (as explained above), args is
    everything after the command and `send_response` sends the `response` string
    to the client. Note that the response should end in a '\n' newline
    character, which is not automatically added.

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

import ocean.io.select.EpollSelectDispatcher;
import ocean.io.select.protocol.fiber.FiberSelectReader;
import ocean.io.select.protocol.fiber.FiberSelectWriter;

import ocean.sys.socket.UnixSocket;
import ocean.io.select.protocol.generic.ErrnoIOException : SocketError;

import ocean.util.log.Logger;
import ocean.text.util.SplitIterator: ChrSplitIterator;
import ocean.core.array.Mutation : copy;

/// Provides basic command handling functionality for unix socket commands.
public class BasicCommandHandler
{
    /// Alias for a command handler response delegate.
    public alias void delegate ( cstring,  void delegate (cstring) ) Handler;

    /// Map of command name to handler response delegate.
    public Handler[istring] handlers;

    /***************************************************************************

        Constructor

        Params:
            handlers = Array of command string to handler delegate.

    ***************************************************************************/

    public this ( Handler[istring] handlers )
    {
        this.handlers = handlers;
    }

    /***************************************************************************

        Receive the command from the unix socket and call appropriate handler
        delegate if registered.

        Params:
            command = Command received from unix socket.
            args = Arguments provided (if any).
            send_response = Delegate to send a response to the unix socket.

    ***************************************************************************/

    public void handle ( cstring command, cstring args,
        scope void delegate ( cstring ) send_response )
    {
        if (auto handler = command in this.handlers)
        {
            (*handler)(args, send_response);
        }
        else
        {
            send_response("Command not found\n");
        }
    }
}

/// Provides default functionality for handling unix socket commands.
public class UnixConnectionHandler : UnixSocketConnectionHandler!(BasicCommandHandler)
{
    /***************************************************************************

        Constructor.

        Params:
            finalize_dg  = internal select listener parameter for super class
            epoll        = epoll select dispatcher to use for I/O
            handlers     = Array of command to handler delegate.
            address_path = the path of the server socket address, for logging

    ***************************************************************************/

    public this ( FinalizeDg finalize_dg, EpollSelectDispatcher epoll,
                  BasicCommandHandler.Handler[istring] handlers,
                  istring address_path )
    {
        super(finalize_dg, epoll, new BasicCommandHandler(handlers),
            address_path);
    }
}

/*******************************************************************************

    Params:
        CommandHandlerType = The handler type that will process commands
                             received by the socket. Must contain a
                             `void handle ( cstring, cstring, void delegate
                             ( cstring ) )` method.

*******************************************************************************/

public class UnixSocketConnectionHandler ( CommandHandlerType ) : IFiberConnectionHandler
{

    /***************************************************************************

        Responder to process the received commands.

    ***************************************************************************/

    private CommandHandlerType handler;

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
            handler      = processes incoming commands.
            address_path = the path of the server socket address, for logging

    ***************************************************************************/

    public this ( FinalizeDg finalize_dg, EpollSelectDispatcher epoll,
                  CommandHandlerType handler, istring address_path )
    {
        super(epoll, new UnixSocket, finalize_dg);
        auto e = new SocketError(this.socket);
        this.reader = new FiberSelectReader(this.socket, this.fiber, e, e);
        this.writer = new FiberSelectWriter(this.socket, this.fiber, e, e);
        this.address_path = address_path;
        this.handler = handler;
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

        Splits `request_ln` into command and arguments. The handler's `handle`
        method is called with the command, arguments and the send response
        delegate. If `request_ln` is empty or contains only white space,
        nothing is done.

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

        this.handler.handle(cmd, split_cmd.remaining, &this.sendResponse);
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
