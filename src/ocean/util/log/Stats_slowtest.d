/*******************************************************************************

    Test-suite for ocean.util.log.Stats.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.log.Stats_slowtest;

import ocean.core.Test,
       ocean.util.log.Stats;

import ocean.transition;
import ocean.io.device.TempFile;

unittest
{
    class MyStatsLog : StatsLog
    {
        this ( Config config ) { super(config); }

        void test()
        {
            .test!("==")(this.layout[], `x:10`[]);
        }
    }

    class Stats
    {
        int x;
    }

    scope temp_file = new TempFile;

    auto logger = new MyStatsLog(new StatsLog.Config(temp_file.toString()));

    auto stats = new Stats();
    stats.x = 10;

    logger.add(stats);
    logger.test();
}

unittest
{
    scope temp_file = new TempFile;

    class TestLogger : StatsLog
    {
        this ()
        {
            super(new StatsLog.Config(temp_file.toString()));
        }

        void test()
        {
            .test!("==")(
                this.layout[],
                `workers_hired:420 workers_injured:0`
                ~ ` production_line/samsung/phone_built:10000`
                ~ ` production_line/samsung/laptop_built:200`
                ~ ` production_line/apple/phone_built:800`
                ~ ` production_line/apple/laptop_built:100`);
        }
    }

    auto logger = new TestLogger();

    // Stats about a factory
    struct FactoryStats
    {
        ulong workers_hired;
        ulong workers_injured;
    }

    // Stats about a single production line
    struct ProductionLineStats
    {
        ulong phone_built;
        ulong laptop_built;
    }

    FactoryStats stats;
    stats.workers_hired = 420;

    static struct Entry
    {
        istring name;
        ProductionLineStats stats;
    }

    Entry[] entries = [
        Entry("samsung", ProductionLineStats(10_000, 200)),
        Entry("apple", ProductionLineStats(800, 100))
    ];

    // log everything
    logger.add(stats);

    foreach (entry; entries)
        logger.addObject!("production_line")(entry.name, entry.stats);

    logger.test();
}
