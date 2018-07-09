/*******************************************************************************

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.time.Time_test;

import ocean.time.Time;
import ocean.core.Test;
import ocean.text.convert.Formatter;
import ocean.text.convert.DateTime_tango;

unittest
{
    test(TimeSpan.zero > TimeSpan.min);
    test(TimeSpan.max  > TimeSpan.zero);
    test(TimeSpan.max  > TimeSpan.min);
    test(TimeSpan.zero >= TimeSpan.zero);
    test(TimeSpan.zero <= TimeSpan.zero);
    test(TimeSpan.max >= TimeSpan.max);
    test(TimeSpan.max <= TimeSpan.max);
    test(TimeSpan.min >= TimeSpan.min);
    test(TimeSpan.min <= TimeSpan.min);

    test(TimeSpan.fromSeconds(50).seconds is 50);
    test(TimeSpan.fromSeconds(5000).seconds is 5000);
    test(TimeSpan.fromMinutes(50).minutes is 50);
    test(TimeSpan.fromMinutes(5000).minutes is 5000);
    test(TimeSpan.fromHours(23).hours is 23);
    test(TimeSpan.fromHours(5000).hours is 5000);
    test(TimeSpan.fromDays(6).days is 6);
    test(TimeSpan.fromDays(5000).days is 5000);

    test(TimeSpan.fromSeconds(50).time.seconds is 50);
    test(TimeSpan.fromSeconds(5000).time.seconds is 5000 % 60);
    test(TimeSpan.fromMinutes(50).time.minutes is 50);
    test(TimeSpan.fromMinutes(5000).time.minutes is 5000 % 60);
    test(TimeSpan.fromHours(23).time.hours is 23);
    test(TimeSpan.fromHours(5000).time.hours is 5000 % 24);

    auto tod = TimeOfDay (25, 2, 3, 4);
    tod = tod.span.time;
    test(tod.hours is 1);
    test(tod.minutes is 2);
    test(tod.seconds is 3);
    test(tod.millis is 4);
}

// pretty time formatting
unittest
{
    test!("==")(
        format("{}", asPrettyStr(Time.epoch1970)),
        "01/01/70 00:00:00"
    );
    test!("==")(
        format("{}", asPrettyStr(Time.epoch1970 + TimeSpan.fromDays(5))),
        "01/06/70 00:00:00"
    );
}

// raw time
unittest
{
    test!("==")(
        format("{}", Time.epoch1970),
        "{ ticks_: 621355968000000000 }"
    );
    test!("==")(
        format("{}", Time.epoch1970 + TimeSpan.fromDays(5)),
        "{ ticks_: 621360288000000000 }"
    );
}
