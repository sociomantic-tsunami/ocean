/*******************************************************************************

    Utility for handling requests via a unix socket.

    Commands can be registered to the registry and when the command is received
    the provided delegate will be called. Any provided arguments will be split
    by the space character and provided as an array.

    Copyright:
        Copyright (c) 2009-2018 Sociomantic Labs GmbH.
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

    /// Alias for our interactive handler delegate.
    public alias void delegate ( cstring[],
            void delegate (cstring),
            void delegate (ref mstring) ) InteractiveHandler;

    /// Alias for our non-interactive handler delegate.
    public alias void delegate ( cstring[],
            void delegate (cstring) ) Handler;

    /// Our registered map of interactive handlers by command.
    private InteractiveHandler[istring] interactive_handlers;

    /// Our registered map of handlers by command.
    private Handler[istring] handlers;

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

    ***************************************************************************/

    public void handle ( cstring command, cstring args,
                 void delegate (cstring) send_response,
                 void delegate (ref mstring buf) wait_reply )
    {
        if (auto handler = command in this.interactive_handlers)
        {
            split(args, " ", this.args_buf);
            scope predicate = (cstring v) { return !v.length; };
            auto arguments = this.args_buf[0..filterInPlace(this.args_buf[], predicate)];
            (*handler)(arguments, send_response, wait_reply);
        }
        else if (auto handler = command in this.handlers)
        {
            split(args, " ", this.args_buf);
            scope predicate = (cstring v) { return !v.length; };
            auto arguments = this.args_buf[0..filterInPlace(this.args_buf[], predicate)];
            (*handler)(arguments, send_response);
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
        InteractiveHandler handler )
    {
        this.interactive_handlers[command] = handler;
    }

    /***************************************************************************

        Register a command and a handler the registry.

        Params:
            command = The command name
            handler = The handler to call when command is received.

    ***************************************************************************/

    public void addHandler ( istring command, Handler handler )
    {
        this.handlers[command] = handler;
    }

    /***************************************************************************

        Register a command and handler to the unix listener.

        Params:
            command = The command name of the command to remove from the registry

    ***************************************************************************/

    public void removeHandler ( istring command )
    {
        this.handlers.remove(command);
    }
}
