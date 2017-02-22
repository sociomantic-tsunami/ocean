/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: May 2004

        Authors: Kris

*******************************************************************************/

module ocean.util.log.LayoutChainsaw;

import ocean.transition;

import ocean.core.Thread;

import ocean.util.log.Appender;
import ocean.util.log.Event;
import ocean.util.log.Log;

/*******************************************************************************

        A layout with XML output conforming to Log4J specs.

*******************************************************************************/

public class LayoutChainsaw : Appender.Layout
{
        /***********************************************************************

                Subclasses should implement this method to perform the
                formatting of the actual message content.

        ***********************************************************************/

        void format (LogEvent event, size_t delegate(Const!(void)[]) dg)
        {
                char[20] tmp;
                istring  threadName;

                threadName = Thread.getThis.name;
                if (threadName.length is 0)
                    threadName = "{unknown}";

                dg ("<log4j:event logger=\"");
                dg (event.name);
                dg ("\" timestamp=\"");
                dg (event.toMilli (tmp, event.time.span));
                dg ("\" level=\"");
                dg (event.levelName);
                dg ("\" thread=\"");
                dg (threadName);
                dg ("\">\r\n<log4j:message><![CDATA[");

                dg (event.toString);

                dg ("]]></log4j:message>\r\n<log4j:properties><log4j:data name=\"application\" value=\"");
                dg (event.host.label);
                dg ("\"/><log4j:data name=\"hostname\" value=\"");
                auto c = cast(Hierarchy) event.host;
                dg (c !is null ? c.address : "localhost");
                dg ("\"/></log4j:properties></log4j:event>\r\n");
        }
}
