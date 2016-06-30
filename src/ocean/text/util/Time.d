/*******************************************************************************

    Functions to format time strings.

    Usage example:

    ---

        import ocean.text.util.Time;
        import ocean.stdc.time : time_t;

        time_t timestamp = 23897129;
        char[20] static_str;
        formatTime(timestamp, static_str);

        // static_str now contains "1970-10-04 14:05:29"

        char[] str;
        uint seconds = 94523;

        formatDuration(seconds, str);

        // str now contains "1 day, 2 hours, 15 minutes, 23 seconds"

        formatDurationShort(seconds, str);

        // str now contains "1d2h15m23s"

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.util.Time;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.Enforce;

import ocean.core.Array : copy;

import ocean.stdc.time : gmtime, strftime, time_t, tm;

import ocean.text.convert.Format;



/*******************************************************************************

    Formats a string with the human-readable form of the specified unix
    timestamp. The timestamp is formatted as follows:

        1970-10-04 14:05:29

    Params:
        utc = timestamp to format
        output = slice to destination string buffer, must be long enough to
            contain formatted string (at least 20 characters) -- intended for
            use with a static array

    Returns:
        slice to the string formatted in 'output', may be an empty slice if the
        provided buffer is too small

*******************************************************************************/

public mstring formatTime ( time_t utc, mstring output )
in
{
    assert(output.length >= 20);
}
body
{
    tm time;
    time = *gmtime(&utc);

    const format = "%F %T\0";
    output.length = strftime(output.ptr, output.length, format.ptr, &time);

    return output;
}


/*******************************************************************************

    Formats a string with the number of years, days, hours, minutes & seconds
    specified.

    Params:
        s = number of seconds elapsed
        output = destination string buffer

    Returns:
        formatted string

*******************************************************************************/

public mstring formatDuration ( ulong s, ref mstring output )
{
    output.length = 0;

    bool comma = false;

    /***************************************************************************

        Appends the count of the specified value to the output string, if the
        value is > 0. Also appends a comma first, if this is not the first value
        to be appended to the output string. In this way, a comma-separated list
        of values is built up over multiple calls to this function.

        Params:
            number = value to append
            name = name of quantity

    ***************************************************************************/

    void append ( ulong number, cstring name )
    {
        if ( number > 0 )
        {
            if ( comma ) output ~= ", ";
            Format.format(output, "{} {}{}", number, name,
                number > 1 ? "s" : "");
            comma = true;
        }
    }

    if ( s == 0 )
    {
        output.copy("0 seconds");
    }
    else
    {
        uint years, days, hours, minutes, seconds;
        extractTimePeriods(s, years, days, hours, minutes, seconds);

        append(years,   "year");
        append(days,    "day");
        append(hours,   "hour");
        append(minutes, "minute");
        append(seconds, "second");
    }

    return output;
}


/*******************************************************************************

    Formats a string with the number of years, days, hours, minutes & seconds
    specified. The string is formatted with short names for the time periods
    (e.g. 's' instead of 'seconds').

    Params:
        s = number of seconds elapsed
        output = destination string buffer

    Returns:
        formatted string

*******************************************************************************/

public mstring formatDurationShort ( ulong s, ref mstring output )
{
    output.length = 0;

    /***************************************************************************

        Appends the count of the specified value to the output string, if the
        value is > 0. Also appends a comma first, if this is not the first value
        to be appended to the output string. In this way, a comma-separated list
        of values is built up over multiple calls to this function.

        Params:
            number = value to append
            name = name of quantity

    ***************************************************************************/

    void append ( ulong number, cstring name )
    {
        if ( number > 0 )
        {
            Format.format(output, "{}{}", number, name);
        }
    }

    if ( s == 0 )
    {
        output.copy("0s");
    }
    else
    {
        uint years, days, hours, minutes, seconds;
        extractTimePeriods(s, years, days, hours, minutes, seconds);

        append(years,   "y");
        append(days,    "d");
        append(hours,   "h");
        append(minutes, "m");
        append(seconds, "s");
    }

    return output;
}


/*******************************************************************************

    Works out the number of multiples of various timespans (years, days, hours,
    minutes, seconds) in the provided total count of seconds, breaking the
    seconds count down into constituent parts.

    Params:
        s = total seconds count to extract timespans from
        years = receives the extracted count of years in s
        days = receives the extracted count of days in s
        hours = receives the extracted count of hours in s
        minutes  = receives the extracted count of minutes in s
        seconds = receives the remaining seconds after all other timespans have
            been extracted from s

*******************************************************************************/

public void extractTimePeriods ( ulong s, out uint years, out uint days,
    out uint hours, out uint minutes, out uint seconds )
{
    /***************************************************************************

        Works out the number of multiples of the specified timespan in the total
        count of seconds, and reduces the seconds count by these multiples. In
        this way, when this function is called multiple times with decreasingly
        large timespans, the seconds count can be broken down into constituent
        parts.

        Params:
            timespan = number of seconds in timespan to extract

        Returns:
            number of timespans in seconds

    ***************************************************************************/

    uint extract ( ulong timespan )
    {
        auto extracted = seconds / timespan;
        seconds -= extracted * timespan;
        return cast(uint) extracted;
    }

    const minute_timespan   = 60;
    const hour_timespan     = minute_timespan * 60;
    const day_timespan      = hour_timespan * 24;
    const year_timespan     = day_timespan * 365;

    enforce(s <= uint.max);
    seconds = cast(uint) s;

    years      = extract(year_timespan);
    days       = extract(day_timespan);
    hours      = extract(hour_timespan);
    minutes    = extract(minute_timespan);
}

