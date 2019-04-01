/*******************************************************************************

    Handler for time interval CLI arguments

    copyright: Copyright (c) 2018 dunnhumby Germany GmbH. All rights reserved

*******************************************************************************/

module ocean.text.arguments.TimeIntervalArgs;

import core.stdc.time;

import ocean.core.Enforce;
import ocean.text.Arguments;
import ocean.text.convert.DateTime;
import ocean.text.convert.Integer;
import ocean.transition;

version (UnitTest)
{
    import Test = ocean.core.Test;
}

/// Structure reoresenting a Timestamp interval
struct TimestampInterval
{
    /// The timestamp for the beginning of the interval
    long begin;

    /// The timestamp for the end of the interval
    long end;
}



/***************************************************************************

    Add application-specific command line arguments for the selecting a
    time interval

    Params:
        args = The arguments to add to
        required = True if the fields are mandatory

***************************************************************************/

public void setupTimeIntervalArgs ( Arguments args, bool required )
{
    auto interval = args("time-interval")
        .aliased('t')
        .params(2)
        .help("Specify a time interval. It get 2 values, where they can be:\n\t" ~
            "'now' an alias for the current timestamp\n\t" ~
            "an integer for unix timestamps\n\t" ~
            "a time duration `{int}m`. Supported units are [m]inutes, [h]ours and [d]ays\n\t" ~
            "an iso1806 date (YYYY-MM-DD)");

    if ( required )
    {
        interval.required();
    }
}

/***************************************************************************

    Validate the time-interval argument

    Params:
        app = The application
        args = The arguments to add to

    Returns:
        The error message, if any argument failed to validate

***************************************************************************/

public istring validateTimeIntervalArgs ( Arguments args )
{
    if ( args["time-interval"].assigned.length != 2 &&
        args["time-interval"].assigned.length != 0 )
    {
        return "The 'time-interval' argument must have 2 values";
    }

    return null;
}

/***************************************************************************

    Process the time-interval argument

    Params:
        args = The arguments to process
        default_interval = The interval in seconds that should be used when
            dates are not set by the user

***************************************************************************/

public TimestampInterval processTimeIntervalArgs ( Arguments args,
    long default_interval = 60 )
{
    TimestampInterval interval;

    if ( args("time-interval").set && args["time-interval"].assigned.length == 2 )
    {
        cstring begin = args["time-interval"].assigned[0];
        cstring end = args["time-interval"].assigned[1];

        interval.begin = parseDateString(begin, 0);
        interval.end = parseDateString(end, 24 * 3600 - 1);

        if ( isTimeInterval(begin) && isTimeInterval(end) )
        {
            interval.begin = time(null) - parseTimeInterval(begin);
            interval.end = time(null) + parseTimeInterval(end);
        }

        if ( isTimeInterval(begin) && interval.begin == 0 )
        {
            interval.begin = interval.end - parseTimeInterval(begin);
        }

        if ( isTimeInterval(end) && interval.end == 0 )
        {
            interval.end = interval.begin + parseTimeInterval(end);
        }
    }

    if ( interval.begin == 0 && interval.end == 0 )
    {
        interval.begin = time(null) - default_interval;
    }

    if ( interval.begin == 0 )
    {
        interval.begin = time(null);
    }

    if ( interval.end == 0 )
    {
        interval.end = time(null);
    }

    return interval;
}

/**************************************************************************

    Converts a string interval to a unix timestamp. If the value is an
    ISO 8601 date then the date_time will be added to the converted value.

    Params:
        value = `now`, a string timestamp or iso8601 date
        date_time = seconds added to the converted iso8601 timestamp

    Returns:
        an unix timestamp

**************************************************************************/

private long parseDateString ( cstring value, long date_time )
{
    if ( value == "now" )
    {
        return time(null);
    }

    long timestamp;
    if ( toLong(value, timestamp) )
    {
        return timestamp;
    }

    long result;
    DateConversion dummy_conv;
    if ( timeToUnixTime(value, result, dummy_conv) )
    {
        result += date_time;
        return result;
    }

    enforce(isTimeInterval(value), cast(istring) ("`" ~ value ~ "` is an invalid time interval argument. " ~
        "Only `now`, unix timestamp, iso8601 date and durations are permited."));

    return 0;
}

/// Timestamp to use in unit tests;
version ( UnitTest )
{
    // 04/01/2019 @ 3:26pm (UTC)
    const TEST_TIME_NOW = 1554132392;

    /***************************************************************************

        Params
            _unused = Unused.

        Returns:
            Fake "now" time to use within the unit tests.

    ***************************************************************************/

    private time_t time ( tm* _unused )
    {
        return TEST_TIME_NOW;
    }
}

/// Check the date arguments setup
unittest
{
    long dummy_time;
    DateConversion dummy_conv;
    long default_interval = 60;

    auto args = new Arguments;

    /// When there is no begin and end date set
    setupTimeIntervalArgs(args, false);
    args.parse("");
    auto interval = processTimeIntervalArgs(args, default_interval);
    Test.test!("<=")(interval.begin, time(null) - default_interval);
    Test.test!("==")(interval.end, time(null));

    /// When the begin date is provided
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval 2014-03-09 now");
    interval = processTimeIntervalArgs(args);
    timeToUnixTime("2014-03-09 00:00:00", dummy_time, dummy_conv);

    Test.test!("==")(interval.begin, dummy_time);
    Test.test!("==")(interval.end, time(null));

    /// When the end date is provided
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval now 2014-03-09");
    interval = processTimeIntervalArgs(args);
    timeToUnixTime("2014-03-09 23:59:59", dummy_time, dummy_conv);

    Test.test!("==")(interval.begin, time(null));
    Test.test!("==")(interval.end, dummy_time);

    /// When both dates are provided
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval 2014-03-09 2014-03-09");
    interval = processTimeIntervalArgs(args);

    timeToUnixTime("2014-03-09 00:00:00", dummy_time, dummy_conv);
    Test.test!("==")(interval.begin, dummy_time);

    timeToUnixTime("2014-03-09 23:59:59", dummy_time, dummy_conv);
    Test.test!("==")(interval.end, dummy_time);

    /// Using timestamps
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval 1000 1200");
    interval = processTimeIntervalArgs(args);

    Test.test!("==")(interval.begin, 1000);
    Test.test!("==")(interval.end, 1200);

    /// Using interval starting with time duration
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval 1m 1000");
    interval = processTimeIntervalArgs(args);

    Test.test!("==")(interval.begin, 940);
    Test.test!("==")(interval.end, 1000);

    /// Using interval ending with time duration
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval 1000 1m");
    interval = processTimeIntervalArgs(args);

    Test.test!("==")(interval.begin, 1000);
    Test.test!("==")(interval.end, 1060);

    /// Using two time durations
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval 1m 1m");
    interval = processTimeIntervalArgs(args);

    Test.test!("==")(interval.begin, TEST_TIME_NOW - 60);
    Test.test!("==")(interval.end, TEST_TIME_NOW + 60);

    /// Using an invalid argument
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval invalid 1m");
    Test.testThrown!(Exception)(processTimeIntervalArgs(args));
}

/******************************************************************************

    Converts a string to seconds

    Params:
        value = a string containing an integer and the first leter of a time
            unit. The supported units are minutes, hours and days.

    Returns:
        The interval in seconds

******************************************************************************/

public long parseTimeInterval ( cstring value )
{
    if ( value == "" )
    {
        return 0;
    }

    long result;
    long tempValue;

    char unit = value[value.length - 1];

    if ( !toLong(value[0..$-1], tempValue) )
    {
        throw new Exception("The provided time interval has an invalid value.");
    }

    switch ( unit )
    {
        case 's':
            result = tempValue;
            break;

        case 'm':
            result = tempValue * 60;
            break;

        case 'h':
            result = tempValue * 3600;
            break;

        case 'd':
            result = tempValue * 3600 * 24;
            break;

        default:
            throw new Exception("The provided time interval has an invalid unit.");
    }

    return result;
}

///
unittest
{
    Test.test!("==")(parseTimeInterval(""), 0);
    Test.test!("==")(parseTimeInterval("1s"), 1);
    Test.test!("==")(parseTimeInterval("1m"), 60);
    Test.test!("==")(parseTimeInterval("2m"), 120);
    Test.test!("==")(parseTimeInterval("1h"), 3_600);
    Test.test!("==")(parseTimeInterval("2h"), 7_200);
    Test.test!("==")(parseTimeInterval("1d"), 3600 * 24);
    Test.test!("==")(parseTimeInterval("2d"), 3600 * 48);

    Test.testThrown!(Exception)(parseTimeInterval("2x"), false);
    Test.testThrown!(Exception)(parseTimeInterval("1xm"), false);
}


/******************************************************************************

    Checks if a string can be converted to a time interval

    Params:
        value = a string containing an integer and the first leter of a time
            unit. The supported units are minutes, hours and days.

    Returns:
        true, if the string is a valid interval

******************************************************************************/

public bool isTimeInterval ( cstring value )
{
    if (value == "")
    {
        return false;
    }

    long result;
    long tempValue;

    char unit = value[value.length - 1];

    if ( !toLong(value[0..$-1], tempValue) )
    {
        return false;
    }

    if ( unit != 's' &&  unit != 'm' && unit != 'h' && unit != 'd' )
    {
        return false;
    }

    return true;
}

///
unittest
{
    Test.test!("==")(isTimeInterval(""), false);
    Test.test!("==")(isTimeInterval("1s"), true);
    Test.test!("==")(isTimeInterval("1m"), true);
    Test.test!("==")(isTimeInterval("2m"), true);
    Test.test!("==")(isTimeInterval("1h"), true);
    Test.test!("==")(isTimeInterval("2h"), true);
    Test.test!("==")(isTimeInterval("1d"), true);
    Test.test!("==")(isTimeInterval("2d"), true);

    Test.test!("==")(isTimeInterval("1x"), false);
    Test.test!("==")(isTimeInterval("2xm"), false);
}
