/*******************************************************************************

    Functions to format time strings.

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

import core.sys.posix.time : gmtime_r;

import ocean.transition;

import ocean.core.Enforce;

import ocean.core.Array : copy;

import core.stdc.time : strftime, time_t, tm;

import ocean.text.convert.Formatter;



/*******************************************************************************

    Formats the given UNIX timestamp into the form specified by the format
    string. If no format string is given, and the length of the destination
    output buffer has been set to at least 20 characters, then the timestamp
    will be formatted into the form `1982-09-15 10:37:29`.

    Refer to the manual page of `strftime` for the various conversion
    specifications that can be used to construct the format string.

    This function should be preferred when formatting the time into a static
    array.

    Params:
        timestamp = timestamp to format
        output = slice to destination string buffer, must be long enough to
            contain the resulting string post-conversion
        format_string = format string to define how the timestamp should be
            formatted, must be null-terminated (defaults to "%F %T\0")
            note that the format string requires an explicit '\0' even if string
            literals are being passed

    Returns:
        slice to the string formatted in 'output', may be an empty slice if the
        provided buffer is too small or if an error occurred

*******************************************************************************/

public mstring formatTime ( time_t timestamp, mstring output,
    cstring format_string = "%F %T\0" )
in
{
    assert(!format_string[$ - 1], "Format string must be null-terminated");
}
body
{
    tm time;
    size_t len;

    if ( gmtime_r(&timestamp, &time) )
    {
        len = strftime(output.ptr, output.length, format_string.ptr, &time);
    }

    return output[0 .. len];
}


/*******************************************************************************

    Formats the given UNIX timestamp into the form specified by the format
    string. If no format string is given, then the timestamp will be formatted
    into the form `1982-09-15 10:37:29`.

    Refer to the manual page of `strftime` for the various conversion
    specifications that can be used to construct the format string.

    This function should be preferred when formatting the time into a dynamic
    array.

    Params:
        timestamp = timestamp to format
        output = slice to destination string buffer
        format_string = format string to define how the timestamp should be
            formatted, must be null-terminated (defaults to "%F %T\0")
            note that the format string requires an explicit '\0' even if string
            literals are being passed
        max_output_len = maximum length of the resulting string post-conversion
            (defaults to 50)

    Returns:
        the formatted string, may be an empty slice if the result exceeds the
        maximum output length specified or if an error occurred

*******************************************************************************/

public mstring formatTimeRef ( time_t timestamp, ref mstring output,
    cstring format_string = "%F %T\0", uint max_output_len = 50 )
{
    output.length = max_output_len;
    enableStomping(output);

    output.length = formatTime(timestamp, output, format_string).length;
    enableStomping(output);

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
    enableStomping(output);

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
            sformat(output, "{} {}{}", number, name,
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
    enableStomping(output);

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
            sformat(output, "{}{}", number, name);
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


version ( UnitTest )
{
    import ocean.core.Test;
}

///
unittest
{
    time_t timestamp = 400934249;
    char[20] static_str;
    char[50] big_static_str;

    test!("==")(formatTime(timestamp, static_str), "1982-09-15 10:37:29");

    // An empty string is returned if the buffer is not large enough
    test!("==")(formatTime(timestamp, static_str, "%A, %d %B %Y %T\0"), "");

    test!("==")(formatTime(timestamp, big_static_str, "%A, %d %B %Y %T\0"),
        "Wednesday, 15 September 1982 10:37:29");

    mstring buf;

    formatTimeRef(timestamp, buf);
    test!("==")(buf, "1982-09-15 10:37:29");

    formatTimeRef(timestamp, buf, "%A, %d %B %Y %T\0");
    test!("==")(buf, "Wednesday, 15 September 1982 10:37:29");

    // An empty string is returned if the resulting string is longer than the
    // maximum length
    formatTimeRef(timestamp, buf,
        "%d/%m/%y, but Americans would write that as %D\0");
    test!("==")(buf, "");

    // A larger maximum length can be set if necessary
    formatTimeRef(timestamp, buf,
        "%d/%m/%y, but Americans would write that as %D\0", 100);
    test!("==")(buf, "15/09/82, but Americans would write that as 09/15/82");

    mstring str;
    uint seconds = 94523;

    formatDuration(seconds, str);
    test!("==")(str, "1 day, 2 hours, 15 minutes, 23 seconds");

    formatDurationShort(seconds, str);
    test!("==")(str, "1d2h15m23s");

    uint years, days, hours, minutes;

    extractTimePeriods(100000000, years, days, hours, minutes, seconds);
    test!("==")(years, 3);
    test!("==")(days, 62);
    test!("==")(hours, 9);
    test!("==")(minutes, 46);
    test!("==")(seconds, 40);
}
