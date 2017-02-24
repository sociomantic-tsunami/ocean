/******************************************************************************

    Formats an UNIX time value to a HTTP compliant date/time string

    Formats an UNIX time value to a HTTP compliant (RFC 1123) date/time string.
    Contains a static length array as string buffer to provide
    memory-friendliness.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.net.http.time.HttpTimeFormatter;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.transition;
import core.stdc.time:       time_t, tm, time;
import core.sys.posix.time: gmtime_r, localtime_r;
import core.stdc.stdlib:     lldiv;

/******************************************************************************/

struct HttpTimeFormatter
{
    /**************************************************************************

        Date/time string length constant

     **************************************************************************/

    public const size_t ResultLength = "Sun, 06 Nov 1994 08:49:37 GMT".length;

    /**************************************************************************

        Callback function to obtain the wall clock time. By default (null) the
        system time is queried using time() of the C stdlib.
        An application may set its own time function, if desried.

     **************************************************************************/

    public static time_t function ( ) now = null;

    /**************************************************************************

        Date/time string destination buffer

     **************************************************************************/

    private char[ResultLength] buf;

    /**************************************************************************

        Weekday/month name constants

     **************************************************************************/

    private const istring[7]  weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    private const istring[12] months   = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    /**************************************************************************

        Generates a HTTP compliant date/time string (asctime) from t.

        Params:
            t = UNIX time value to be formatted as HTTP date/time string

        Returns:
            HTTP date/time string from UNIX time value t. Do not modify (exposes
            an internal buffer).

        Throws:
            Exception if formatting failed (supposed never to happen)

     **************************************************************************/

    public mstring format ( time_t t )
    {
        return this.format(this.buf, t);
    }

    /**************************************************************************

        Ditto; uses the current wall clock time.

        Returns:
            HTTP date/time string from UNIX time value t. Do not modify (exposes
            an internal buffer).

        Throws:
            Exception if formatting failed (supposed never to happen)

     **************************************************************************/

    public mstring format ( )
    {
        return this.format(this.buf);
    }

    /**************************************************************************

        Generates a HTTP compliant date/time string from t and stores it in dst.
        dst.length must be ResultLength.

        Params:
            dst      = destination string
            t        = UNIX time value to be formatted as HTTP date/time string

        Returns:
            slice to valid result data in dst, starting at dst[0]

         Throws:
            Exception if formatting failed (supposed never to happen)

    **************************************************************************/

    public static mstring format ( mstring dst, time_t t )
    in
    {
        assert (dst.length == ResultLength);
    }
    body
    {
        tm  datetime;

        tm* datetimep = gmtime_r(&t, &datetime);

        if (datetimep is null) throw new Exception("time conversion failed", __FILE__, __LINE__);

        with (*datetimep)
        {
            dst[ 0 ..  3] = weekdays[tm_wday];
            dst[ 3 ..  5] = ", ";
            fmt(dst[ 5 ..  7], tm_mday);
            dst[ 7      ] = ' ';
            dst[ 8 .. 11] = months[tm_mon];
            dst[11      ] = ' ';
            fmt(dst[12 .. 16], tm_year + 1900);
            dst[16      ] = ' ';
            fmt(dst[17 .. 19], tm_hour);
            dst[19      ] = ':';
            fmt(dst[20 .. 22], tm_min);
            dst[22      ] = ':';
            fmt(dst[23 .. 25], tm_sec);
        }

        dst[$ - " GMT".length .. $] = " GMT";

        return dst;
    }

    /**************************************************************************

        Ditto; uses the current wall clock time.

        Params:
            dst = destination string

        Returns:
            slice to valid result data in dst, starting at dst[0]

         Throws:
            Exception if formatting failed (supposed never to happen)

    **************************************************************************/

    public static mstring format ( mstring dst )
    {
        return format(dst, now? now() : time(null));
    }

    /**************************************************************************

        Converts n to a decimal string, left-padding with '0'.
        n must be at least 0 and fit into dst (be less than 10 ^ dst.length).

        Params:
            dst = destination string
            n   = number to convert

    **************************************************************************/

    private static void fmt ( mstring dst, long n )
    in
    {
       assert (n >= 0);
    }
    out
    {
        assert (!n, "decimal formatting overflow");
    }
    body
    {
        foreach_reverse (ref c; dst)
        {
            with (lldiv(n, 10))
            {
                c = cast(char) (rem + '0');
                n = quot;
            }
        }
    }
}


unittest
{
    char[HttpTimeFormatter.ResultLength] buf;
    assert (HttpTimeFormatter.format(buf, 352716457) == "Fri, 06 Mar 1981 08:47:37 GMT");
}
