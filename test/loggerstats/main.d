/*******************************************************************************

    Tests the Log.stats() API

    Copyright:      Copyright (c) 2016 sociomantic labs. All rights reserved

*******************************************************************************/

module test.loggerstats.main;

import ocean.util.log.Log;
import ocean.core.Test;
import ocean.io.device.File;


/*******************************************************************************

  Runs the test

*******************************************************************************/

void main ( )
{
    auto dev_null = new File("/dev/null", File.WriteAppending);
    Log.config(dev_null);

    auto log1 = Log.lookup("MyLog1");
    log1.level = log1.Error;

    auto log2 = Log.lookup("MyLog2");
    log2.level = log2.Warn;

    // Confirm that stats are auto reset
    for (auto i = 0; i < 3; i++)
    {
        // Will emit
        log1.fatal("Oh no");
        log1.error("Oh no");
        log2.fatal("Oh no");
        log2.error("Oh no");
        log2.warn("Oh no");

        // Will not emit
        log1.warn("Shouldn't count");
        log1.info("Shouldn't count");
        log2.trace("Shouldn't count");

        auto stats = Log.stats();

        test!("==")(stats.logged_fatal, 2);
        test!("==")(stats.logged_error, 2);
        test!("==")(stats.logged_warn, 1);
        test!("==")(stats.logged_info, 0);
        test!("==")(stats.logged_trace, 0);
    }
}
