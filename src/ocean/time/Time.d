/******************************************************************************

        Copyright:
            Copyright (c) 2007 Tango contributors.
            Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version:
            mid 2005: Initial release
            Apr 2007: heavily reshaped
            Dec 2007: moved to ocean.time

        Authors: John Chapman, Kris, scheivguy

******************************************************************************/

module ocean.time.Time;

import core.time;
import core.stdc.time: time_t;
import ocean.meta.types.Qualifiers;

version (unittest)
{
    import core.stdc.time;
    import ocean.core.Test;
}

/******************************************************************************

    This struct represents a length of time.  The underlying representation is
    in units of 100ns.  This allows the length of time to span to roughly
    +/- 10000 years.

    Notably missing from this is a representation of weeks, months and years.
    This is because weeks, months, and years vary according to local calendars.
    Use ocean.time.chrono.* to deal with these concepts.

    Note: nobody should change this struct without really good reason as it is
    required to be a part of some interfaces.  It should be treated as a
    builtin type. Also note that there is deliberately no opCall constructor
    here, since it tends to produce too much overhead.   If you wish to build
    a TimeSpan struct from a ticks value, use D's builtin ability to create a
    struct with given member values (See the description of ticks() for an
    example of how to do this).

    Example:
    -------------------
    Time start = Clock.now;
    Thread.sleep(0.150);
    Stdout.formatln("slept for {} ms", (Clock.now-start).millis);
    -------------------

    See_Also: ocean.core.Thread, ocean.time.Clock

******************************************************************************/

struct TimeSpan
{
        // this is the only member of the struct.
        package Duration duration_;

        /// Convenience function (older compilers don't allow public alias to package)
        public Duration duration () const { return this.duration_; }
        /// Allow implicit conversion from `TimeSpan` to `Duration`
        alias duration this;

        // useful constants.  Shouldn't be used in normal code, use the
        // static TimeSpan members below instead.  i.e. instead of
        // TimeSpan.TicksPerSecond, use TimeSpan.second.ticks
        //
        enum : long
        {
                /// basic tick values
                NanosecondsPerTick  = 100,
                TicksPerMicrosecond = 1000 / NanosecondsPerTick,
                TicksPerMillisecond = 1000 * TicksPerMicrosecond,
                TicksPerSecond      = 1000 * TicksPerMillisecond,
                TicksPerMinute      = 60 * TicksPerSecond,
                TicksPerHour        = 60 * TicksPerMinute,
                TicksPerDay         = 24 * TicksPerHour,

                // millisecond counts
                MillisPerSecond     = 1000,
                MillisPerMinute     = MillisPerSecond * 60,
                MillisPerHour       = MillisPerMinute * 60,
                MillisPerDay        = MillisPerHour * 24,

                /// day counts
                DaysPerYear         = 365,
                DaysPer4Years       = DaysPerYear * 4 + 1,
                DaysPer100Years     = DaysPer4Years * 25 - 1,
                DaysPer400Years     = DaysPer100Years * 4 + 1,

                // epoch counts
                Epoch1601           = DaysPer400Years * 4 * TicksPerDay,
                Epoch1970           = Epoch1601 + TicksPerSecond * 11644473600L,
        }

        /**
         * Minimum TimeSpan
         */
        enum TimeSpan min = TimeSpan(Duration.min);

        /**
         * Maximum TimeSpan
         */
        enum TimeSpan max = TimeSpan(Duration.max);

        /**
         * Zero TimeSpan.  Useful for comparisons.
         */
        enum TimeSpan zero = TimeSpan(Duration.zero);

        /// Compatibility constructors
        public this (long ticks)
        {
            this.duration_ = ticks.hnsecs;
        }

        ///
        public this (Duration dur)
        {
            this.duration_ = dur;
        }

        /**
         * Get the number of ticks that this timespan represents.
         *
         * A tick correspond to an hecto-nanosecond, or 100ns.
         * This is the way this struct stores data internally,
         * which is the representation `core.time : Duration` uses.
         *
         * This method can be used to construct another `TimeSpan`:
         * --------
         * long ticks = myTimeSpan.ticks;
         * TimeSpan copyOfMyTimeSpan = TimeSpan(ticks);
         * --------
         *
         * See_Also:
         * https://dlang.org/phobos/core_time.html
         */
        long ticks()
        {
            return this.duration_.total!"hnsecs";
        }

        /**
         * Determines whether two TimeSpan values are equal
         */
        equals_t opEquals(TimeSpan t)
        {
                return this.duration_ == t.duration_;
        }

        /**
         * Compares this object against another TimeSpan value.
         */
        public int opCmp ( const typeof(this) rhs ) const
        {
            return this.duration_.opCmp(rhs.duration_);
        }

        /**
         * Add or subtract the TimeSpan given to this TimeSpan returning a
         * new TimeSpan.
         *
         * Params:  op = operation to perform
         *          t = A TimeSpan value to add or subtract
         * Returns: A TimeSpan value that is the result of this instance, the
         *          operation, and t.
         */
        TimeSpan opBinary (string op) (TimeSpan t) if (op == "+" || op == "-")
        {
            mixin("return TimeSpan(this.duration_ " ~ op ~ " t.duration_);");
        }

        unittest
        {
            TimeSpan time_span;
            time_span.duration_ = 5.hnsecs;

            TimeSpan test_span;
            test_span.duration_ = 10.hnsecs;

            auto res = time_span + test_span;
            test!("==")(res.ticks(), 15);

            test_span.duration_ = 3.hnsecs;

            res = time_span - test_span;
            test!("==")(res.ticks(), 2);
        }

        /**
         * Add or subtract the specified TimeSpan to this TimeSpan, assigning
         * the result to this instance.
         *
         * Params:  op = operation to perform
         *          t = A TimeSpan value to add or subtract
         * Returns: a copy of this instance after adding or subtracting t.
         */

        TimeSpan opOpAssign (string op) (TimeSpan t) if (op == "+" || op == "-")
        {
            mixin("duration_ " ~ op ~ "= t.duration_;");
            return this;
        }

        unittest
        {
            TimeSpan time_span;
            time_span.duration_ = 5.hnsecs;

            TimeSpan test_span;
            test_span.duration_ = 10.hnsecs;

            time_span += test_span;
            test!("==")(time_span.ticks(), 15);

            test_span.duration_ = 3.hnsecs;

            time_span -= test_span;
            test!("==")(time_span.ticks(), 12);
        }

        /**
         * Scale the TimeSpan by the specified amount.  This should not be
         * used to convert to a different unit.  Use the unit accessors
         * instead.  This should only be used as a scaling mechanism.  For
         * example, if you have a timeout and you want to sleep for twice the
         * timeout, you would use timeout * 2. Returns a new TimeSpan.
         *
         * Params: op = operation to perform
         *         v = A multiplier or divisor to use for scaling this time span.
         * Returns: A new TimeSpan that is scaled by v
         */
        TimeSpan opBinary (string op) (long v) if (op == "*" || op == "/")
        {
                mixin("return TimeSpan(duration_ " ~ op ~ " v);");
        }

        unittest
        {
            TimeSpan time_span;
            time_span.duration_ = 5.hnsecs;

            auto res = time_span * 10;
            test!("==")(res.ticks(), 50);

            res = time_span / 5;
            test!("==")(res.ticks(), 1);
        }

        /**
         * Scales this TimeSpan and assigns the result to this instance.
         *
         * Params: op = operation to perform
         *         v = A multipler or divisor to use for scaling
         * Returns: A copy of this instance after scaling
         */
        TimeSpan opOpAssign (string op) (long v) if (op == "*" || op == "/")
        {
                mixin("duration_ " ~ op ~ "= v;");
                return this;
        }

        unittest
        {
            TimeSpan time_span;
            time_span.duration_ = 5.hnsecs;

            time_span *= 10;
            test!("==")(time_span.ticks(), 50);

            time_span /= 5;
            test!("==")(time_span.ticks(), 10);
        }

        /**
         * Perform integer division with the given time span.
         *
         * Params: op = operation to perform
         *         t = A divisor used for dividing
         * Returns: The result of integer division between this instance and
         * t.
         */
        long opBinary (string op) (TimeSpan t) if (op == "/")
        {
            return duration_ / t.duration_;
        }

        unittest
        {
            TimeSpan time_span;
            time_span.duration_ = 10.hnsecs;

            TimeSpan test_span;
            test_span.duration_ = 5.hnsecs;

            test!("==")(time_span / test_span, 2);
        }

        /**
         * Negate a time span. Returns a new TimeSpan.
         *
         * Params:  op = operation to perform
         * Returns: The negative equivalent to this time span
         */
        TimeSpan opUnary (string op) () if (op == "-")
        {
                return TimeSpan(-duration_);
        }

        unittest
        {
            TimeSpan time_span;
            time_span.duration_ = 10.hnsecs;

            auto res = (-time_span);

            test!("==")(res.ticks(), -10);
        }

        /**
         * Convert to nanoseconds
         *
         * Note: this may incur loss of data because nanoseconds cannot
         * represent the range of data a TimeSpan can represent.
         *
         * Returns: The number of nanoseconds that this TimeSpan represents.
         */
        long nanos()
        {
            return duration_.total!"nsecs";
        }

        /**
         * Convert to microseconds
         *
         * Returns: The number of microseconds that this TimeSpan represents.
         */
        long micros()
        {
            return duration_.total!"usecs";
        }

        /**
         * Convert to milliseconds
         *
         * Returns: The number of milliseconds that this TimeSpan represents.
         */
        long millis()
        {
            return duration_.total!"msecs";
        }

        /**
         * Convert to seconds
         *
         * Returns: The number of seconds that this TimeSpan represents.
         */
        long seconds()
        {
            return duration_.total!"seconds";
        }

        /**
         * Convert to minutes
         *
         * Returns: The number of minutes that this TimeSpan represents.
         */
        long minutes()
        {
            return duration_.total!"minutes";
        }

        /**
         * Convert to hours
         *
         * Returns: The number of hours that this TimeSpan represents.
         */
        long hours()
        {
            return duration_.total!"hours";
        }

        /**
         * Convert to days
         *
         * Returns: The number of days that this TimeSpan represents.
         */
        long days()
        {
            return duration_.total!"days";
        }

        /**
         * Convert to a floating point interval representing seconds.
         *
         * Note: This may cause a loss of precision as a double cannot exactly
         * represent some fractional values.
         *
         * Returns: An interval representing the seconds and fractional
         * seconds that this TimeSpan represents.
         */
        double interval()
        {
            return (cast(double) duration_.total!"hnsecs") / TicksPerSecond;
        }

        /**
         * Convert to TimeOfDay
         *
         * Returns: the TimeOfDay this TimeSpan represents.
         */
        TimeOfDay time()
        {
                return TimeOfDay(duration_);
        }

        /**
         * Construct a TimeSpan from the given number of nanoseconds
         *
         * Note: This may cause a loss of data since a TimeSpan's resolution
         * is in 100ns increments.
         *
         * Params: value = The number of nanoseconds.
         * Returns: A TimeSpan representing the given number of nanoseconds.
         */
        static TimeSpan fromNanos(long value)
        {
            return TimeSpan(value.dur!"nsecs");
        }

        /**
         * Construct a TimeSpan from the given number of microseconds
         *
         * Params: value = The number of microseconds.
         * Returns: A TimeSpan representing the given number of microseconds.
         */
        static TimeSpan fromMicros(long value)
        {
            return TimeSpan(value.dur!"usecs");
        }

        /**
         * Construct a TimeSpan from the given number of milliseconds
         *
         * Params: value = The number of milliseconds.
         * Returns: A TimeSpan representing the given number of milliseconds.
         */
        static TimeSpan fromMillis(long value)
        {
                return TimeSpan(value.dur!"msecs");
        }

        /**
         * Construct a TimeSpan from the given number of seconds
         *
         * Params: value = The number of seconds.
         * Returns: A TimeSpan representing the given number of seconds.
         */
        static TimeSpan fromSeconds(long value)
        {
            return TimeSpan(value.dur!"seconds");
        }

        /**
         * Construct a TimeSpan from the given number of minutes
         *
         * Params: value = The number of minutes.
         * Returns: A TimeSpan representing the given number of minutes.
         */
        static TimeSpan fromMinutes(long value)
        {
            return TimeSpan(value.dur!"minutes");
        }

        /**
         * Construct a TimeSpan from the given number of hours
         *
         * Params: value = The number of hours.
         * Returns: A TimeSpan representing the given number of hours.
         */
        static TimeSpan fromHours(long value)
        {
            return TimeSpan(value.dur!"hours");
        }

        /**
         * Construct a TimeSpan from the given number of days
         *
         * Params: value = The number of days.
         * Returns: A TimeSpan representing the given number of days.
         */
        static TimeSpan fromDays(long value)
        {
            return TimeSpan(value.dur!"days");
        }

        /**
         * Construct a TimeSpan from the given interval.  The interval
         * represents seconds as a double.  This allows both whole and
         * fractional seconds to be passed in.
         *
         * Params: sec = The interval to convert in seconds.
         * Returns: A TimeSpan representing the given interval.
         */
        static TimeSpan fromInterval(double sec)
        {
            return TimeSpan((cast(long)(sec * TicksPerSecond + .1)).dur!"hnsecs");
        }
}


/******************************************************************************

        Represents a point in time.

        Remarks: Time represents dates and times between 12:00:00
        midnight on January 1, 10000 BC and 11:59:59 PM on December 31,
        9999 AD.

        Time values are measured in 100-nanosecond intervals, or ticks.
        A date value is the number of ticks that have elapsed since
        12:00:00 midnight on January 1, 0001 AD in the Gregorian
        calendar.

        Negative Time values are offsets from that same reference point,
        but backwards in history.  Time values are not specific to any
        calendar, but for an example, the beginning of December 31, 1 BC
        in the Gregorian calendar is Time.epoch - TimeSpan.days(1).

******************************************************************************/

struct Time
{
        private long ticks_;

        private enum : long
        {
                maximum = (TimeSpan.DaysPer400Years * 25 - 366) * TimeSpan.TicksPerDay - 1,
                minimum = -((TimeSpan.DaysPer400Years * 25 - 366) * TimeSpan.TicksPerDay - 1),
        }

        /// Represents the smallest and largest Time value.
        enum Time min       = {minimum},
                          max       = {maximum};

        /// Represents the epoch (1/1/0001)
        enum Time epoch     = {0};

        /// Represents the epoch of 1/1/1601 (Commonly used in Windows systems)
        enum Time epoch1601 = {TimeSpan.Epoch1601};

        /// Represents the epoch of 1/1/1970 (Commonly used in Unix systems)
        enum Time epoch1970 = {TimeSpan.Epoch1970};

        /**********************************************************************

                $(I Property.) Retrieves the number of ticks for this Time.
                This value can be used to construct another Time struct by
                writing:

                ---------
                long ticks = myTime.ticks;
                Time copyOfMyTime = Time(ticks);
                ---------


                Returns: A long represented by the time of this
                         instance.

        **********************************************************************/

        long ticks ()
        {
                return ticks_;
        }

        /**********************************************************************

                Determines whether two Time values are equal.

                Params:  t = A Time _value.
                Returns: true if both instances are equal; otherwise, false

        **********************************************************************/

        int opEquals (Time t)
        {
                return ticks_ is t.ticks_;
        }

        /**********************************************************************

                Compares two Time values.

        **********************************************************************/

        int opCmp (Time t)
        {
                if (ticks_ < t.ticks_)
                    return -1;

                if (ticks_ > t.ticks_)
                    return 1;

                return 0;
        }

        /**********************************************************************

                Adds or subtracts the specified time span to the time,
                returning a new time.

                Params:  op = operation to perform
                         t = A TimeSpan value.
                Returns: A Time that is the sum or difference of this instance
                         and t.

        **********************************************************************/

        Time opBinary (string op) (TimeSpan t) if (op == "+" || op == "-")
        {
            mixin("return Time(ticks_ " ~ op ~ " t.duration_.total!`hnsecs`);");
        }

        unittest
        {
            Time time_span;
            time_span.ticks_ = 5;

            TimeSpan test_span;
            test_span.duration_ = 10.dur!"hnsecs";

            auto res = time_span + test_span;
            test!("==")(res.ticks(), 15);

            test_span.duration_ = 3.dur!"hnsecs";

            res = time_span - test_span;
            test!("==")(res.ticks(), 2);
        }

        /**********************************************************************

                Adds or subtracts the specified time span to the time, assigning
                the result to this instance.

                Params:  op = operation to perform
                         t = A TimeSpan value.
                Returns: The current Time instance, with t added or subtracted
                         to the time.

        **********************************************************************/

        Time opOpAssign (string op) (TimeSpan t) if (op == "+" || op == "-")
        {
                mixin("ticks_ " ~ op ~ "= t.duration_.total!`hnsecs`;");
                return this;
        }

        unittest
        {
            Time time_span;
            time_span.ticks_ = 5;

            TimeSpan test_span;
            test_span.duration_ = 10.dur!"hnsecs";

            time_span += test_span;
            test!("==")(time_span.ticks(), 15);

            test_span.duration_ = 3.dur!"hnsecs";

            time_span -= test_span;
            test!("==")(time_span.ticks(), 12);
        }

        /**********************************************************************

                Returns a time span which represents the difference in time
                between this and the given Time.

                Params:  op = operation to perform
                         t = A Time value.
                Returns: A TimeSpan which represents the difference between
                         this and t.

        **********************************************************************/

        TimeSpan opBinary (string op) (Time t) if (op == "-")
        {
            return TimeSpan((ticks - t.ticks_).dur!"hnsecs");
        }

        unittest
        {
            Time time_span;
            time_span.ticks_ = 5;

            TimeSpan test_span;
            test_span.duration_ = 3.dur!"hnsecs";

            auto res = time_span - test_span;
            test!("==")(res.ticks(), 2);
        }

        /**********************************************************************

                $(I Property.) Retrieves the date component.

                Returns: A new Time instance with the same date as
                         this instance, but with the time truncated.

        **********************************************************************/

        Time date ()
        {
                return this - TimeOfDay.modulo24(ticks_);
        }

        /**********************************************************************

                $(I Property.) Retrieves the time of day.

                Returns: A TimeOfDay representing the fraction of the day
                         elapsed since midnight.

        **********************************************************************/

        TimeOfDay time ()
        {
                return TimeOfDay (ticks_);
        }

        /**********************************************************************

                $(I Property.) Retrieves the equivalent TimeSpan.

                Returns: A TimeSpan representing this Time.

        **********************************************************************/

        TimeSpan span ()
        {
                return TimeSpan (ticks_);
        }

        /**********************************************************************

                $(I Property.) Retrieves a TimeSpan that corresponds to Unix
                time (time since 1/1/1970).  Use the TimeSpan accessors to get
                the time in seconds, milliseconds, etc.

                Returns: A TimeSpan representing this Time as Unix time.

                -------------------------------------
                auto unixTime = Clock.now.unix.seconds;
                auto javaTime = Clock.now.unix.millis;
                -------------------------------------

        **********************************************************************/

        TimeSpan unix()
        {
                return TimeSpan(ticks_ - epoch1970.ticks_);
        }

        /**********************************************************************

            Constructs a Time instance from the Unix time (time since 1/1/1970).

            Params:
                unix_time = number of seconds since 1/1/1970

            Returns:
                Time instance corresponding the given unix time.

        ***********************************************************************/

        static Time fromUnixTime (time_t unix_time)
        {
            return Time(epoch1970.ticks_ + unix_time * TimeSpan.TicksPerSecond);
        }
}


/******************************************************************************

        Represents a time of day. This is different from TimeSpan in that
        each component is represented within the limits of everyday time,
        rather than from the start of the Epoch. Effectively, the TimeOfDay
        epoch is the first second of each day.

        This is handy for dealing strictly with a 24-hour clock instead of
        potentially thousands of years. For example:
        ---
        auto time = Clock.now.time;
        assert (time.millis < 1000);
        assert (time.seconds < 60);
        assert (time.minutes < 60);
        assert (time.hours < 24);
        ---

        You can create a TimeOfDay from an existing Time or TimeSpan instance
        via the respective time() method. To convert back to a TimeSpan, use
        the span() method

******************************************************************************/

struct TimeOfDay
{
        /**
         * hours component of the time of day.  This should be between 0 and
         * 23, inclusive.
         */
        public uint     hours;

        /**
         * minutes component of the time of day.  This should be between 0 and
         * 59, inclusive.
         */
        public uint     minutes;

        /**
         * seconds component of the time of day.  This should be between 0 and
         * 59, inclusive.
         */
        public uint     seconds;

        /**
         * milliseconds component of the time of day.  This should be between
         * 0 and 999, inclusive.
         */
        public uint     millis;

        /**
         * constructor.
         * Params: hours = number of hours since midnight
         *         minutes = number of minutes into the hour
         *         seconds = number of seconds into the minute
         *         millis = number of milliseconds into the second
         *
         * Returns: a TimeOfDay representing the given time fields.
         *
         * Note: There is no verification of the range of values, or
         * normalization made.  So if you pass in larger values than the
         * maximum value for that field, they will be stored as that value.
         *
         * example:
         * --------------
         * auto tod = TimeOfDay(100, 100, 100, 10000);
         * assert(tod.hours == 100);
         * assert(tod.minutes == 100);
         * assert(tod.seconds == 100);
         * assert(tod.millis == 10000);
         * --------------
         */
        static TimeOfDay opCall (uint hours, uint minutes, uint seconds, uint millis=0)
        {
                TimeOfDay t = void;
                t.hours   = hours;
                t.minutes = minutes;
                t.seconds = seconds;
                t.millis  = millis;
                return t;
        }

        /**
         * constructor.
         * Params: ticks = ticks representing a Time value.  This is normalized
         * so that it represent a time of day (modulo-24 etc)
         *
         * Returns: a TimeOfDay value that corresponds to the time of day of
         * the given number of ticks.
         */
        static TimeOfDay opCall (long ticks)
        {
            return TimeOfDay(modulo24(ticks));
        }

        /// Ditto
        static TimeOfDay opCall (Duration dur)
        {
            // Note: Since this represents a time of day, hours needs to be
            // 0 <= hours < 24. Using `days` ensures that, even if we don't
            // use the value.
            auto splitted = dur.split!("days", "hours", "minutes", "seconds", "msecs");
            return TimeOfDay(cast(uint)splitted.hours, cast(uint)splitted.minutes,
                             cast(uint)splitted.seconds, cast(uint)splitted.msecs);
        }

        /**
         * construct a TimeSpan from the current fields
         *
         * Returns: a TimeOfDay representing the field values.
         *
         * Note: that fields are not checked against a valid range, so
         * setting 60 for minutes is allowed, and will just add 1 to the hour
         * component, and set the minute component to 0.  The result is
         * normalized, so the hours wrap.  If you pass in 25 hours, the
         * resulting TimeOfDay will have a hour component of 1.
         */
        TimeSpan span ()
        {
                return TimeSpan.fromHours(hours) +
                       TimeSpan.fromMinutes(minutes) +
                       TimeSpan.fromSeconds(seconds) +
                       TimeSpan.fromMillis(millis);
        }

        /**
         * internal routine to adjust ticks by one day. Also adjusts for
         * offsets in the BC era
         */
        package static TimeSpan modulo24 (long ticks)
        {
                ticks %= TimeSpan.TicksPerDay;
                if (ticks < 0)
                    ticks += TimeSpan.TicksPerDay;
                return TimeSpan (ticks);
        }
}

/******************************************************************************

    Generic Date representation

******************************************************************************/

struct Date
{
        public uint         era,            /// AD, BC
                            day,            /// 1 .. 31
                            year,           /// 0 to 9999
                            month,          /// 1 .. 12
                            dow,            /// 0 .. 6
                            doy;            /// 1 .. 366
}


/******************************************************************************

    Combination of a Date and a TimeOfDay

******************************************************************************/

struct DateTime
{
        public Date         date;       /// date representation
        public TimeOfDay    time;       /// time representation
}

unittest
{
    auto unix = time(null);

    test!("==")((Time.fromUnixTime(unix) - Time.epoch1970).seconds, unix);
}
