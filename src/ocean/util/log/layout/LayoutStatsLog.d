/*******************************************************************************

        Slightly modified LayoutDate class. Does NOT output the level.
        Intended for StatsLog.

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: May 2004

        Authors: Kris & Mathias Baumann

*******************************************************************************/

module ocean.util.log.layout.LayoutStatsLog;

import ocean.transition;

import ocean.text.Util;

import ocean.time.Clock,
        ocean.time.WallClock;

import ocean.util.log.Log;

import  Integer = ocean.text.convert.Integer_tango;

/*******************************************************************************

        A layout with ISO-8601 date information prefixed to each message

*******************************************************************************/

public class LayoutStatsLog : Appender.Layout
{
        private bool localTime;

        /***********************************************************************

                Ctor with indicator for local vs UTC time. Default is
                local time.

        ***********************************************************************/

        this (bool localTime = true)
        {
                this.localTime = localTime;
        }

        /***********************************************************************

                Subclasses should implement this method to perform the
                formatting of the actual message content.

        ***********************************************************************/

        void format (LogEvent event, size_t delegate(Const!(void)[]) dg)
        {
                auto level = event.levelName;

                // convert time to field values
                auto tm = event.time;
                auto dt = (localTime) ? WallClock.toDate(tm) : Clock.toDate(tm);

                // format date according to ISO-8601 (lightweight formatter)
                char[20] tmp = void;
                char[256] tmp2 = void;
                dg (layout (tmp2, "%0-%1-%2 %3:%4:%5,%6 ",
                            convert (tmp[0..4],   dt.date.year),
                            convert (tmp[4..6],   dt.date.month),
                            convert (tmp[6..8],   dt.date.day),
                            convert (tmp[8..10],  dt.time.hours),
                            convert (tmp[10..12], dt.time.minutes),
                            convert (tmp[12..14], dt.time.seconds),
                            convert (tmp[14..17], dt.time.millis)));
                dg (event.toString);
        }

        /**********************************************************************

                Convert an integer to a zero prefixed text representation

        **********************************************************************/

        private cstring convert (mstring tmp, long i)
        {
                return Integer.formatter (tmp, i, 'u', '?', 8);
        }
}
