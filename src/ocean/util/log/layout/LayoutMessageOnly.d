/*******************************************************************************

    A log layout that only displays the message and no extra data such as the
    date, level, etc

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.log.layout.LayoutMessageOnly;

import ocean.transition;
import ocean.util.log.Appender;
import ocean.util.log.Event;


/// Ditto
public class LayoutMessageOnly : Appender.Layout
{
    /***************************************************************************

        Subclasses should implement this method to perform the
        formatting of the actual message content.

    ***************************************************************************/

    public override void format (LogEvent event, scope void delegate(cstring) dg)
    {
        dg(event.toString);
    }
}
