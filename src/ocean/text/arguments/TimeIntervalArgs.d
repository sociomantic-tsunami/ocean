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

    Division
    -------------
        All relative values and `now` can be rounded.
        eg. -t 1h/h 1h = if the command is executed at 15:23:23 then
                         begin = 14:00:00, end = 14:59:59
        eg. -t now/d = will select the range between 00:00:00 and `now`

    Intended Range Usage
    -------------
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

/// Number of seconds in a minute
const SECONDS_IN_MINUTE = 60;

/// Number of seconds in an hour
const SECONDS_IN_HOUR = SECONDS_IN_MINUTE * 60;

/// Number of seconds in the day
const SECONDS_IN_DAY = SECONDS_IN_HOUR * 24;

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
        .help("Specify a time interval. It takes 1 or 2 values, where they can be:\n\t" ~
            "'now' an alias for the current timestamp\n\t" ~
            "'yesterday' an alias for yesterdays date\n\t" ~
            "an integer for unix timestamps\n\t" ~
            "a time duration `{int}m`. Supported units are [m]inutes, [h]ours and [d]ays\n\t" ~
            "an iso1806 date (YYYY-MM-DD)\n\t\n\t"~
            "the relative values and 'now' can be rounded by [m]inutes, [h]ours and [d]ays.\n\t" ~
            "eg. 1h/h will set the minutes and seconds to `0`");
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


/******************************************************************************

    Parse one time interval argument

    Params:
        op = the math operation performed to the reference time.
             Only "+", "-" is permitted.
        value = the string that will be parsed
        reference_time = reference timestamp for the relative intervals
        include_end_date = For string dates, actually parse the next day to
                           include the dates data.

******************************************************************************/

public long parseTimeArgument ( cstring op ) ( cstring value, long reference_time,
    bool include_end_date )
{
    long result;

    if ( isRelativeTime(value) )
    {
        static if ( op == "+" )
        {
            result = reference_time + parseTimeInterval(removeTimeDivision(value));
        }
        else static if ( op == "-" )
        {
            result = reference_time - parseTimeInterval(removeTimeDivision(value));
        }
        else
        {
            static assert(false, "Only `+` and `-` operations are supported.");
        }
    }
    else
    {
        result = parseDateString(removeTimeDivision(value), include_end_date);
    }

    if ( isDividedTime(value) )
    {
        result = roundTime(result, getTimeUnit(value));
    }

    return result;
}

/***************************************************************************

    Process the time-interval arguments. It expects one or two
    `time-interval` arguments. They can be a `relative time`,
    an iso8601 date, a timestamp, `now` or `yesterday`.

    If only one argument is provided, the second one will be infered:
        - relative times will use `now` as end
        - `yesterday`, timestamps, dates and `now` will use the same value
           as an end

    If the `time-interval-exclude` argument is not set, then a range of
    '-t 2019-04-01 2019-04-02' will include the end date's data.
    eg. (end: 2019-04-02 23:59:59).

    If the `time-interval-exclude` argument is set, end date data will
    not be included, eg.(end: 2019-04-01 23:59:59)

    Params:
        args = The arguments to process

***************************************************************************/

public TimestampInterval processTimeIntervalArgs ( Arguments args )
{
    auto num_args = args["time-interval"].assigned.length;
    enforce(num_args >= 1 && num_args <= 2, "Not enough arguments provided");
    bool include_end_date = !args["time-interval-exclude"].set;

    if ( num_args == 2 )
    {
        return createTimestampInterval(
            args["time-interval"].assigned[0],
            args["time-interval"].assigned[1],
            include_end_date);
    }

    if ( isRelativeTime(args["time-interval"].assigned[0]) )
    {
        return createTimestampInterval(
            args["time-interval"].assigned[0],
            "now",
            include_end_date);
    }

    return createTimestampInterval(
        args["time-interval"].assigned[0],
        removeTimeDivision(args["time-interval"].assigned[0]),
        include_end_date);
}

/**************************************************************************

    Create a TimestampInterval from two string values.

    Params:
        str_begin = `now`, "yesterday", a string timestamp or iso8601 date
        str_end = `now`, "yesterday", a string timestamp or iso8601 date
        include_end_date = For string dates, actually parse the next day to
                           include the dates data.

    Returns:
        the parsed TimestampInterval

**************************************************************************/

private TimestampInterval createTimestampInterval ( cstring str_begin,
    cstring str_end, bool include_end_date )
{
    auto reference_time = time(null);

    if ( !isRelativeTime(str_end) )
    {
        reference_time = parseDateString(removeTimeDivision(str_end), include_end_date);
    }

    auto begin = parseTimeArgument!("-")(str_begin, reference_time, false);
    auto end = parseTimeArgument!("+")(str_end, begin, include_end_date);

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

        return cur_time - (cur_time % SECONDS_IN_DAY) +
            (include_end_date ? SECONDS_IN_DAY : 0);
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

    enforce(isRelativeTime(value), cast(istring) ("`" ~ value ~ "` is an invalid time interval argument. " ~
        "Only `now`, unix timestamp, iso8601 date and durations are permited."));

    return 0;
}

/// Timestamp to use in unit tests;
version ( UnitTest )
{
    // 2019-04-01 15:26:32
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
    Test.test!("==")(interval.end, TEST_TIME_NOW - 1);

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

    /// Using time intervals with rounded hours
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval 1h/h 1h");
    interval = processTimeIntervalArgs(args);

    timeToUnixTime("2019-04-01 14:00:00", dummy_time, dummy_conv);
    Test.test!("==")(interval.begin, dummy_time);

    timeToUnixTime("2019-04-01 14:59:59", dummy_time, dummy_conv);
    Test.test!("==")(interval.end, dummy_time);

    /// Using divided time intervals that start `now`
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval now 1h/h");
    interval = processTimeIntervalArgs(args);

    timeToUnixTime("2019-04-01 15:26:32", dummy_time, dummy_conv);
    Test.test!("==")(interval.begin, dummy_time);

    timeToUnixTime("2019-04-01 15:59:59", dummy_time, dummy_conv);
    Test.test!("==")(interval.end, dummy_time);

    /// Select the yesterday interval with relative time
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval 1d/d 1d");
    interval = processTimeIntervalArgs(args);

    timeToUnixTime("2019-03-31 00:00:00", dummy_time, dummy_conv);
    Test.test!("==")(interval.begin, dummy_time);

    timeToUnixTime("2019-03-31 23:59:59", dummy_time, dummy_conv);
    Test.test!("==")(interval.end, dummy_time);

    /// Using divided time intervals that ends `now`
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval 1h/h now");
    interval = processTimeIntervalArgs(args);

    timeToUnixTime("2019-04-01 14:00:00", dummy_time, dummy_conv);
    Test.test!("==")(interval.begin, dummy_time);

    timeToUnixTime("2019-04-01 15:26:31", dummy_time, dummy_conv);
    Test.test!("==")(interval.end, dummy_time);

    /// Using divided `now`
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval now/h now/m");
    interval = processTimeIntervalArgs(args);

    timeToUnixTime("2019-04-01 15:00:00", dummy_time, dummy_conv);
    Test.test!("==")(interval.begin, dummy_time);

    timeToUnixTime("2019-04-01 15:25:59", dummy_time, dummy_conv);
    Test.test!("==")(interval.end, dummy_time);

    /// Using one divided `now`
    args = new Arguments;

    setupTimeIntervalArgs(args, false);
    args.parse("--time-interval now/h");
    interval = processTimeIntervalArgs(args);

    timeToUnixTime("2019-04-01 15:00:00", dummy_time, dummy_conv);
    Test.test!("==")(interval.begin, dummy_time);

    timeToUnixTime("2019-04-01 15:26:31", dummy_time, dummy_conv);
    Test.test!("==")(interval.end, dummy_time);
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

    Checks if a string is a valid relative time

    Params:
        value = a string containing an integer and the first leter of a time
            unit. The supported units are seconds, minutes, hours and days.

    Returns:
        true, if the string is a valid relative time

******************************************************************************/

private bool isRelativeTime ( cstring value )
{
    if (value == "")
    {
        return false;
    }

    auto relative_value = removeTimeDivision(value);

    long tempValue;

    if ( !toLong(relative_value[0..$-1], tempValue) )
    {
        return false;
    }

    return isValidTimeUnit(value[value.length - 1]);
}

/// ditto
public deprecated alias isRelativeTime isTimeInterval;

/// Validations for relative times
unittest
{
    Test.test!("==")(isRelativeTime(""), false);
    Test.test!("==")(isRelativeTime("1s"), true);
    Test.test!("==")(isRelativeTime("1m"), true);
    Test.test!("==")(isRelativeTime("2m"), true);
    Test.test!("==")(isRelativeTime("1h"), true);
    Test.test!("==")(isRelativeTime("2h"), true);
    Test.test!("==")(isRelativeTime("1d"), true);
    Test.test!("==")(isRelativeTime("2d"), true);
    Test.test!("==")(isRelativeTime("2d/d"), true);

    Test.test!("==")(isRelativeTime("1x"), false);
    Test.test!("==")(isRelativeTime("2xm"), false);
}

/******************************************************************************

    Check if a char value is a valid time unit

    Params:
        unit = the char to be checked

    Returns:
        true if the unit is valid

******************************************************************************/

private bool isValidTimeUnit ( char unit )
{
    return unit == 's' || unit == 'm' || unit == 'h' || unit == 'd';
}

/// Check if the unit is valid
unittest
{
    Test.test!("==")(isValidTimeUnit('s'), true);
    Test.test!("==")(isValidTimeUnit('m'), true);
    Test.test!("==")(isValidTimeUnit('h'), true);
    Test.test!("==")(isValidTimeUnit('d'), true);

    size_t valid_units;
    for ( char ch = 'a'; ch <= 'z'; ch++ )
    {
        if ( isValidTimeUnit(ch) )
        {
            valid_units++;
        }
    }

    Test.test!("==")(valid_units, 4);
}

/******************************************************************************

    Checks if a string contains a valid divided relative time

    Params:
        value = the relative time that will be validated

    Returns:
        true, if the string matches the pattern [some value]/[time unit]

******************************************************************************/

private bool isDividedTime ( cstring value )
{
    if ( value.length <= 2 )
    {
        return false;
    }

    auto last_index = value.length - 1;

    if ( !isValidTimeUnit(value[last_index]) )
    {
        return false;
    }

    if ( value[last_index - 1] != '/' )
    {
        return false;
    }

    return true;
}

/// Validate divided time arguments
unittest
{
    Test.test!("==")(isDividedTime(""), false);
    Test.test!("==")(isDividedTime("d"), false);
    Test.test!("==")(isDividedTime("1d"), false);
    Test.test!("==")(isDividedTime("11d/dd"), false);
    Test.test!("==")(isDividedTime("1d/x"), false);

    Test.test!("==")(isDividedTime("11/d"), true);
    Test.test!("==")(isDividedTime("d/d"), true);
    Test.test!("==")(isDividedTime("11dd/d"), true);
    Test.test!("==")(isDividedTime("1d/d"), true);
}

/******************************************************************************

    Remove the time division from the relative time

    Params:
        value = the relative time

    Returns:
        the relative time without the division

******************************************************************************/

private cstring removeTimeDivision ( cstring value )
{
    if ( value.length < 2 || !isDividedTime(value) )
    {
        return value;
    }

    return value[0..$-2];
}

/// Validate divided time arguments
unittest
{
    Test.test!("==")(removeTimeDivision(""), "");
    Test.test!("==")(removeTimeDivision("d"), "d");
    Test.test!("==")(removeTimeDivision("d/d"), "d");
    Test.test!("==")(removeTimeDivision("1d"), "1d");
    Test.test!("==")(removeTimeDivision("11/d"), "11");
    Test.test!("==")(removeTimeDivision("11d/dd"), "11d/dd");
    Test.test!("==")(removeTimeDivision("1d/x"), "1d/x");

    Test.test!("==")(removeTimeDivision("11dd/d"), "11dd");
    Test.test!("==")(removeTimeDivision("1d/d"), "1d");
}

/******************************************************************************

    Get the division time unit from a string time

    Params:
        value = the string time

    Returns:
        the char representing the time unit or '?' in case of error

******************************************************************************/

private char getTimeUnit ( cstring value )
{
    if ( value == "" )
    {
        return '?';
    }

    auto last_index = value.length - 1;
    auto unit = value[last_index];

    if ( !isValidTimeUnit(unit) )
    {
        return '?';
    }

    return unit;
}

/// Getting the time unit
unittest
{
    Test.test!("==")(getTimeUnit(""), '?');
    Test.test!("==")(getTimeUnit("d"), 'd');
    Test.test!("==")(getTimeUnit("/d"), 'd');
    Test.test!("==")(getTimeUnit("/x"), '?');
}


/******************************************************************************

    Round a timestamp to a particular time unit

    Params:
        value = the timestamp
        unit = the time unit used for rounding

    Returns:
        the rounded timestamp

******************************************************************************/

private long roundTime ( long value, char unit )
{
    switch ( unit )
    {
        case 'm':
            return value - value % SECONDS_IN_MINUTE;
        case 'h':
            return value - value % SECONDS_IN_HOUR;
        case 'd':
            return value - value % SECONDS_IN_DAY;
        default:
    }

    return value;
}

unittest
{
    long actual_time;
    long expected_time;
    DateConversion dummy_conv;

    timeToUnixTime("2019-04-01 14:12:34", actual_time, dummy_conv);
    Test.test!("==")(roundTime(actual_time, 's'), actual_time);

    timeToUnixTime("2019-04-01 14:12:00", expected_time, dummy_conv);
    timeToUnixTime("2019-04-01 14:12:34", actual_time, dummy_conv);
    Test.test!("==")(roundTime(actual_time, 'm'), expected_time);

    timeToUnixTime("2019-04-01 14:00:00", expected_time, dummy_conv);
    timeToUnixTime("2019-04-01 14:12:34", actual_time, dummy_conv);
    Test.test!("==")(roundTime(actual_time, 'h'), expected_time);

    timeToUnixTime("2019-04-01 00:00:00", expected_time, dummy_conv);
    timeToUnixTime("2019-04-01 14:12:34", actual_time, dummy_conv);
    Test.test!("==")(roundTime(actual_time, 'd'), expected_time);
}
