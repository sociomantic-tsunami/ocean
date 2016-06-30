/*******************************************************************************

    A log layout that only displays the message and no extra data such as the
    date, level, etc

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.log.layout.LayoutMessageOnly;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.util.log.Log;



/*******************************************************************************

    A layout with only the message

*******************************************************************************/

public class LayoutMessageOnly : Appender.Layout
{
    /***************************************************************************

        Constructor

    ***************************************************************************/

    this ( )
    {
    }

    /***************************************************************************

        Subclasses should implement this method to perform the
        formatting of the actual message content.

    ***************************************************************************/

    void format (LogEvent event, size_t delegate(Const!(void)[]) dg)
    {
        dg (event.toString);
    }

}

