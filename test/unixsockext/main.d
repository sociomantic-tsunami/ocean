/*******************************************************************************

    Test for UnixSocketExt

    Copyright:
        Copyright (c) 2017 sociomantic labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

import ocean.transition;

import core.sys.posix.sys.stat;
import ocean.core.Test;
import ocean.sys.ErrnoException;
import ocean.util.app.DaemonApp;
import ocean.task.Scheduler;
import ocean.task.Task;

class UnixSockListeningApp : DaemonApp
{
    this ( )
    {
        initScheduler(SchedulerConfiguration.init);
        theScheduler.exception_handler = (Task t, Exception e) {
            throw e;
        };

        istring name = "Application";
        istring desc = "Testing unix socket listener mode.";

        DaemonApp.OptionalSettings settings;

        super(name, desc, VersionInfo.init, settings);
    }

    // Called after arguments and config file parsing.
    override protected int run ( Arguments args, ConfigParser config )
    {
        this.startEventHandling(theScheduler.epoll);
        auto errnoexception = new ErrnoException;

        // Let's check the mode of the socket!
        stat_t stats;
        errnoexception.enforceRetCode!(stat)().call("unix.socket", &stats);
        test!("==")((stats.st_mode & ~S_IFMT), Octal!("0600"));

        return 0; // return code to OS
    }

}

import ocean.io.device.File;
import ocean.util.test.DirectorySandbox;

void main(istring[] args)
{
    auto sandbox = DirectorySandbox.create(["etc", "log"]);

    File.set("etc/config.ini", "[LOG.Root]\n" ~
               "console = false\n\n" ~
               "[UNIX_SOCKET]\npath=unix.socket\nmode=0600");

    auto app = new UnixSockListeningApp;
    auto ret = app.main(args);
}
