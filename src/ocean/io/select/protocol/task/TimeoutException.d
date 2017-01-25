/*******************************************************************************

    Exception thrown on I/O timeout

    Copyright:
        Copyright (c) 2017 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.protocol.task.TimeoutException;

class TimeoutException: Exception
{
    import ocean.transition;

    this ( istring file = __FILE__, int line = __LINE__ )
    {
        super("I/O timeout", file, line);
    }
}
