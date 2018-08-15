/*******************************************************************************

    Test for the TimerExt behaviour.

    Copyright:
        Copyright (c) 2017 sociomantic labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).


*******************************************************************************/

module integrationtest.timerext.main;

import ocean.transition;
import ocean.core.Test;
import ocean.util.app.Application;
import ocean.util.app.ext.TimerExt;
import ocean.util.test.DirectorySandbox;
import ocean.io.device.File;

class App : Application
{
    import ocean.io.select.EpollSelectDispatcher;
    import ocean.transition;

    private EpollSelectDispatcher epoll;
    private TimerExt timers;
    private int trigger_count;

    public this ( )
    {
        super("", "");

        this.epoll = new EpollSelectDispatcher;
        this.timers = new TimerExt(this.epoll);
        this.registerExtension(this.timers);
    }

    override protected int run ( istring[] args )
    {
        // Register some timed events
        this.timers.register(&this.first, 0.0001);
        this.timers.register(&this.second, 0.0002);
        this.timers.register(&this.third, 0.0003);

        this.epoll.eventLoop();

        return 0;
    }

    private bool first ( )
    {
        return false;
    }

    private bool second ( )
    {
        this.trigger_count++;
        if (this.trigger_count < 3)
        {
            throw new Exception("throw from the handler.");
        }
        else
        {
            return false;
        }
    }

    private bool third ( )
    {
        return false;
    }
}

version(UnitTest) {} else
void main (istring[] args)
{
    auto sandbox = DirectorySandbox.create(["etc", "log"]);

    File.set("etc/config.ini", "[LOG.Root]\n" ~
               "console = false\n");

    auto app = new App;

    test!("==")(app.main(args), 0);
    test!("==")(app.trigger_count, 3);
}
