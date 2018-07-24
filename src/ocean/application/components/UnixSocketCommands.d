/*******************************************************************************

    Support for unix socket command handling.

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.application.components.UnixSocketCommands;

/// ditto
public class UnixSocketCommands
{
    import ocean.transition;
    import ocean.core.Enforce;
    import ocean.io.select.EpollSelectDispatcher;
    import ocean.text.convert.Integer;
    import ocean.text.util.StringC;
    import ocean.util.config.ConfigParser;
    import ocean.net.server.unix.CommandRegistry;
    import ocean.net.server.unix.UnixListener;

    /// Path to create the unix socket.
    private istring path;

    /// Mode to apply to the unix socket after binding
    private int mode = -1;

    /// Command registry to handle the commands from the client
    public CommandsRegistry commands;

    /// Handler delegate
    public alias CommandsRegistry.Handler Handler;

    /// Interactive handler delegate
    public alias CommandsRegistry.InteractiveHandler InteractiveHandler;

    /// RawSocketHandler delegate
    public alias CommandsRegistry.RawSocketHandler RawSocketHandler;

    /// Unix listener with dynamic command handling.
    private UnixSocketListener!(CommandsRegistry) unix_listener;

    /***************************************************************************

        Constructor

    ***************************************************************************/

    public this ( )
    {
        this.commands = new CommandsRegistry;
    }

    /***************************************************************************

        Initializes the socket listener and registers it with the provided epoll
        selector.

        Params:
            epoll = Epoll instance.

    ***************************************************************************/

    public void startEventHandling ( EpollSelectDispatcher epoll )
    {
        if (this.path.length)
        {
            this.unix_listener = new UnixSocketListener!(CommandsRegistry)
                (this.path, epoll, this.commands, this.mode);
            epoll.register(this.unix_listener);
        }
    }

    /***************************************************************************

        Setup the unix socket listener if the config for the socket path exists.

        Params:
            config = configuration instance

    ***************************************************************************/

    public void parseConfig ( ConfigParser config )
    {
        this.path = config.get("UNIX_SOCKET", "path", "");

        istring modestr = config.get("UNIX_SOCKET", "mode", "");
        if (modestr.length)
        {
            enforce(toInteger(modestr, this.mode, 8),
                    "Invalid mode for UnixSocket");
        }
    }

    /***************************************************************************

        Shut down the unix listener.

    ***************************************************************************/

    public void shutdown ( )
    {
        if (this.unix_listener !is null)
            this.unix_listener.shutdown();
    }
}
