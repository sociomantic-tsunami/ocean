/*******************************************************************************

    Utility for handling requests via a unix socket.

    Commands can be registered to the registry and when the command is received
    the provided delegate will be called. Any provided arguments will be split
    by the space character and provided as an array.

    Copyright:
        Copyright (c) 2009-2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.net.server.unix.CommandRegistry;

import ocean.transition;

/// ditto
public class CommandsRegistry
{
    import ocean.core.array.Mutation: filterInPlace;
    import ocean.core.array.Transformation: split;
    import ocean.core.Buffer;
    import ocean.core.Enforce;
    import ocean.core.Verify;
    import ocean.text.convert.Integer;
    import ocean.io.device.IODevice;

    /// Alias for our interactive handler delegate.
    public alias void delegate ( cstring[],
            void delegate (cstring),
            void delegate (ref mstring) ) InteractiveHandler;

    /// Alias for our non-interactive handler delegate.
    public alias void delegate ( cstring[],
            void delegate (cstring) ) Handler;

    /// Alias for the type of handler delegate which accepts
    /// the socket instance for direct control over it
    public alias void delegate ( cstring[], void delegate (cstring),
            void delegate (ref mstring), IODevice socket ) RawSocketHandler;

    /// Our registered map of interactive handlers by command.
    private InteractiveHandler[istring] interactive_handlers;

    /// Our registered map of handlers by command.
    private Handler[istring] handlers;

    /// Registered map of handlers that accept socket by command.
    private RawSocketHandler[istring] handlers_ex;

    /// Stores the command arguments split by " ";
    private cstring[] args_buf;

    /***************************************************************************

        Receives all commands from the socket and splits the command by " ".
        If a matching command is registered then the command will be called with
        the remaining arguments. This method will be called by the
        UnixSocketListener whenever a command is received.

        Params:
            command = The command received by the unix socket.
            args = The arguments provided with the command.
            send_response = Delegate to call with response string.
            wait_reply = Delegate to call to obtain the reply from the user
            socket = connected socket stream

    ***************************************************************************/

    public void handle ( cstring command, cstring args,
                 scope void delegate (cstring) send_response,
                 scope void delegate (ref mstring buf) wait_reply,
                 IODevice socket )
    {
        scope predicate = (cstring v) { return !v.length; };

        // escape the command, remove empty elements.
        scope arguments_split = () {
            split(args, " ", this.args_buf);
            return this.args_buf[0..filterInPlace(this.args_buf[], predicate)];
        };

        if (auto handler = command in this.interactive_handlers)
        {
            auto arguments = arguments_split();
            (*handler)(arguments, send_response, wait_reply);
        }
        else if (auto handler = command in this.handlers)
        {
            auto arguments = arguments_split();
            (*handler)(arguments, send_response);
        }
        else if (auto handler = command in handlers_ex)
        {
            auto arguments = arguments_split();
            (*handler)(arguments, send_response, wait_reply, socket);
        }
        else
        {
            send_response("Command not found\n");
        }
    }

    /***************************************************************************

        Register a command and interactive handler to the unix listener.

        Params:
            command = The command to listen for in the socket listener.
            handler = The interactive handler to call when command is received.

    ***************************************************************************/

    public void addHandler ( istring command,
        scope InteractiveHandler handler )
    {
        this.interactive_handlers[command] = handler;
    }

    /***************************************************************************

        Register a command and a handler the registry.

        Params:
            command = The command name
            handler = The handler to call when command is received.

    ***************************************************************************/

    public void addHandler ( istring command, scope Handler handler )
    {
        this.handlers[command] = handler;
    }

    /***************************************************************************

        Registers a command and the raw socket handler with the registry

        Params:
            command = The command name
            handler = The handler to call when command is received.

    ***************************************************************************/

    public void addHandler ( istring command, scope RawSocketHandler handler )
    {
        this.handlers_ex[command] = handler;
    }

    /***************************************************************************

        Register a command and handler to the unix listener.

        Params:
            command = The command name of the command to remove from the registry

    ***************************************************************************/

    public void removeHandler ( istring command )
    {
        this.handlers.remove(command);
        this.interactive_handlers.remove(command);
        this.handlers_ex.remove(command);
    }
}
