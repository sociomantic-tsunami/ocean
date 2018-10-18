/*******************************************************************************

    Application extension for handling requests via a unix socket.

    Commands can be registered to the extension and when the command is received
    the provided delegate will be called. Any provided arguments will be split
    by the space character and provided as an array.

    The socket will be created under the path defined by the config option
    `path` under the `[UNIX_SOCKET]` config group. If the config path is not
    defined then the unix socket will not be created. If there's a need to
    setup the permissions mode, config option `mode` will be used to read the
    mode as octal string (usually you want 0600 for this).

    Copyright:
        Copyright (c) 2009-2017 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.ext.UnixSocketExt;

import ocean.transition;
import ocean.core.Verify;

import ocean.core.Enforce;
import ocean.io.select.EpollSelectDispatcher;
import ocean.util.app.model.IApplication;
import ocean.util.app.model.IApplicationExtension;
import ocean.util.app.ext.model.IConfigExtExtension;

/// ditto
public class UnixSocketExt : IApplicationExtension, IConfigExtExtension
{
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
    private CommandsRegistry commands;

    /// Handler delegate
    public alias CommandsRegistry.Handler Handler;

    /// Interactive handler delegate
    public alias CommandsRegistry.InteractiveHandler InteractiveHandler;

    /// RawSocketHandler delegate
    public alias CommandsRegistry.RawSocketHandler RawSocketHandler;

    /// Unix listener with dynamic command handling.
    private UnixSocketListener!(CommandsRegistry) unix_listener;

    /*************************************************************************

        Constructor

    **************************************************************************/

    this ( )
    {
        this.commands = new CommandsRegistry;
    }

    /*************************************************************************

        Initializes the socket listener.

         Params:
            epoll = Epoll instance.

    **************************************************************************/

    public void initializeSocket ( EpollSelectDispatcher epoll )
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
            app = the application instance
            config = configuration instance

    ***************************************************************************/

    public override void processConfig ( IApplication app, ConfigParser config )
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

        Params:
            command = The command to listen for in the socket listener.
            handler = The handler to call when command is received.

    ***************************************************************************/

    deprecated ("Use the appropriate overload of UnixSocketExt.addHandler.")
    public void addInteractiveHandler ( istring command, scope InteractiveHandler handler )
    {
        this.commands.addHandler(command, handler);
    }

    /***************************************************************************

        Params:
            command = The command to listen for in the socket listener.
            handler = The handler to call when command is received.

    ***************************************************************************/

    public void addHandler ( istring command, scope Handler handler )
    {
        this.commands.addHandler(command, handler);
    }

    /***************************************************************************

        Params:
            command = The command to listen for in the socket listener.
            handler = The handler to call when command is received.

    ***************************************************************************/

    public void addHandler ( istring command, scope InteractiveHandler handler )
    {
        this.commands.addHandler(command, handler);
    }

    /***************************************************************************

        Register a command and raw handler to the unix listener.

        Params:
            command = The command to listen for in the socket listener.
            handler = The handler to call when command is received.

    ***************************************************************************/

    public void addHandler ( istring command, scope RawSocketHandler handler )
    {
        this.commands.addHandler(command, handler);
    }

    /***************************************************************************

        Unregister a command and handler from the unix listener.

        Params:
            command = The command to be removed from the listener.

    ***************************************************************************/

    deprecated ("Use UnixSocketExt.removeHandler instead.")
    public void removeInteractiveHandler ( istring command )
    {
        this.commands.removeHandler(command);
    }

    /***************************************************************************

        Unregisters a command and handler to the unix listener.

        Params:
            command = The command to be removed from the listener.

    ***************************************************************************/

    public void removeHandler ( istring command )
    {
        this.commands.removeHandler(command);
    }

    /***************************************************************************

        Shut down the unix listener upon exit of the application.

        Params:
            app = Application instance.
            args = Provided application arguments.
            status = Return code status.
            exception = Exception if exists.

    ***************************************************************************/

    public override void atExit ( IApplication app, istring[] args, int status,
            ExitException exception )
    {
        if (this.unix_listener !is null)
            this.unix_listener.shutdown();
    }

    /***************************************************************************

        Unused IConfigExtExtension method to satisfy interface.

        Params:
            app = the application instance
            config = configuration instance

    ***************************************************************************/

    public override void preParseConfig ( IApplication app, ConfigParser config )
    {
        // Unused
    }

    /***************************************************************************

        Unused IConfigExtExtension method to satisfy interface.

        Params:
            app = the application instance
            config = configuration instance
            files = current list of configuration files to parse

        Returns:
            new list of configuration files to parse

    ***************************************************************************/

    public override istring[] filterConfigFiles ( IApplication app,
                                         ConfigParser config,
                                         istring[] files )
    {
        // Unused
        return files;
    }

    /***************************************************************************

        Return:
            Use the default ordering.

    ***************************************************************************/

    public override int order ( )
    {
        return -1;
    }

    /***************************************************************************

        Unused IApplicationExtension methods to satisfy interface.

    ***************************************************************************/

    public override void preRun ( IApplication app, istring[] args )
    {
    }

    /// ditto
    public override void postRun ( IApplication app, istring[] args, int status )
    {
    }

    /// ditto
    public override ExitException onExitException ( IApplication app, istring[] args,
            ExitException exception )
    {
        return exception;
    }
}

version ( UnitTest )
{
    import ocean.util.app.DaemonApp;
}

///
unittest
{
    class TestApp : DaemonApp
    {
        public this ( )
        {
            super("TestApp", "Test UnixSocketExt", null);
        }

        override public int run ( Arguments args, ConfigParser config )
        {
            this.startEventHandling(new EpollSelectDispatcher);
            this.unix_socket_ext.addHandler("test", &this.test);

            return 0;
        }

        private void test ( cstring[] args,
            scope void delegate ( cstring response ) send_response,
            scope void delegate ( ref mstring response ) wait_reply )
        {
            send_response("Test request received");
        }
    }

    TestApp app = new TestApp;
}
