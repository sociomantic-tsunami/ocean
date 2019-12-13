/*******************************************************************************

   Slightly modified LayoutDate class. Does NOT output the level.
   Intended for StatsLog.

   Copyright:
       Copyright (c) 2004 Kris Bell.
       Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
       All rights reserved.

   License:
       Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
       See LICENSE_TANGO.txt for details.

   Version: Initial release: May 2004

   Authors: Kris & Mathias Baumann

*******************************************************************************/

module ocean.util.log.layout.LayoutStatsLog;

import ocean.transition;
import ocean.text.convert.Formatter;
import ocean.time.Clock;
import ocean.time.WallClock;
import ocean.util.log.Appender;
import ocean.util.log.Event;

version (unittest)
{
    import ocean.core.Test;
    import ocean.util.log.ILogger;
}

/*******************************************************************************

   A layout with ISO-8601 date information prefixed to each message

*******************************************************************************/

public class LayoutStatsLog : Appender.Layout
{
   private bool localTime;

    /***************************************************************************

        Ctor with indicator for local vs UTC time. Default is local time.

    ***********************************************************************/

    public this (bool localTime = true)
    {
        this.localTime = localTime;
    }

    /***************************************************************************

        Subclasses should implement this method to perform the formatting
        of the actual message content.

    ***************************************************************************/

    public override void format (LogEvent event, scope void delegate(cstring) dg)
    {
        // convert time to field values
        const tm = event.time;
        const dt = (localTime) ? WallClock.toDate(tm) : Clock.toDate(tm);

        // format date according to ISO-8601 (lightweight formatter)
        sformat(dg, "{u4}-{u2}-{u2} {u2}:{u2}:{u2},{u3} {}",
            dt.date.year, dt.date.month, dt.date.day,
            dt.time.hours, dt.time.minutes, dt.time.seconds, dt.time.millis,
            event);
    }
}

unittest
{
    mstring result = new mstring(2048);
    result.length = 0;
    enableStomping(result);

    scope dg = (cstring v) { result ~= v; };
    scope layout = new LayoutStatsLog(false);
    LogEvent event = {
        msg_: "Baguette: 420, Radler: +Inf",
        name_: "Irrelevant",
        time_: Time.fromUnixTime(1525048962) + TimeSpan.fromMillis(42),
        level_: ILogger.Level.Warn,
        host_: null,
    };

    testNoAlloc(layout.format(event, dg));
    test!("==")(result, "2018-04-30 00:42:42,042 Baguette: 420, Radler: +Inf");
}
