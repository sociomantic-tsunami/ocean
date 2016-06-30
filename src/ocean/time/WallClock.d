/*******************************************************************************

        Copyright:
            Copyright (c) 2007 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Apr 2007: split away from utc

        Authors: Kris

*******************************************************************************/

module ocean.time.WallClock;

public  import ocean.time.Time;

import ocean.time.Clock;

import ocean.sys.Common;

/******************************************************************************

        Exposes wall-time relative to Jan 1st, 1 AD. These values are
        based upon a clock-tick of 100ns, giving them a span of greater
        than 10,000 years. These Units of time are the foundation of most
        time and date functionality in Tango contributors.

        Please note that conversion between UTC and Wall time is performed
        in accordance with the OS facilities. In particular, Win32 systems
        behave differently to Posix when calculating daylight-savings time
        (Win32 calculates with respect to the time of the call, whereas a
        Posix system calculates based on a provided point in time). Posix
        systems should typically have the TZ environment variable set to
        a valid descriptor.

*******************************************************************************/

struct WallClock
{
        version (Posix)
        {
                /***************************************************************

                        Return the current local time

                ***************************************************************/

                static Time now ()
                {
                        tm t = void;
                        timeval tv = void;
                        gettimeofday (&tv, null);
                        localtime_r (&tv.tv_sec, &t);
                        tv.tv_sec = timegm (&t);
                        return Clock.convert (tv);
                }

                /***************************************************************

                        Return the timezone relative to GMT. The value is
                        negative when west of GMT

                ***************************************************************/

                static TimeSpan zone ()
                {
                        version (darwin)
                                {
                                timezone_t tz = void;
                                gettimeofday (null, &tz);
                                return TimeSpan.fromMinutes(-tz.tz_minuteswest);
                                }
                             else
                                return TimeSpan.fromSeconds(-timezone);
                }

                /***************************************************************

                        Set fields to represent a local version of the
                        current UTC time. All values must fall within
                        the domain supported by the OS

                ***************************************************************/

                static DateTime toDate ()
                {
                        return toDate (Clock.now);
                }

                /***************************************************************

                        Set fields to represent a local version of the
                        provided UTC time. All values must fall within
                        the domain supported by the OS

                ***************************************************************/

                static DateTime toDate (Time utc)
                {
                        DateTime dt = void;
                        auto timeval = Clock.convert (utc);
                        dt.time.millis = cast(uint) (timeval.tv_usec / 1000);

                        tm t = void;
                        localtime_r (&timeval.tv_sec, &t);

                        dt.date.year    = t.tm_year + 1900;
                        dt.date.month   = t.tm_mon + 1;
                        dt.date.day     = t.tm_mday;
                        dt.date.dow     = t.tm_wday;
                        dt.date.era     = 0;
                        dt.time.hours   = t.tm_hour;
                        dt.time.minutes = t.tm_min;
                        dt.time.seconds = t.tm_sec;

                        Clock.setDoy(dt);
                        return dt;
                }

                /***************************************************************

                        Convert Date fields to local time

                ***************************************************************/

                static Time fromDate (ref DateTime dt)
                {
                        tm t = void;

                        t.tm_year = dt.date.year - 1900;
                        t.tm_mon  = dt.date.month - 1;
                        t.tm_mday = dt.date.day;
                        t.tm_hour = dt.time.hours;
                        t.tm_min  = dt.time.minutes;
                        t.tm_sec  = dt.time.seconds;

                        auto seconds = mktime (&t);
                        return Time.epoch1970 + TimeSpan.fromSeconds(seconds)
                                              + TimeSpan.fromMillis(dt.time.millis);
                }
        }

        /***********************************************************************

        ***********************************************************************/

        static Time toLocal (Time utc)
        {
                auto mod = utc.ticks % TimeSpan.TicksPerMillisecond;
                auto date=toDate(utc);
                return Clock.fromDate(date) + TimeSpan(mod);
        }

        /***********************************************************************

        ***********************************************************************/

        static Time toUtc (Time wall)
        {
                auto mod = wall.ticks % TimeSpan.TicksPerMillisecond;
                auto date=Clock.toDate(wall);
                return fromDate(date) + TimeSpan(mod);
        }
}


version (Posix)
{
    version (darwin) {}
    else
    {
        static this()
        {
            tzset();
        }
    }
}
