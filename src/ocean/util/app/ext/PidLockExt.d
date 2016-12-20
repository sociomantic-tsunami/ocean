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
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
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
    import ocean.core.Enforce;
    import ocean.text.convert.Formatter;
    import ocean.text.util.StringC;
    import ocean.sys.ErrnoException;
    import ocean.core.Traits: identifier;
    import core.stdc.errno;
    import core.stdc.stdio;
    import core.stdc.stdlib;
    import core.stdc.string;
    import core.sys.posix.unistd: write, close, ftruncate, getpid, unlink;
    import core.sys.posix.sys.stat;
    import core.sys.posix.fcntl;

    /***************************************************************************

        Fd referring to the pidfile.

    ***************************************************************************/

    private int lock_fd;

    /***************************************************************************

        Indicator if the pidfile is locked by this instance.

    ***************************************************************************/

    private bool is_locked;

    /***************************************************************************

        Path to the pidlock file.

    ***************************************************************************/

    private mstring pidlock_path;

    /***************************************************************************

        Order doesn't matter, so return default -> 0

        Returns:
            the extension order

    ***************************************************************************/

    public override int order ( )
    {
        return 0;
    }

    /***************************************************************************

        Parse the configuration file options to set up the loggers.

        Params:
            app = the application instance
            config = configuration instance

    ***************************************************************************/

    public override void processConfig ( IApplication app, ConfigParser config )
    {
        this.pidlock_path = config.get("PidLock", "path", "").dup;
    }

    /***************************************************************************

        Tries to lock the pid file.

        Throws:
            Exception if the locking is not successful.

    ***************************************************************************/

    public override void preRun ( IApplication app, istring[] cl_args )
    {
        if (this.pidlock_path.length)
        {
            istring msg =
                idup("Couldn't lock the pid lock file '" ~ this.pidlock_path
                 ~ "'. Probably another instance of the application is running.");
            enforce(this.tryLockPidFile(), msg);
        }
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
        if (!this.is_locked)
        {
            return;
        }

        // releases the lock and closes the lock file
        this.enforcePosix!(close)(this.lock_fd);
        this.enforcePosix!(unlink)(StringC.toCString(this.pidlock_path));
    }

    /***************************************************************************

        Called to try to create and lock the pidlock file. On success
        this will create and lock the file pointed by `this.pidlock_path`,
        and it will write out the application pid into it.

        Params:
            pidlock = path to the pidlock file

        Returns:
            true if the lock has been successful, false otherwise.

        Throws:
            ErrnoException if any of the system calls fails for unexpected
            reasons

    ***************************************************************************/

    private bool tryLockPidFile ( )
    {
        this.lock_fd = this.enforcePosix!(open)(StringC.toCString(this.pidlock_path),
                O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);

        // TODO these will be available in tango v1.6.0
        const F_SETLK = 6;

        // Lock the pidfile
        flock fl;
        fl.l_type = F_WRLCK;
        fl.l_whence = SEEK_SET;
        fl.l_start = 0;
        fl.l_len = 0;

        if (fcntl(this.lock_fd, F_SETLK, &fl) == -1)
        {
            // Region already locked, can't acquire a lock
            if (errno == EAGAIN || errno == EACCES)
            {
                return false;
            }
            else
            {
                throw (new ErrnoException).useGlobalErrno("fcntl");
            }
        }

        // Clear the any previous contents of the file
        this.enforcePosix!(ftruncate)(this.lock_fd, 0);

        char[512] buf;
        auto pid_string = snformat(buf, "{}\n", getpid());

        this.writeNonInterrupted(this.lock_fd, pid_string);

        this.is_locked = true;
        return true;
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

    /***************************************************************************

        Calls the function with the provided arguments and throws
        new ErrnoException on failure (indicated by -1 return code)

        Params:
            Func = function to call
            args = arguments to call the function with

        Returns:
            return value of Func(args) on success

        Throws:
            new ErrnoException on failure.

    ***************************************************************************/

    static private int enforcePosix(alias Func, Args...)(Args args)
    {
        auto ret = Func(args);

        if (ret == -1)
        {
            throw (new ErrnoException).useGlobalErrno(identifier!(Func));
        }

        return ret;
    }

    /***************************************************************************

        Writes the content of buffer to fd, repeating if interrupted by
        signal.

        Params:
            fd = file descriptor to write to
            buf = buffer contents to write

        Throws:
            ErrnoException on failure.

    ***************************************************************************/

    static private void writeNonInterrupted(int fd, char[] buf)
    {
        int count;
        while (count < buf.length)
        {
			auto written = write(fd, buf.ptr + count,
				buf.length - count);

			if (written < 0)
			{
				if (errno == EINTR)
				{
					continue;
				}
				else
				{
					throw (new ErrnoException).useGlobalErrno("write");
				}
			}

			count += written;
        }
    }
}
