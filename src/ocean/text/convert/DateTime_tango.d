/*******************************************************************************

        Support for formatting date/time values, in a locale-specific
        manner. See DateTimeLocale.format() for a description on how
        formatting is performed (below).

        Reference links:
        ---
        http://www.opengroup.org/onlinepubs/007908799/xsh/strftime.html
        http://msdn.microsoft.com/en-us/library/system.globalization.datetimeformatinfo(VS.71).aspx
        ---

        Copyright:
            Copyright (c) 2005 John Chapman.
            Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version:
            Jan 2005: initial release
            Mar 2009: extracted from locale, and
                      converted to a struct

        Authors: John Chapman, Kris, mwarning

******************************************************************************/

module ocean.text.convert.DateTime_tango;

import ocean.transition;

import ocean.core.ExceptionDefinitions;
import ocean.stdc.posix.langinfo;
import Integer = ocean.text.convert.Integer_tango;
import Utf = ocean.text.convert.Utf;
import ocean.text.convert.Formatter;
import ocean.text.util.StringC;
import ocean.time.chrono.Calendar;
import ocean.time.chrono.Gregorian;
import ocean.transition;
import ocean.core.Verify;

import core.sys.posix.time; // timezone

/******************************************************************************

        The default DateTimeLocale instance

******************************************************************************/

public DateTimeLocale DateTimeDefault;

static this()
{
    DateTimeDefault = DateTimeLocale.create;
}

/******************************************************************************

        How to format locale-specific date/time output

******************************************************************************/

struct DateTimeLocale
{
    static rfc1123Pattern = "ddd, dd MMM yyyy HH':'mm':'ss 'GMT'";
    static sortableDateTimePattern = "yyyy'-'MM'-'dd'T'HH':'mm':'ss";
    static universalSortableDateTimePattern = "yyyy'-'MM'-'dd' 'HH':'mm':'ss'Z'";

    Calendar assignedCalendar;

    cstring shortDatePattern,
            shortTimePattern,
            longDatePattern,
            longTimePattern,
            fullDateTimePattern,
            generalShortTimePattern,
            generalLongTimePattern,
            monthDayPattern,
            yearMonthPattern;

    cstring amDesignator, pmDesignator;

    cstring timeSeparator, dateSeparator;

    cstring[] dayNames, monthNames,
        abbreviatedDayNames, abbreviatedMonthNames;

    /**********************************************************************

      Format the given Time value into the provided output,
      using the specified layout. The layout can be a generic
      variant or a custom one, where generics are indicated
      via a single character:

      <pre>
      "t" = 7:04
      "T" = 7:04:02 PM
      "d" = 3/30/2009
      "D" = Monday, March 30, 2009
      "f" = Monday, March 30, 2009 7:04 PM
      "F" = Monday, March 30, 2009 7:04:02 PM
      "g" = 3/30/2009 7:04 PM
      "G" = 3/30/2009 7:04:02 PM
      "y"
      "Y" = March, 2009
      "r"
      "R" = Mon, 30 Mar 2009 19:04:02 GMT
      "s" = 2009-03-30T19:04:02
      "u" = 2009-03-30 19:04:02Z
      </pre>

      For the US locale, these generic layouts are expanded in the
      following manner:

      <pre>
      "t" = "h:mm"
      "T" = "h:mm:ss tt"
      "d" = "M/d/yyyy"
      "D" = "dddd, MMMM d, yyyy"
      "f" = "dddd, MMMM d, yyyy h:mm tt"
      "F" = "dddd, MMMM d, yyyy h:mm:ss tt"
      "g" = "M/d/yyyy h:mm tt"
      "G" = "M/d/yyyy h:mm:ss tt"
      "y"
      "Y" = "MMMM, yyyy"
      "r"
      "R" = "ddd, dd MMM yyyy HH':'mm':'ss 'GMT'"
      "s" = "yyyy'-'MM'-'dd'T'HH':'mm':'ss"
      "u" = "yyyy'-'MM'-'dd' 'HH':'mm':'ss'Z'"
      </pre>

      Custom layouts are constructed using a combination of the
      character codes indicated on the right, above. For example,
      a layout of "dddd, dd MMM yyyy HH':'mm':'ss zzzz" will emit
      something like this:
      ---
      Monday, 30 Mar 2009 19:04:02 -08:00
      ---

      Using these format indicators with Layout (Stdout etc) is
      straightforward. Formatting integers, for example, is done
      like so:
      ---
      Stdout.formatln ("{:u}", 5);
      Stdout.formatln ("{:b}", 5);
      Stdout.formatln ("{:x}", 5);
      ---

      Formatting date/time values is similar, where the format
      indicators are provided after the colon:
      ---
      Stdout.formatln ("{:t}", Clock.now);
      Stdout.formatln ("{:D}", Clock.now);
      Stdout.formatln ("{:dddd, dd MMMM yyyy HH:mm}", Clock.now);
      ---

     **********************************************************************/

    char[] format (char[] output, Time dateTime, cstring layout)
    {
        // default to general format
        if (layout.length is 0)
            layout = "G";

        // might be one of our shortcuts
        if (layout.length is 1)
            layout = expandKnownFormat (layout);

        auto res=Result(output);
        scope sink = (cstring v) { res ~= v; return v.length; };
        (&this).formatCustom(sink, dateTime, layout);
        return res.get;
    }

    /// Ditto
    public void format (scope size_t delegate(cstring) output, Time dateTime,
                        cstring layout)
    {
        // default to general format
        if (layout.length is 0)
            layout = "G";

        // might be one of our shortcuts
        if (layout.length is 1)
            layout = expandKnownFormat (layout);

        return formatCustom(output, dateTime, layout);
    }


    /**********************************************************************

     **********************************************************************/

    deprecated("Use format instead")
    T[] formatWide(T) (T[] output, Time dateTime, T[] fmt)
    {
        static if (is (T == char))
            return format (output, dateTime, fmt);
        else
        {
            char[128] tmp0 = void;
            char[128] tmp1 = void;
            return Utf.fromString8(format(tmp0, dateTime, Utf.toString(fmt, tmp1)), output);
        }
    }

    /**********************************************************************

      Return a generic English/US instance

     **********************************************************************/

    static DateTimeLocale* generic ()
    {
        return &EngUS;
    }

    /**********************************************************************

      Return the assigned Calendar instance, using Gregorian
      as the default

     **********************************************************************/

    Calendar calendar ()
    {
        if (assignedCalendar is null)
            assignedCalendar = Gregorian.generic;
        return assignedCalendar;
    }

    /**********************************************************************

      Return a short day name

     **********************************************************************/

    cstring abbreviatedDayName (Calendar.DayOfWeek dayOfWeek)
    {
        return abbreviatedDayNames [cast(int) dayOfWeek];
    }

    /**********************************************************************

      Return a long day name

     **********************************************************************/

    cstring dayName (Calendar.DayOfWeek dayOfWeek)
    {
        return dayNames [cast(int) dayOfWeek];
    }

    /**********************************************************************

      Return a short month name

     **********************************************************************/

    cstring abbreviatedMonthName (int month)
    {
        verify(month > 0 && month < 13);
        return abbreviatedMonthNames [month - 1];
    }

    /**********************************************************************

      Return a long month name

     **********************************************************************/

    cstring monthName (int month)
    {
        verify(month > 0 && month < 13);
        return monthNames [month - 1];
    }

    /**************************************************************************

        Create and populate an instance via O/S configuration
        for the current user

    ***************************************************************************/

    static DateTimeLocale create ()
    {
        //extract separator
        static cstring extractSeparator(cstring str, cstring def)
        {
            for (auto i = 0; i < str.length; ++i)
            {
                char c = str[i];
                if ((c == '%') || (c == ' ') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'))
                    continue;
                return str[i..i+1].dup;
            }
            return def;
        }

        static cstring getString(nl_item id, cstring def = null)
        {
            char* p = nl_langinfo(id);
            return p ? StringC.toDString(p).dup : def;
        }

        static cstring getFormatString(nl_item id, cstring def = null)
        {
            auto posix_str = getString(id, def);
            return convert(posix_str);
        }

        DateTimeLocale dt;

        for (auto i = DAY_1; i <= DAY_7; ++i)
            dt.dayNames ~= getString (i);

        for (auto i = ABDAY_1; i <= ABDAY_7; ++i)
            dt.abbreviatedDayNames ~= getString (i);

        for (auto i = MON_1; i <= MON_12; ++i)
            dt.monthNames ~= getString (i);

        for (auto i = ABMON_1; i <= ABMON_12; ++i)
            dt.abbreviatedMonthNames ~= getString (i);

        dt.amDesignator = getString (AM_STR, "AM");
        dt.pmDesignator = getString (PM_STR, "PM");

        dt.longDatePattern = "dddd, MMMM d, yyyy"; //default
        dt.shortDatePattern = getFormatString(D_FMT, "M/d/yyyy");

        dt.longTimePattern = getFormatString(T_FMT, "h:mm:ss tt");
        dt.shortTimePattern = "h:mm"; //default

        dt.yearMonthPattern = "MMMM, yyyy"; //no posix equivalent?
        dt.fullDateTimePattern = getFormatString(D_T_FMT, "dddd, MMMM d, yyyy h:mm:ss tt");

        dt.dateSeparator = extractSeparator(dt.shortDatePattern, "/");
        dt.timeSeparator = extractSeparator(dt.longTimePattern, ":");

        //extract shortTimePattern from longTimePattern
        for (auto i = dt.longTimePattern.length; i--;)
        {
            if (dt.longTimePattern[i] == dt.timeSeparator[$-1])
            {
                dt.shortTimePattern = dt.longTimePattern[0..i];
                break;
            }
        }

        //extract longDatePattern from fullDateTimePattern
        auto pos = dt.fullDateTimePattern.length - dt.longTimePattern.length - 2;
        if (pos < dt.fullDateTimePattern.length)
            dt.longDatePattern = dt.fullDateTimePattern[0..pos];

        dt.fullDateTimePattern = dt.longDatePattern ~ " " ~ dt.longTimePattern;
        dt.generalLongTimePattern = dt.shortDatePattern ~ " " ~  dt.longTimePattern;
        dt.generalShortTimePattern = dt.shortDatePattern ~ " " ~  dt.shortTimePattern;

        return dt;
    }

    /***************************************************************************

        Convert POSIX date time format to .NET format syntax.

    ***************************************************************************/

    private static char[] convert(cstring fmt)
    {
        char[32] ret;
        size_t len;

        void put(cstring str)
        {
            verify((len+str.length) <= ret.length);
            ret[len..len+str.length] = str;
            len += str.length;
        }

        for (auto i = 0; i < fmt.length; ++i)
        {
            char c = fmt[i];

            if (c != '%')
            {
                verify((len+1) <= ret.length);
                ret[len] = c;
                len += 1;
                continue;
            }

            i++;
            if (i >= fmt.length)
                break;

            c = fmt[i];
            switch (c)
            {
            case 'a': //locale's abbreviated weekday name.
                put("ddd"); //The abbreviated name of the day of the week,
                break;

            case 'A': //locale's full weekday name.
                put("dddd");
                break;

            case 'b': //locale's abbreviated month name
                put("MMM");
                break;

            case 'B': //locale's full month name
                put("MMMM");
                break;

            case 'd': //day of the month as a decimal number [01,31]
                put("dd"); // The day of the month. Single-digit
                //days will have a leading zero.
                break;

            case 'D': //same as %m/%d/%y.
                put("MM/dd/yy");
                break;

            case 'e': //day of the month as a decimal number [1,31];
                //a single digit is preceded by a space
                put("d"); //The day of the month. Single-digit days
                //will not have a leading zero.
                break;

            case 'h': //same as %b.
                put("MMM");
                break;

            case 'H':
                //hour (24-hour clock) as a decimal number [00,23]
                put("HH"); //The hour in a 24-hour clock. Single-digit
                //hours will have a leading zero.
                break;

            case 'I': //the hour (12-hour clock) as a decimal number [01,12]
                put("hh"); //The hour in a 12-hour clock.
                //Single-digit hours will have a leading zero.
                break;

            case 'm': //month as a decimal number [01,12]
                put("MM"); //The numeric month. Single-digit
                //months will have a leading zero.
                break;

            case 'M': //minute as a decimal number [00,59]
                put("mm"); //The minute. Single-digit minutes
                //will have a leading zero.
                break;

            case 'n': //newline character
                put("\n");
                break;

            case 'p': //locale's equivalent of either a.m. or p.m
                put("tt");
                break;

            case 'r': //time in a.m. and p.m. notation;
                //equivalent to %I:%M:%S %p.
                put("hh:mm:ss tt");
                break;

            case 'R': //time in 24 hour notation (%H:%M)
                put("HH:mm");
                break;

            case 'S': //second as a decimal number [00,61]
                put("ss"); //The second. Single-digit seconds
                //will have a leading zero.
                break;

            case 't': //tab character.
                put("\t");
                break;

            case 'T': //equivalent to (%H:%M:%S)
                put("HH:mm:ss");
                break;

            case 'u': //weekday as a decimal number [1,7],
                //with 1 representing Monday
            case 'U': //week number of the year
                //(Sunday as the first day of the week) as a decimal number [00,53]
            case 'V': //week number of the year
                //(Monday as the first day of the week) as a decimal number [01,53].
                //If the week containing 1 January has four or more days
                //in the new year, then it is considered week 1.
                //Otherwise, it is the last week of the previous year, and the next week is week 1.
            case 'w': //weekday as a decimal number [0,6], with 0 representing Sunday
            case 'W': //week number of the year (Monday as the first day of the week)
                //as a decimal number [00,53].
                //All days in a new year preceding the first Monday
                //are considered to be in week 0.
            case 'x': //locale's appropriate date representation
            case 'X': //locale's appropriate time representation
            case 'c': //locale's appropriate date and time representation
            case 'C': //century number (the year divided by 100 and
                //truncated to an integer) as a decimal number [00-99]
            case 'j': //day of the year as a decimal number [001,366]
                assert(0);

            case 'y': //year without century as a decimal number [00,99]
                put("yy"); // The year without the century. If the year without
                //the century is less than 10, the year is displayed with a leading zero.
                break;

            case 'Y': //year with century as a decimal number
                put("yyyy"); //The year in four digits, including the century.
                break;

            case 'Z': //timezone name or abbreviation,
                //or by no bytes if no timezone information exists
                //assert(0);
                break;

            case '%':
                put("%");
                break;

            default:
                assert(0);
            }
        }
        return ret[0..len].dup;
    }

    /**********************************************************************

     **********************************************************************/

    private cstring expandKnownFormat (cstring format)
    {
        cstring f;

        switch (format[0])
        {
            case 'd':
                f = shortDatePattern;
                break;
            case 'D':
                f = longDatePattern;
                break;
            case 'f':
                f = longDatePattern ~ " " ~ shortTimePattern;
                break;
            case 'F':
                f = fullDateTimePattern;
                break;
            case 'g':
                f = generalShortTimePattern;
                break;
            case 'G':
                f = generalLongTimePattern;
                break;
            case 'r':
            case 'R':
                f = rfc1123Pattern;
                break;
            case 's':
                f = sortableDateTimePattern;
                break;
            case 'u':
                f = universalSortableDateTimePattern;
                break;
            case 't':
                f = shortTimePattern;
                break;
            case 'T':
                f = longTimePattern;
                break;
            case 'y':
            case 'Y':
                f = yearMonthPattern;
                break;
            default:
                return ("'{invalid time format}'");
        }
        return f;
    }

    /**********************************************************************

     **********************************************************************/

    private void formatCustom (scope size_t delegate(cstring) sink, Time dateTime,
                               cstring format)
    {
        uint            len,
                        doy,
                        dow,
                        era;
        uint            day,
                        year,
                        month;
        int             index;
        char[10]        tmp = void;
        auto            time = dateTime.time;

        // extract date components
        calendar.split (dateTime, year, month, day, doy, dow, era);

        // sweep format specifiers ...
        while (index < format.length)
        {
            char c = format[index];

            switch (c)
            {
                // day
                case 'd':
                    len = parseRepeat (format, index, c);
                    if (len <= 2)
                        sink(formatInt(tmp, day, len));
                    else
                        sink(formatDayOfWeek (cast(Calendar.DayOfWeek) dow, len));
                    break;

                    // millis
                case 'f':
                    len = parseRepeat (format, index, c);
                    auto num = Integer.itoa (tmp, time.millis);
                    if(len > num.length)
                    {
                        sink(num);

                        // append '0's
                        static char[8] zeros = '0';
                        auto zc = len - num.length;
                        zc = (zc > zeros.length) ? zeros.length : zc;
                        sink(zeros[0..zc]);
                    }
                    else
                        sink(num[0..len]);
                    break;

                    // millis, no trailing zeros
                case 'F':
                    len = parseRepeat (format, index, c);
                    auto num = Integer.itoa (tmp, time.millis);
                    auto idx = (len < num.length) ? len : num.length;

                    // strip '0's
                    while(idx && num[idx-1] is '0')
                        --idx;

                    sink(num[0..idx]);
                    break;

                    // month
                case 'M':
                    len = parseRepeat (format, index, c);
                    if (len <= 2)
                        sink(formatInt(tmp, month, len));
                    else
                        sink(formatMonth(month, len));
                    break;

                    // year
                case 'y':
                    len = parseRepeat (format, index, c);

                    // Two-digit years for Japanese
                    if (calendar.id is Calendar.JAPAN)
                        sink(formatInt(tmp, year, 2));
                    else
                    {
                        if (len <= 2)
                            sink(formatInt(tmp, year % 100, len));
                        else
                            sink(formatInt(tmp, year, len));
                    }
                    break;

                    // hour (12-hour clock)
                case 'h':
                    len = parseRepeat (format, index, c);
                    int hour = time.hours % 12;
                    if (hour is 0)
                        hour = 12;
                    sink(formatInt(tmp, hour, len));
                    break;

                    // hour (24-hour clock)
                case 'H':
                    len = parseRepeat (format, index, c);
                    sink(formatInt(tmp, time.hours, len));
                    break;

                    // minute
                case 'm':
                    len = parseRepeat (format, index, c);
                    sink(formatInt(tmp, time.minutes, len));
                    break;

                    // second
                case 's':
                    len = parseRepeat (format, index, c);
                    sink(formatInt (tmp, time.seconds, len));
                    break;

                    // AM/PM
                case 't':
                    len = parseRepeat (format, index, c);
                    if (len is 1)
                    {
                        if (time.hours < 12)
                        {
                            if (amDesignator.length != 0)
                                sink((&amDesignator[0])[0 .. 1]);
                        }
                        else
                        {
                            if (pmDesignator.length != 0)
                                sink((&pmDesignator[0])[0 .. 1]);
                        }
                    }
                    else
                        sink((time.hours < 12) ? amDesignator : pmDesignator);
                    break;

                    // timezone offset
                case 'z':
                    len = parseRepeat (format, index, c);
                    auto minutes = cast(int) (TimeSpan.fromSeconds(-timezone).minutes);
                    if (minutes < 0)
                    {
                        minutes = -minutes;
                        sink("-");
                    }
                    else
                        sink("+");
                    int hours = minutes / 60;
                    minutes %= 60;

                    if (len is 1)
                        sink(formatInt(tmp, hours, 1));
                    else
                        if (len is 2)
                            sink(formatInt (tmp, hours, 2));
                        else
                        {
                            sink(formatInt(tmp, hours, 2));
                            sink(formatInt(tmp, minutes, 2));
                        }
                    break;

                    // time separator
                case ':':
                    len = 1;
                    sink(timeSeparator);
                    break;

                    // date separator
                case '/':
                    len = 1;
                    sink(dateSeparator);
                    break;

                    // string literal
                case '\"':
                case '\'':
                    len = parseQuote(sink, format, index);
                    break;

                    // other
                default:
                    len = 1;
                    sink((&c)[0 .. 1]);
                    break;
            }
            index += len;
        }
    }

    /**********************************************************************

     **********************************************************************/

    private cstring formatMonth (int month, int rpt)
    {
        if (rpt is 3)
            return abbreviatedMonthName (month);
        return monthName (month);
    }

    /**********************************************************************

     **********************************************************************/

    private cstring formatDayOfWeek (Calendar.DayOfWeek dayOfWeek, int rpt)
    {
        if (rpt is 3)
            return abbreviatedDayName (dayOfWeek);
        return dayName (dayOfWeek);
    }

    /**********************************************************************

     **********************************************************************/

    private static int parseRepeat(cstring format, int pos, char c)
    {
        int n = pos + 1;
        while (n < format.length && format[n] is c)
            n++;
        return n - pos;
    }

    /**********************************************************************

     **********************************************************************/

    private static char[] formatInt (char[] tmp, int v, int minimum)
    {
        auto num = Integer.itoa (tmp, v);
        if ((minimum -= num.length) > 0)
        {
            auto p = tmp.ptr + tmp.length - num.length;
            while (minimum--)
                *--p = '0';
            num = tmp [p-tmp.ptr .. $];
        }
        return num;
    }

    /**********************************************************************

     **********************************************************************/

    private static int parseQuote (scope size_t delegate(cstring) sink,
                                   cstring format, int pos)
    {
        int start = pos;
        char chQuote = format[pos++];
        bool found;
        while (pos < format.length)
        {
            char c = format[pos++];
            if (c is chQuote)
            {
                found = true;
                break;
            }
            else
                if (c is '\\')
                { // escaped
                    if (pos < format.length)
                    {
                        sink(format[pos .. pos + 1]);
                        ++pos;
                    }
                }
                else
                    sink((&c)[0 .. 1]);
        }
        return pos - start;
    }
}

/******************************************************************************

  An english/usa locale
  Used as generic DateTimeLocale.

 ******************************************************************************/

private DateTimeLocale EngUS = {
    shortDatePattern        : "M/d/yyyy",
    shortTimePattern        : "h:mm",
    longDatePattern         : "dddd, MMMM d, yyyy",
    longTimePattern         : "h:mm:ss tt",
    fullDateTimePattern     : "dddd, MMMM d, yyyy h:mm:ss tt",
    generalShortTimePattern : "M/d/yyyy h:mm",
    generalLongTimePattern  : "M/d/yyyy h:mm:ss tt",
    monthDayPattern         : "MMMM d",
    yearMonthPattern        : "MMMM, yyyy",
    amDesignator            : "AM",
    pmDesignator            : "PM",
    timeSeparator           : ":",
    dateSeparator           : "/",
    dayNames                : [ "Sunday", "Monday", "Tuesday", "Wednesday",
        "Thursday", "Friday", "Saturday" ],
    monthNames              : [ "January", "February", "March", "April",
        "May", "June", "July", "August", "September",
        "October", "November", "December" ],
    abbreviatedDayNames     : [ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" ],
    abbreviatedMonthNames   : [ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" ],
};


/******************************************************************************

 ******************************************************************************/

private struct Result
{
    private size_t  index;
    private char[]  target_;

    /**********************************************************************

     **********************************************************************/

    private static Result opCall (char[] target)
    {
        Result result;

        result.target_ = target;
        return result;
    }

    /**********************************************************************

     **********************************************************************/

    private void opCatAssign (cstring rhs)
    {
        auto end = index + rhs.length;
        verify(end < target_.length);

        target_[index .. end] = rhs;
        index = end;
    }

    /**********************************************************************

     **********************************************************************/

    private void opCatAssign (char rhs)
    {
        verify(index < target_.length);
        target_[index++] = rhs;
    }

    /**********************************************************************

     **********************************************************************/

    private char[] get ()
    {
        return target_[0 .. index];
    }
}

/*******************************************************************************

    Params:
        value = time value to wrap in pretty-printing struct

    Returns:
        wrapper struct which, when supplied to `Formatter`, prints `value`
        using current default locale settings.

*******************************************************************************/

public AsPrettyStr asPrettyStr ( Time value )
{
    return AsPrettyStr(value);
}

/*******************************************************************************

    Wrapper struct which, when supplied to `Formatter`, prints `value`
    using current default locale settings.

*******************************************************************************/

public struct AsPrettyStr
{
    private Time value;

    public void toString (scope FormatterSink sink)
    {
        // Layout defaults to 'G'
        scope dg = (cstring s) { sink(s); return s.length; };
        DateTimeDefault.format(dg, (&this).value, "");
    }
}

/******************************************************************************

 ******************************************************************************/

debug (DateTime)
{
    import ocean.io.Stdout;

    void main()
    {
        char[100] tmp;
        auto time = WallClock.now;
        auto locale = DateTimeLocale.create;

        Stdout.formatln ("d: {}", locale.format (tmp, time, "d"));
        Stdout.formatln ("D: {}", locale.format (tmp, time, "D"));
        Stdout.formatln ("f: {}", locale.format (tmp, time, "f"));
        Stdout.formatln ("F: {}", locale.format (tmp, time, "F"));
        Stdout.formatln ("g: {}", locale.format (tmp, time, "g"));
        Stdout.formatln ("G: {}", locale.format (tmp, time, "G"));
        Stdout.formatln ("r: {}", locale.format (tmp, time, "r"));
        Stdout.formatln ("s: {}", locale.format (tmp, time, "s"));
        Stdout.formatln ("t: {}", locale.format (tmp, time, "t"));
        Stdout.formatln ("T: {}", locale.format (tmp, time, "T"));
        Stdout.formatln ("y: {}", locale.format (tmp, time, "y"));
        Stdout.formatln ("u: {}", locale.format (tmp, time, "u"));
        Stdout.formatln ("@: {}", locale.format (tmp, time, "@"));
        Stdout.formatln ("{}", locale.generic.format (tmp, time, "ddd, dd MMM yyyy HH':'mm':'ss zzzz"));
    }
}
