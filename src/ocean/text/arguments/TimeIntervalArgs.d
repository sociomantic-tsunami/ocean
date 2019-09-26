/*******************************************************************************

    Handler for time interval CLI arguments

    One Argument
    ------------

    Date:
        Gives the range for that day.
        "-t 2019-04-01" (start: 2019-04-01 00:00:00, end: 2019-04-01 23:59:59 )

    TimeStamp
        Gives a range from the provided timestamp plus one day.
        "-t 1554132392" (start: 1554132392, end: 1554218791)

    Timerange
        Gives X amount in the past NOT including the current second.
        "-t 1m" with now:1000 (start:940, end:999)

    Two Arguments
    -------------

    Dates:
        Start is parsed inclusively, end is parsed exclusively
        eg. -t "2019-04-01 2019-04-02"
            (start: 2019-04-01 00:00:00)
            (  end: 2019-04-02 23:59:59)

    TimeStamp
        Start is treated as is, end is NOT included in final range.
        eg. -t 100 200 = (begin: 100, end: 199)

    Timerange
        End range includes the starting second.
        eg. -t 100 1m = (begin: 100, end: 159)
        eg. -t 1m 100 = (begin: 60, end: 99)

    Intended Range Usage
        for ( long i = range.begin; i <= range.end; ++i )

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

/// Number of seconds in the day for creating day ranges.
static immutable SECONDS_IN_DAY = 86_400;

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
        .params(1, 2)
        .help("Specify a time interval. It 1 or 2 values, where they can be:\n\t" ~
            "'now' an alias for the current timestamp\n\t" ~
            "'yesterday' an alias for yesterdays date\n\t" ~
            "an integer for unix timestamps\n\t" ~
            "a time duration `{int}m`. Supported units are [m]inutes, [h]ours and [d]ays\n\t" ~
            "an iso1806 date (YYYY-MM-DD)");
    args("time-interval-exclude")
        .help("If not set, then a range of '-t 2019-04-01 2019-04-02' will \n" ~
              "include the end date's data. eg. (end: 2019-04-02 23:59:59) \n" ~
              "If set, end date data will not be included, eg.(end: 2019-04-01 23:59:59)");

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
    auto num_args = args["time-interval"].assigned.length;
    if ( num_args < 1 || num_args > 2 )
    {
        return "The 'time-interval' argument must have 1 or 2 values";
    }

    return null;
}

/***************************************************************************

    Process the time-interval argument

    Params:
        args = The arguments to process

***************************************************************************/

public TimestampInterval processTimeIntervalArgs ( Arguments args )
{
    auto num_args = args["time-interval"].assigned.length;
    enforce(num_args >= 1 && num_args <= 2, "Not enough arguments provided");
    bool include_end_date = !args["time-interval-exclude"].set;

    long begin, end;

    if ( num_args == 1 )
    {
        auto arg = args["time-interval"].assigned[0];
        if ( isTimeInterval(arg) )
        {
            end = time(null);
            begin = end - parseTimeInterval(arg);
        }
        else
        {
            begin = parseDateString(arg);
            end = begin + SECONDS_IN_DAY;
        }
    }
    else if ( num_args == 2 )
    {
        cstring begin_arg = args["time-interval"].assigned[0];
        cstring end_arg = args["time-interval"].assigned[1];

        if ( isTimeInterval(begin_arg) && isTimeInterval(end_arg) )
        {
            begin = time(null) - parseTimeInterval(begin_arg);
            end = time(null) + parseTimeInterval(end_arg);
        }
        else if ( isTimeInterval(begin_arg) )
        {
            end = parseDateString(end_arg, include_end_date);
            begin = end - parseTimeInterval(begin_arg);
        }
        else if ( isTimeInterval(end_arg) )
        {
            begin = parseDateString(begin_arg);
            end = begin + parseTimeInterval(end_arg);
        }
        else
        {
            begin = parseDateString(begin_arg);
            end = parseDateString(end_arg, include_end_date);
        }
    }
    //Don't include the last second in the range.
    return TimestampInterval(begin, end-1);
}

/**************************************************************************

    Converts a string interval to a unix timestamp. If the value is an
    ISO 8601 date. If the value is a stirng date and from the end of the range
    then we say the value is actually the next day

    Params:
        value = `now`, "yesterday", a string timestamp or iso8601 date
        include_end_date = For string dates, actually parse the next day to
                           include the dates data.

    Returns:
        an unix timestamp

**************************************************************************/

private long parseDateString ( cstring value, bool include_end_date = false )
{
    if ( value == "now" )
    {
        return time(null);
    }

    if ( value == "yesterday" )
    {
        auto cur_time = time(null) - SECONDS_IN_DAY;
        return cur_time - (cur_time % SECONDS_IN_DAY);
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
        return result + (include_end_date ? SECONDS_IN_DAY : 0);
    }

    enforce(isTimeInterval(value), cast(istring) ("`" ~ value ~ "` is an invalid time interval argument. " ~
        "Only `now`, unix timestamp, iso8601 date and durations are permited."));

    return 0;
}

/// Timestamp to use in unit tests;
version ( UnitTest )
{
    // 2019-04-01 15:26:32
    static immutable TEST_TIME_NOW = 1554132392;

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
    TimestampInterval interval;

    auto args = new Arguments;

    /// When there is no begin and end date set
    setupTimeIntervalArgs(args, false);
    args.parse("");
    Test.testThrown!(Exception)(processTimeIntervalArgs(args));

    /// When the begin date is provided
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval 2014-03-09 now");
    interval = processTimeIntervalArgs(args);
    timeToUnixTime("2014-03-09 00:00:00", dummy_time, dummy_conv);

    Test.test!("==")(interval.begin, dummy_time);
    Test.test!("==")(interval.end, TEST_TIME_NOW - 1);

    /// When the end date is provided
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval now 2014-04-09");
    interval = processTimeIntervalArgs(args);
    timeToUnixTime("2014-04-09 23:59:59", dummy_time, dummy_conv);

    Test.test!("==")(interval.begin, time(null));
    Test.test!("==")(interval.end, dummy_time);

    /// When the end date is provided with exclusion arg
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval now 2014-04-09 --time-interval-exclude");
    interval = processTimeIntervalArgs(args);
    timeToUnixTime("2014-04-08 23:59:59", dummy_time, dummy_conv);

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
    Test.test!("==")(interval.end, 1199);

    /// Using interval starting with time duration
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval 1m 1000");
    interval = processTimeIntervalArgs(args);

    Test.test!("==")(interval.begin, 940);
    Test.test!("==")(interval.end, 999);

    /// Using interval ending with time duration
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval 1000 1m");
    interval = processTimeIntervalArgs(args);

    Test.test!("==")(interval.begin, 1000);
    Test.test!("==")(interval.end, 1059);

    /// Using two time durations
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval 1m 1m");
    interval = processTimeIntervalArgs(args);

    Test.test!("==")(interval.begin, TEST_TIME_NOW - 60);
    Test.test!("==")(interval.end, TEST_TIME_NOW + 59);

    /// Using an invalid argument
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval invalid 1m");
    Test.testThrown!(Exception)(processTimeIntervalArgs(args));

    /// Test range for all of "yesterday"
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval yesterday");
    interval = processTimeIntervalArgs(args);

    /// 03/31/2019 @ 12:00am(UTC)
    Test.test!("==")(interval.begin, 1553990400);
    /// 03/31/2019 @ 11:59pm (UTC)
    Test.test!("==")(interval.end, 1554076799);

    /// Test last 2 hours of data receiving the last 2 hours of data.
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval 2h");
    interval = processTimeIntervalArgs(args);

    /// 2019-04-01 13:26:32
    Test.test!("==")(interval.begin, 1554125192);
    /// 2019-04-01 15:26:31
    Test.test!("==")(interval.end, 1554132391);
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
    long result;

    if ( value.length < 2 || !toLong(value[0..$-1], result) || result == 0 )
    {
        throw new Exception("The provided time interval has an invalid value.");
    }

    char unit = value[value.length - 1];
    switch ( unit )
    {
        case 's':
            break;

        case 'm':
            result *= 60;
            break;

        case 'h':
            result *= 3600;
            break;

        case 'd':
            result *= 3600 * 24;
            break;

        default:
            throw new Exception("The provided time interval has an invalid unit.");
    }

    return result;
}

///
unittest
{
    Test.test!("==")(parseTimeInterval("1s"), 1);
    Test.test!("==")(parseTimeInterval("1m"), 60);
    Test.test!("==")(parseTimeInterval("2m"), 120);
    Test.test!("==")(parseTimeInterval("1h"), 3_600);
    Test.test!("==")(parseTimeInterval("2h"), 7_200);
    Test.test!("==")(parseTimeInterval("1d"), 3600 * 24);
    Test.test!("==")(parseTimeInterval("2d"), 3600 * 48);

    Test.testThrown!(Exception)(parseTimeInterval(""), false);
    Test.testThrown!(Exception)(parseTimeInterval("0s"), false);
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
