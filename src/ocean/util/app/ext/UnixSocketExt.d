/*******************************************************************************

    Application extension for handling requests via a unix socket.

    Commands can be registered to the extension and when the command is received
    the provided delegate will be called. Any provided arguments will be split
    by the space character and provided as an array.

    The socket will be created under the path defined by the config option
    `path` under the `[UNIX_SOCKET]` config group. If the config path is not
    defined then the unix socket will not be created.

    Usage example:
        See unittest following this class.

    Copyright:
        Copyright (c) 2009-2017 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.ext.UnixSocketExt;

import ocean.transition;

import ocean.core.Enforce;
import ocean.util.app.model.IApplication;
import ocean.util.app.model.IApplicationExtension;
import ocean.util.app.ext.model.IConfigExtExtension;

/// ditto
public class UnixSocketExt : IApplicationExtension, IConfigExtExtension
{
    import ocean.core.Buffer;
    import ocean.core.array.Transformation: split;
    import ocean.io.select.EpollSelectDispatcher;
    import ocean.net.server.unix.UnixListener;
    import ocean.util.config.ConfigParser;

    /// Unix listener with custom command handling.
    private UnixSocketListener!(UnixSocketExt) unix_listener;

    /// Stores the command arguments split by " ";
    private cstring[] args_buf;

    /// Alias for our handler delegate.
    public alias void delegate ( cstring[], void delegate (cstring) ) Handler;

    /// Our registered map of handlers by command.
    private Handler[istring] handlers;

    /// Path to create the unix socket.
    private istring path;

    /***************************************************************************

        Initializes the socket listener.

        Params:
            epoll = Epoll instance.

    ***************************************************************************/

    public void initializeSocket ( EpollSelectDispatcher epoll )
    {
        assert(this.unix_listener is null);
        if ( this.path.length > 0 )
        {
            this.unix_listener =
                new UnixSocketListener!(UnixSocketExt)(this.path, epoll, this);
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
    }

    /***************************************************************************

        Receives all commands from the socket and splits the command by " ".
        If a matching command is registered then the command will be called with
        the remaining arguments. This method will be called by the
        UnixSocketListener whenever a command is received.

        Params:
            command = The command received by the unix socket.
            args = The arguments provided with the command.
            send_response = Delegate to call with response string.

    ***************************************************************************/

    public void handle ( cstring command, cstring args,
                         void delegate (cstring) send_response )
    {
        if (auto handler = command in this.handlers)
        {
            split(args, " ", this.args_buf);
            (*handler)(this.args_buf[], send_response);
        }
        else
        {
            send_response("Command not found\n");
        }
    }

    /***************************************************************************

        Register a command and handler to the unix listener.

        Params:
            command = The command to listen for in the socket listener.
            handler = The handler to call when command is received.

    ***************************************************************************/

    public void addHandler ( istring command, Handler handler )
    {
        this.handlers[command] = handler;
    }

    /***************************************************************************

        Register a command and handler to the unix listener.

        Params:
            command = The command to be removed from the listener.

    ***************************************************************************/

    public void removeHandler ( istring command )
    {
        this.handlers.remove(command);
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
        if (this.unix_listener)
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
        return 0;
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
            void delegate ( cstring response ) send_response )
        {
            send_response("Test request received");
        }
    }

    TestApp app = new TestApp;
}
