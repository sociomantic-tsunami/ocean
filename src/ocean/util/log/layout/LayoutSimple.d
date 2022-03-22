/*******************************************************************************

    Simple Layout to be used with the tango logger

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.log.layout.LayoutSimple;

import ocean.text.convert.Formatter;
import ocean.meta.types.Qualifiers;
import ocean.util.log.Appender;
import ocean.util.log.Event;
import ocean.util.log.ILogger;

version (unittest)
{
    import ocean.core.Test;
}

/*******************************************************************************

   A simple layout, prefixing each message with the log level and
   the name of the logger.

   Example:
   ------
   import ocean.util.log.layout.LayoutSimple;
   import ocean.util.log.Logger;
   import ocean.util.log.AppendConsole;


   Log.root.clear;
   Log.root.add(new AppendConsole(new LayoutSimple));

   auto logger = Log.lookup("Example");

   logger.trace("Trace example");
   logger.error("Error example");
   logger.fatal("Fatal example");
   -----

   Produced output:
   -----
   Trace [Example] - Trace example
   Error [Example] - Error example
   Fatal [Example] - Fatal example
   ----

*******************************************************************************/

public class LayoutSimple : Appender.Layout
{
    /***************************************************************************

        Subclasses should implement this method to perform the formatting
        of the actual message content.

    ***************************************************************************/

    public override void format (LogEvent event, scope FormatterSink dg)
    {
        sformat(dg, "{} [{}] - {}", ILogger.convert(event.level), event.name, event.msg);
    }
}

unittest
{
    mstring result = new mstring(2048);
    result.length = 0;
    assumeSafeAppend(result);

    scope dg = (cstring v) { result ~= v; };
    scope layout = new LayoutSimple();
    LogEvent event = {
        msg: "Have you met Ted?",
        name: "Barney",
        level: ILogger.Level.Warn,
    };

    testNoAlloc(layout.format(event, dg));
    test!("==")(result, "Warn [Barney] - Have you met Ted?");
}
