/******************************************************************************

    Real time clock, obtains the current UNIX wall clock time in µs.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.time.MicrosecondsClock;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.time.Time;
import ocean.stdc.posix.sys.time: timeval, gettimeofday;
import core.sys.posix.time: gmtime_r, localtime_r;
import core.stdc.time: tm, time_t;
import ocean.core.TypeConvert;

version ( UnitTest )
{
    import ocean.core.Test;
}

/******************************************************************************/

class MicrosecondsClock
{
    /**************************************************************************

        timeval struct alias, defined as

        ---
        struct timeval
        {
            time_t tv_sec;  // UNIX time in s
            int    tv_usec; // µs in the current second
        }
        ---

     **************************************************************************/

    alias .timeval timeval;

    /**************************************************************************

        Returns:
            the current UNIX wall clock time in µs.

     **************************************************************************/

    static public ulong now_us ( )
    {
        return us(now);
    }

    /**************************************************************************

        Usage tips: use

        ---
            MicrosecondsClock.now.tv_sec
        ---

        to obtain the UNIX timestamp of the current wall clock time or

        ---
            with (MicrosecondsClock.now.tv_sec)
            {
                // tv_sec:  UNIX timestamp of the current wall clock time
                // tv_usec: µs in the current second
            }
        ---

        to get the current UNIX time split into seconds and microseconds.

        Returns:
            the current UNIX wall clock time.

     **************************************************************************/

    static public timeval now ( )
    {
        timeval t;

        gettimeofday(&t, null);

        return t;
    }

    /**************************************************************************

        Converts t to a single integer value representing the number of
        microseconds.

        Params:
            t = timeval value to convert to single microseconds value

        Returns:
            number of microseconds

     **************************************************************************/

    static public ulong us ( timeval t )
    in
    {
        static if (is (t.tv_sec : int))
        {
            static assert (cast (ulong) t.tv_sec.max <                          // overflow check
                          (cast (ulong) t.tv_sec.max + 1) * 1_000_000);
        }
    }
    body
    {
        return t.tv_sec * 1_000_000UL + t.tv_usec;
    }

    /***************************************************************************

        Converts `t` to a tm struct, specifying the year, months, days, hours,
        minutes, and seconds.

        Params:
            t = time in seconds to convert
            local = true: return local time, false: return GMT.

        Returns:
            the t as tm struct.

        Out:
            DST can be enabled with local time only.

    ***************************************************************************/

    static public tm toTm ( time_t t, bool local = false )
    out (datetime)
    {
        assert (local || datetime.tm_isdst <= 0, "DST enabled with GMT");
    }
    body
    {
        tm datetime;

        // actually one should check the return value of localtime_r() and
        // gmtime_r(), but in this usage they should never fail
        (local? &localtime_r : &gmtime_r)(&t, &datetime);

        return datetime;
    }

    unittest
    {
        time_t sec = 1460103457;
        auto t = toTm(sec);

        // Just compare the raw time values
        t.tm_gmtoff = t.tm_gmtoff.init;
        t.tm_zone = t.tm_zone.init;

        test!("==")(t, tm(37, 17, 8, 8, 3, 116, 5, 98, 0));
    }

    /***************************************************************************

        Converts `t` to a tm struct, specifying the year, months, days, hours,
        minutes, and seconds, plus the microseconds via an out parameter.

        Params:
            t = timeval struct to convert
            us = receives the remainder number of microseconds (not stored in
                the returned tm struct)

        Returns:
            tm struct containing everything.

    ***************************************************************************/

    static public tm toTm ( timeval t, out ulong us )
    {
        us = t.tv_usec;
        return toTm(t.tv_sec);
    }

    unittest
    {
        timeval tv;
        tv.tv_sec = 1460103457;
        tv.tv_usec = 1095;
        ulong us;
        auto t = toTm(tv, us);

        // Just compare the raw time values
        t.tm_gmtoff = t.tm_gmtoff.init;
        t.tm_zone = t.tm_zone.init;

        test!("==")(t, tm(37, 17, 8, 8, 3, 116, 5, 98, 0));
        test!("==")(us, 1095);
    }

    /***************************************************************************

        Converts `t` to a DateTime struct, specifying the year, months, days,
        hours, minutes, seconds, and milliseconds, plus the microseconds via an
        out parameter.

        Params:
            t = timeval struct to convert
            us = receives the remainder number of microseconds (not stored in
                the returned DateTime struct)

        Returns:
            DateTime struct containing everything.

    ***************************************************************************/

    static public DateTime toDateTime ( timeval t, out ulong us )
    {
        with (t) with (toTm(tv_sec))
        {
            DateTime dt;

            dt.date.day   = tm_mday;
            dt.date.year  = tm_year + 1900;
            dt.date.month = tm_mon  + 1;
            dt.date.dow   = tm_wday;
            dt.date.doy   = tm_yday + 1;

            dt.time.hours   = tm_hour;
            dt.time.minutes = tm_min;
            dt.time.seconds = tm_sec;

            auto usec = tv_usec / 1000;
            assert (usec <= uint.max);
            assert (usec >= 0);
            dt.time.millis = castFrom!(long).to!(uint)(usec);

            us = tv_usec % 1000;

            return dt;
        }
    }

    unittest
    {
        timeval tv;
        tv.tv_sec = 1460103457;
        tv.tv_usec = 1095;
        ulong us;
        auto dt = toDateTime(tv, us);
        test!("==")(dt,
            DateTime(Date(0, 8, 2016, 4, 5, 99), TimeOfDay(8, 17, 37, 1)));
        test!("==")(us, 95);
    }
}
