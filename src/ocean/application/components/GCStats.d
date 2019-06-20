/*******************************************************************************

    Contains API to obtain garbage collector stats.

    Copyright:
        Copyright (c) 2009-2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.application.components.GCStats;

import core.memory;

import ocean.meta.traits.Aggregates : hasMember;
import ocean.meta.types.Function : ParametersOf;
import ocean.time.MicrosecondsClock;

/*******************************************************************************

    Class used for getting used GC stats for the current process. This will
    work only with dmd-transitional.

*******************************************************************************/

public class GCStats
{
    static if ( hasMember!(GC, "monitor") )
    {
        /// The type of the gcEnd delegate
        private alias ParametersOf!(GC.monitor)[1] MonitorEndParams;

        /// Integers used by the gcEnd delegate
        private alias ParametersOf!(MonitorEndParams)[0] MonitorInt;
    }
    else
    {
        pragma(msg, "There will be no gc stats! You need to use dmd transitional:");
        pragma(msg, "https://github.com/sociomantic-tsunami/dmd-transitional");

        /// Default type for integers used by monitor
        private alias long MonitorInt;
    }

    /**********************************************************************

        Structure representing recorded GC stats.

    **********************************************************************/

    public struct Stats
    {
        /**********************************************************************

            The number of microseconds the garbage collector ran for in the
            last stats collection.

        **********************************************************************/

        public size_t gc_run_duration;

        /**********************************************************************

            The percentage of time that was spent by the garbage collector in
            the last stats collection.

        **********************************************************************/

        public float gc_run_percentage = 0;
    }

    /// ditto
    private Stats stats;

    /// Timestamp for when the last garbage collection started
    private ulong gc_start_us;

    /**********************************************************************

        Timestamp for when the last stats were collected used to
        calculate the percentage of the time spent in GC between stats
        cycles.

    **********************************************************************/

    private ulong last_collected_timestamp;

    /**********************************************************************

        Reset statistics.

    **********************************************************************/

    private void reset ( )
    {
        this.last_collected_timestamp = MicrosecondsClock.now_us();
        this.stats.gc_run_duration = 0;
    }

    /**********************************************************************

        Start stats reporting

    **********************************************************************/

    public void start ( )
    {
        static if ( hasMember!(GC, "monitor") )
        {
            GC.monitor(&this.gcBegin, &this.gcEnd);
        }
    }

    /**********************************************************************

        Stop stats reporting

    **********************************************************************/

    public void stop ( )
    {
        static if ( hasMember!(GC, "monitor") )
        {
            GC.monitor(null, null);
        }
    }

    /***************************************************************************

        Get's the GC stats for the current process.

        Returns:
            Stats instance recording the current stats.

    ***************************************************************************/

    public Stats collect ()
    {
        auto result = this.stats;
        this.reset();

        return result;
    }

    /**********************************************************************

        Called each time the GC starts a collection

    **********************************************************************/

    private void gcBegin ( )
    {
        this.gc_start_us = MicrosecondsClock.now_us();
    }

    /***************************************************************************

        Called when the GC completes a collection.

        Params:
            freed = the number of bytes freed overall
            pagebytes = the number of bytes freed within full pages.

    ***************************************************************************/

    private void gcEnd ( MonitorInt freed, MonitorInt pagebytes )
    {
        auto now = MicrosecondsClock.now_us();

        this.stats.gc_run_duration += now - this.gc_start_us;
        this.stats.gc_run_percentage = cast(float)this.stats.gc_run_duration /
            cast(float)(now - last_collected_timestamp);
    }
}
