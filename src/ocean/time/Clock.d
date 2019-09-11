/*******************************************************************************

        Copyright:
            Copyright (c) 2007 Kris Bell.
            Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Feb 2007: Initial release

        Authors: Kris

*******************************************************************************/

module ocean.time.Clock;

import core.sys.posix.sys.time;
import core.sys.posix.time;
import ocean.core.ExceptionDefinitions;
public import ocean.time.Time;

version (unittest) import ocean.core.Test;

/******************************************************************************

        Exposes UTC time relative to Jan 1st, 1 AD. These values are
        based upon a clock-tick of 100ns, giving them a span of greater
        than 10,000 years. These units of time are the foundation of most
        time and date functionality in Tango contributors.

        Interval is another type of time period, used for measuring a
        much shorter duration; typically used for timeout periods and
        for high-resolution timers. These intervals are measured in
        units of 1 second, and support fractional units (0.001 = 1ms).

*******************************************************************************/

struct Clock
{
        /// Time at which the program started
        private static Time start_time_;

        /// Returns: Time at which the application started
        public static Time startTime ()
        {
            return start_time_;
        }

        static this ()
        {
            start_time_ = Clock.now;
        }

        // copied from Gregorian.  Used while we rely on OS for toDate.
        package static uint[] DaysToMonthCommon = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365];
        package static void setDoy(ref DateTime dt)
        {
            uint doy = dt.date.day + DaysToMonthCommon[dt.date.month - 1];
            uint year = dt.date.year;

            if(dt.date.month > 2 && (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)))
                doy++;

            dt.date.doy = doy;
        }


    /***************************************************************************

        Returns:
            the current time as UTC since the epoch

    ***************************************************************************/

    static Time now ()
    {
        timeval tv = void;
        if (gettimeofday (&tv, null))
            throw new PlatformException ("Clock.now :: Posix timer is not available");

        return convert (tv);
    }

    /***************************************************************************

        Set Date fields to represent the current time.

    ***************************************************************************/

    static DateTime toDate ()
    {
        return toDate(now);
    }

    /***************************************************************************

        Set fields to represent the provided UTC time.

        Note that the conversion is limited by the underlying OS, and will fail
        to operate correctly with Time values beyond the domain, which is
        01-01-1970 on Linux.
        Date is limited to millisecond accuracy at best.

    ***************************************************************************/

    static DateTime toDate (Time time)
    {
        DateTime dt = void;
        auto timeval = convert (time);
        dt.time.millis = cast(uint) (timeval.tv_usec / 1000);

        tm t = void;
        gmtime_r (&timeval.tv_sec, &t);

        dt.date.year    = t.tm_year + 1900;
        dt.date.month   = t.tm_mon + 1;
        dt.date.day     = t.tm_mday;
        dt.date.dow     = t.tm_wday;
        dt.date.era     = 0;
        dt.time.hours   = t.tm_hour;
        dt.time.minutes = t.tm_min;
        dt.time.seconds = t.tm_sec;

        // Calculate the day-of-year
        setDoy(dt);

        return dt;
    }

    /***************************************************************************

        Convert Date fields to Time

        Note that the conversion is limited by the underlying OS, and will fail
        to operate correctly with Time values beyond the domain, which is
        01-01-1970 on Linux.
        Date is limited to millisecond accuracy at best.

    ***************************************************************************/

    static Time fromDate (ref DateTime dt)
    {
        tm t = void;

        t.tm_year = dt.date.year - 1900;
        t.tm_mon  = dt.date.month - 1;
        t.tm_mday = dt.date.day;
        t.tm_hour = dt.time.hours;
        t.tm_min  = dt.time.minutes;
        t.tm_sec  = dt.time.seconds;

        auto seconds = timegm (&t);
        return Time.epoch1970 +
            TimeSpan.fromSeconds(seconds) +
            TimeSpan.fromMillis(dt.time.millis);
    }

    /***************************************************************************

        Convert timeval to a Time

    ***************************************************************************/

    package static Time convert (ref timeval tv)
    {
        return Time.epoch1970 +
            TimeSpan.fromSeconds(tv.tv_sec) +
            TimeSpan.fromMicros(tv.tv_usec);
    }

    /***************************************************************************

        Convert Time to a timeval

    ***************************************************************************/

    package static timeval convert (Time time)
    {
        timeval tv = void;

        TimeSpan span = time - time.epoch1970;
        assert (span >= TimeSpan.zero);
        tv.tv_sec  = cast(typeof(tv.tv_sec)) span.seconds;
        tv.tv_usec = cast(typeof(tv.tv_usec)) (span.micros % 1_000_000L);
        return tv;
    }
}



unittest
{
    auto time = Clock.now;
    auto clock=Clock.convert(time);
    test (Clock.convert(clock) is time);

    time -= TimeSpan(time.ticks % TimeSpan.TicksPerSecond);
    auto date = Clock.toDate(time);

    test (time is Clock.fromDate(date));
}
