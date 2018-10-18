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
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.net.server.unix.UnixConnectionHandler;


import ocean.net.server.connection.IFiberConnectionHandler;

import ocean.transition;
import ocean.core.array.Mutation;

import ocean.io.select.EpollSelectDispatcher;
import ocean.io.select.protocol.fiber.FiberSelectReader;
import ocean.io.select.protocol.fiber.FiberSelectWriter;

import ocean.sys.socket.UnixSocket;
import ocean.io.select.protocol.generic.ErrnoIOException : SocketError;

import ocean.util.log.Logger;
import ocean.text.util.SplitIterator: ChrSplitIterator;
import ocean.core.array.Mutation : copy;
import ocean.meta.types.Function;

/// Provides basic command handling functionality for unix socket commands.
public class BasicCommandHandler
{
    /// Alias for an interactive command handler delegate.
    public alias void delegate ( cstring,  void delegate (cstring),
            void delegate (ref mstring)) InteractiveHandler;

    /// Alias for a non-interactive command handler delegate.
    public alias void delegate ( cstring, void delegate (cstring) ) Handler;

    /// Map of command name to interactive handler response delegate.
    public InteractiveHandler[istring] interactive_handlers;

    /// Map of a command name to non-interactive handlers delegate
    public Handler[istring] handlers;

    /***************************************************************************

        Constructor

        Note that handlers and interactive handlers' command names may overlap.
        In that case, the interactive handler is given the priority.

        Params:
            handlers = Array of command string to handler delegate.
            interactive_handlers = Array of command string to interactive handler
                delegate.

    ***************************************************************************/

    public this ( scope Handler[istring] handlers,
            scope InteractiveHandler[istring] interactive_handlers )
    {
        this.handlers = handlers;
        this.interactive_handlers = interactive_handlers;
    }

    /***************************************************************************

        Constructor

        Params:
            handlers = Array of command string to handler delegate.

    ***************************************************************************/

    public this ( scope Handler[istring] handlers )
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
            wait_reply = delegate to get a reply from the unix socket

    ***************************************************************************/

    public void handle ( cstring command, cstring args,
        scope void delegate ( cstring ) send_response,
        scope void delegate (ref mstring) wait_reply)
    {

        if (auto handler = command in this.interactive_handlers)
        {
            (*handler)(args, send_response, wait_reply);
        }
        else if (auto handler = command in this.handlers)
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
            interactive_handlers = Array of command to interactive handler
                                   delegate.
            address_path = the path of the server socket address, for logging

    ***************************************************************************/

    public this ( scope FinalizeDg finalize_dg, EpollSelectDispatcher epoll,
                  scope BasicCommandHandler.Handler[istring] handlers,
                  scope BasicCommandHandler.InteractiveHandler[istring] interactive_handlers,
                  istring address_path )
    {
        super(finalize_dg, epoll,
            new BasicCommandHandler(handlers, interactive_handlers),
            address_path);
    }

    /***************************************************************************

        Constructor.

        Params:
            finalize_dg  = internal select listener parameter for super class
            epoll        = epoll select dispatcher to use for I/O
            handlers     = Array of command to handler delegate.
            address_path = the path of the server socket address, for logging

    ***************************************************************************/

    public this ( scope FinalizeDg finalize_dg, EpollSelectDispatcher epoll,
                  scope BasicCommandHandler.Handler[istring] handlers,
                  cstring address_path )
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

        Buffer to store the partial handler that followed the last occurrence of
        '\n' in the most recently read input data.

    ***************************************************************************/

    private char[] remaining_request_ln;

    /***************************************************************************

        Buffer to store the partial line of a in-command response.

    ***************************************************************************/

    private mstring last_read_line;

    /***************************************************************************

        The Unix domain server socket address for logging.

    ***************************************************************************/

    private cstring address_path;

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

    public this ( scope FinalizeDg finalize_dg, EpollSelectDispatcher epoll,
                  CommandHandlerType handler, cstring address_path )
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

        while (true)
        {
            getNextLine();
            handleCmd(this.last_read_line);
        }
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
            If no newline is found, A value greater than `data.length` so
            that `this.reader.readConsume` continues reading from the socket.
            Otherwise, `data.lenght`, so the reading continues when needed.

    ***************************************************************************/

    private size_t parseLine ( void[] data )
    {
        scope split = new ChrSplitIterator('\n');
        split.include_remaining = false;
        split.reset(cast(char[])data);

        auto before_newline = split.next();

        // no newline found, read more
        if (before_newline.length == data.length)
        {
            this.remaining_request_ln ~= before_newline;
            return data.length + 1;
        }

        // We have read up to newline, leave the line for the user
        // to process, or for this facility to call the next command, and
        // save the optional rest
        this.last_read_line.length = 0;
        enableStomping(this.last_read_line);

        this.last_read_line ~= this.remaining_request_ln;
        this.last_read_line ~= before_newline;

        this.remaining_request_ln.copy(split.remaining());

        return data.length;
    }

    private void getNextLine()
    {
        // do we have more lines in the remaining data?
        scope split = new ChrSplitIterator('\n');

        split.include_remaining = false;
        split.reset(this.remaining_request_ln);

        auto before_newline = split.next();

        if (before_newline.length)
        {
            this.last_read_line.copy(before_newline);
            auto remaining = split.remaining();
            removeShift(this.remaining_request_ln,
                0, remaining_request_ln.length - remaining.length);
            return;
        }


        // else fetch a new one
        this.reader.readConsume(&this.parseLine);
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

        static if (ParametersOf!(typeof(this.handler.handle)).length == 4)
            this.handler.handle(cmd, split_cmd.remaining, &this.sendResponse,
                    &this.waitReply);
        else
            this.handler.handle(cmd, split_cmd.remaining, &this.sendResponse,
                    &this.waitReply, this.socket);
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

    /***************************************************************************

        Reads the input from the client socket. This method is passed to the
        user's command handler as a delegate.

        Params:
            prompt = prompt to send to the user
            buf = buffer to read the response in.

    ***************************************************************************/

    private void waitReply ( ref mstring response )
    {
        this.getNextLine();
        response.copy(this.last_read_line);
    }
}
