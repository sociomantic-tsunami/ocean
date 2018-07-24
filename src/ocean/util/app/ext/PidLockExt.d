/*******************************************************************************

    Application extension to try to lock the pid file.

    If `[PidLock]` section with the `path` member is found in the config file,
    application will try to lock the file specified by `path` and it will abort
    the execution if that fails, making sure only one application instance per
    pid-lock file is running.

    The pid-lock file contains pid of the application that locked the file, and
    it's meant for the user inspection - the locking doesn't depend on this
    data.

    This extension should be use if it's critical that only one instance of the
    application is running (say, if sharing the working directory between two
    instances will corrupt data).

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.ext.PidLockExt;

import ocean.util.app.model.ExtensibleClassMixin;
import ocean.util.app.model.IApplicationExtension;
import ocean.util.app.ext.model.IConfigExtExtension;

import ocean.transition;


/// ditto
class PidLockExt : IConfigExtExtension, IApplicationExtension
{
    import ocean.application.components.PidLock;

    /***************************************************************************

        Pid lock wrapper

    ***************************************************************************/

    private PidLock pid;

    /***************************************************************************

        Order set to -1500, as the extension should run after ConfigExt (-10000)
        but before LogExt (-1000) (as LogExt can create side effects).

        Returns:
            the extension order

    ***************************************************************************/

    public override int order ( )
    {
        return -1500;
    }

    /***************************************************************************

        Parse the configuration file options to set up the loggers.

        Params:
            app = the application instance
            config = configuration instance

    ***************************************************************************/

    public override void processConfig ( IApplication app, ConfigParser config )
    {
        this.pid.parseConfig(config);
    }

    /***************************************************************************

        Tries to lock the pid file.

        Throws:
            Exception if the locking is not successful.

    ***************************************************************************/

    public override void preRun ( IApplication app, istring[] cl_args )
    {
        this.pid.lock();
    }

    /***************************************************************************

        Cleans up behind and releases the lock file.

        Params:
            app = the application instance that will run
            args = command line arguments used to invoke the application
            status = exit status returned by the application
            exception = exit exception instance, if one was thrown (null
                otherwise)

        Throws:
            ErrnoException if any of the system calls fails

    ***************************************************************************/

    public override void atExit ( IApplication app, istring[] args, int status,
            ExitException exception )
    {
        this.pid.unlock();
    }

    /***************************************************************************

        Unused IApplicationExtension methods.

        We just need to provide an "empty" implementation to satisfy the
        interface.

    ***************************************************************************/

    /// ditto
    public override void postRun ( IApplication app, istring[] args, int status )
    {
        // Unused
    }

    /// ditto
    public override ExitException onExitException ( IApplication app,
            istring[] args, ExitException exception )
    {
        // Unused
        return exception;
    }

    /***************************************************************************

        Unused IConfigExtExtension methods.

        We just need to provide an "empty" implementation to satisfy the
        interface.

        Params:
            app = the application instance
            config = configuration instance

    ***************************************************************************/

    public override void preParseConfig ( IApplication app, ConfigParser config )
    {
        // Unused
    }


    /***************************************************************************

        Function to filter the list of configuration files to parse.
        Only present to satisfy the interface

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
}
