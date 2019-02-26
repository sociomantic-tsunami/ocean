/*******************************************************************************

    Set of files which are reopened upon calling the reopenAll() method. The
    extension cooperates with the SignalExt, allowing the registered set of
    files to be reopened when a specific signal is received by the application.
    The constructor provides a convenient means to configure this behaviour.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.ext.ReopenableFilesExt;




import ocean.transition;

import ocean.core.Verify;

import ocean.util.app.model.IApplication;
import ocean.util.app.model.IApplicationExtension;

import ocean.util.app.ext.SignalExt;
import ocean.util.app.ext.UnixSocketExt;

import ocean.util.app.ext.model.ISignalExtExtension;

import core.sys.posix.signal : SIGHUP;

import ocean.io.device.File;


public class ReopenableFilesExt : IApplicationExtension, ISignalExtExtension
{
    import ocean.application.components.OpenFiles;

    /// TODO
    private OpenFiles files;


    /***************************************************************************

        The code of the signal to trigger reopening the files, when used with
        the SignalExt. See onSignal().

    ***************************************************************************/

    private int reopen_signal;


    /***************************************************************************

        Constructor.

        Optionally registers this extension with the signal extension and
        activates the handling of the specified signal, which will cause the
        registered files to be reopened. For this to happen, a non-null
        `signal_ext` and a non-zero `reopen_signal` must be supplied.

        Params:
            signal_ext = SignalExt instance to register with (defaults to null)
            reopen_signal = signal to trigger reopening of registered files
                (defaults to SIGHUP, and considered only if non-zero and
                `signal_ext` is non-null)

    ***************************************************************************/

    public this ( SignalExt signal_ext = null, int reopen_signal = SIGHUP )
    {
        this.files = new OpenFiles;

        if (signal_ext && reopen_signal)
        {
            this.setupSignalHandler(signal_ext, reopen_signal);
        }
    }


    /***************************************************************************

        Registers this extension with the signal extension and activates the
        handling of the specified signal, which will cause the registered files
        to be reopened.

        Params:
            signal_ext = SignalExt instance
            reopen_signal = signal to trigger reopening of registered files

    ***************************************************************************/

    public void setupSignalHandler ( SignalExt signal_ext,
            int reopen_signal = SIGHUP )
    {
        verify(signal_ext !is null);
        verify(this.reopen_signal == this.reopen_signal.init,
            "Either pass SignalExt to constructor or to setupSignalHandler, " ~
            "not to both.");

        this.reopen_signal = reopen_signal;
        signal_ext.register(this.reopen_signal);
        signal_ext.registerExtension(this);
    }


    /***************************************************************************

        Registers this extension with the unix socket extension and activates the
        handling of the specified unix socket command, which will cause reopening
        files specified as arguments to the command.

        Params:
            unix_socket_ext = UnixSocketExt instance to register with
            reopen_command = command to trigger reopening of the registered
                file (passed as arguments to the command).

    ***************************************************************************/

    public void setupUnixSocketHandler ( UnixSocketExt unix_socket_ext,
            istring reopen_command = "reopen_files" )
    {
        verify(unix_socket_ext !is null);

        unix_socket_ext.addHandler(reopen_command,
            &this.socketReloadCommand);
    }


    /***************************************************************************

        Registers the specified file, to be reopened when reopenAll() is called.

        Params:
            file = file to add to the set of reopenable files

    ***************************************************************************/

    public void register ( File file )
    {
        this.files.register(file);
    }


    /***************************************************************************

        Reopens all registered files.

    ***************************************************************************/

    public void reopenAll ( )
    {
        this.files.reopenAll();
    }


    /***************************************************************************

        Reopens all registered files with the given path

        Params:
            file_path = path of the file to open

        Returns:
            true if the file was registered and reopen, false otherwise.

    ***************************************************************************/

    public bool reopenFile ( cstring file_path )
    {
        return this.files.reopenFile(file_path);
    }

    /***************************************************************************

        Signal handler. Called by SignalExt when a signal occurs. Reopens all
        log files.

        Params:
            signal = signal which fired

    ***************************************************************************/

    public void onSignal ( int signal )
    {
        if ( signal == this.reopen_signal )
        {
            this.reopenAll();
        }
    }

    /****************************************************************************

        Reopen command to trigger from the Unix Domain socket. It reads
        the file names to reload and reloads the appropriate files.

        Params:
            args = list of arguments received from the socket - should contain
                   names of the files to rotate.
            send_response = delegate to send the response to the client

    *****************************************************************************/

    private void socketReloadCommand ( cstring[] args,
            scope void delegate ( cstring response ) send_response )
    {
        if (args.length == 0)
        {
            send_response("ERROR: missing name of the file to rotate.\n");
            return;
        }

        foreach (filename; args)
        {
            if (!this.reopenFile(filename))
            {
                send_response("ERROR: Could not rotate the file '");
                send_response(filename);
                send_response("'\n");
                return;
            }
        }

        send_response("ACK\n");
    }

    /***************************************************************************

        Required by ISignalExtExtension.

        Returns:
            a number to provide ordering to extensions

    ***************************************************************************/

    override public int order ( )
    {
        return -1;
    }


    /***************************************************************************

        Unused IApplicationExtension method.

        We just need to provide an "empty" implementation to satisfy the
        interface.

    ***************************************************************************/

    override public void preRun ( IApplication app, istring[] args )
    {
        // Unused
    }


    /// ditto
    override public void postRun ( IApplication app, istring[] args, int status )
    {
        // Unused
    }


    /// ditto
    override public void atExit ( IApplication app, istring[] args, int status,
            ExitException exception )
    {
        // Unused
    }


    /// ditto
    override public ExitException onExitException ( IApplication app, istring[] args,
            ExitException exception )
    {
        // Unused
        return exception;
    }
}
