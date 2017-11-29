/*******************************************************************************

    Test for the CpuMemoryStats.

    Copyright:
        Copyright (c) 2009-2017 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

import ocean.transition;

import ocean.core.Test;
import ocean.sys.ErrnoException;
import ocean.util.app.DaemonApp;
import ocean.io.select.client.TimerEvent;
import ocean.math.IEEE;
import ProcVFS = ocean.sys.stats.linux.ProcVFS;

class MyApp : DaemonApp
{
    import ocean.io.select.EpollSelectDispatcher;
    import ocean.sys.Stats;

    private EpollSelectDispatcher epoll;

    /// Instance of CpuMemoryStats
    private CpuMemoryStats sys_stats;

    this ( )
    {
        this.epoll = new EpollSelectDispatcher;

        istring name = "Application";
        istring desc = "Testing signal handling.";

        DaemonApp.OptionalSettings settings;

        this.sys_stats = new CpuMemoryStats;
        // log first time to avoid zeroes in CPU usage in the first log
        this.sys_stats.collect();

        super(name, desc, VersionInfo.init, settings);
    }

    // Called after arguments and config file parsing.
    override protected int run ( Arguments args, ConfigParser config )
    {
        this.startEventHandling(this.epoll);
        CpuMemoryStats.Stats stats;

        auto uptime = ProcVFS.getProcUptime();
        auto timer = new TimerEvent(
                {
                    // wait until uptime advances, clock might be slower on VMs
                    if (ProcVFS.getProcUptime() == uptime)
                        return true;
                    stats = this.sys_stats.collect();
                    this.epoll.shutdown();

                    return false;
                });

        timer.set(0, 10, 0, 10);
        this.epoll.register(timer);
        this.epoll.eventLoop();

        test!(">=")(stats.cpu_user, 0);
        test!(">=")(stats.cpu_system, 0);
        test!(">=")(stats.cpu_total, 0);
        test!(">")(stats.vsz, 0);
        test!(">")(stats.rss, 0);
        test!(">=")(stats.mem_percentage, 0);

        test!("==")(isInfinity(stats.cpu_user), false);
        test!("==")(isInfinity(stats.cpu_system), false);
        test!("==")(isInfinity(stats.cpu_total), false);
        test!("==")(isInfinity(stats.mem_percentage), false);

        test!("==")(isNaN(stats.cpu_user), false);
        test!("==")(isNaN(stats.cpu_system), false);
        test!("==")(isNaN(stats.cpu_total), false);
        test!("==")(isNaN(stats.mem_percentage), false);

        return 0; // return code to OS
    }

}

import ocean.io.device.File;
import ocean.util.test.DirectorySandbox;

void main(istring[] args)
{
    auto sandbox = DirectorySandbox.create(["etc", "log"]);

    File.set("etc/config.ini", "[LOG.Root]\n" ~
               "console = false\n");

    auto app = new MyApp;
    auto ret = app.main(args);
}
