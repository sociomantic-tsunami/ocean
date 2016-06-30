/******************************************************************************

    Parses a HTTP compliant date/time string and converts it to the
    UNIX time value

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.net.http.time.HttpTimeParser;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.transition;

import TimeStamp = ocean.text.convert.TimeStamp: rfc1123, rfc850, asctime;

import ocean.time.Time: Date, TimeOfDay;

import ocean.stdc.time: time_t, tm;
import ocean.stdc.posix.time: timegm;

/******************************************************************************

    Parses timestamp, which is expected to be a HTTP compliant date/time string,
    and converts it to the UNIX time value.

        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.3

    Params:
        timestamp = HTTP compliant date/time string
        t         = resulting UNIX time value; changed only if the return value
                    is true

    Returns:
        true if the conversion succeeded or false on parse error or invalid
        date/time value

 ******************************************************************************/

bool parse ( cstring timestamp, ref time_t t )
{
    Date      date;
    TimeOfDay tod;

    bool ok = TimeStamp.rfc1123(timestamp, tod, date) != 0;

    if (!ok)
    {
        ok = TimeStamp.rfc850(timestamp, tod, date) != 0;
    }

    if (!ok)
    {
        ok = TimeStamp.asctime(timestamp, tod, date) != 0;
    }

    if (ok)
    {
        tm timeval;

        with (timeval)
        {
            tm_sec  = tod.seconds;
            tm_min  = tod.minutes;
            tm_hour = tod.hours;
            tm_mday = date.day;
            tm_mon  = date.month - 1;
            tm_year = date.year - 1900;
        }

        time_t t_ = timegm(&timeval);

        ok = t_ >= 0;

        if (ok)
        {
            t = t_;
        }
    }

    return ok;
}

/******************************************************************************

    Using http://www.epochconverter.com/ as reference.

 ******************************************************************************/

unittest
{
    const time_t T = 352716457;

    time_t t;

    bool ok = parse("Fri, 06 Mar 1981 08:47:37 GMT", t);
    assert (ok);
    assert (t == T);

    ok = parse("Friday, 06-Mar-81 08:47:37 GMT", t);
    assert (ok);
    assert (t == T);

    ok = parse("Fri Mar  6 08:47:37 1981", t);
    assert (ok);
    assert (t == T);
}
