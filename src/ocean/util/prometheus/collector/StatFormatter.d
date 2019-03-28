/*******************************************************************************

    Contains methods that format primitive data members from structs or classes
    into strings that can be exported as responses to prometheus queries.

    Copyright:
        Copyright (c) 2019 dunnhumby Germany GmbH.
        All rights reserved

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

*******************************************************************************/

module ocean.util.prometheus.collector.StatFormatter;

import ocean.net.http.TaskHttpConnectionHandler;

import core.stdc.time;
import Traits = ocean.core.Traits;
import ocean.math.IEEE;
import ocean.text.convert.Formatter;
import ocean.transition;

/*******************************************************************************

    Format data members from a struct or a class into a string that can be
    added to a stat collection buffer for exporting to prometheus.

    The names and values of the members of the given struct are formatted as
    stat names and values, respectively.

    Params:
        ValuesT = The struct or class type to fetch the stat names from.
        values  = The struct or class to fetch stat values from.
        buffer  = The buffer to add the formatted stats to.

*******************************************************************************/

public static void formatStats ( ValuesT ) (
    ValuesT values, ref mstring buffer )
{
    static assert (is(ValuesT == struct) || is(ValuesT == class),
        "'values' parameter must be a struct or a class.");

    foreach (i, ValMemberT; typeof(ValuesT.tupleof))
    {
        static if (Traits.isPrimitiveType!(ValMemberT))
        {
            sformat(buffer, "{}", Traits.FieldName!(i, ValuesT));
            appendValue(*Traits.GetField!(i, ValMemberT, ValuesT)(&values),
                buffer);
        }
    }
}

/*******************************************************************************

    Format data members from a struct or a class, with a additional label name
    and value, into a string that can be added to a stat collection buffer for
    exporting to prometheus.

    Params:
        LabelName = The name of the label to annotate the stats with.
        ValuesT   = The struct or class type to fetch the stat names from.
        LabelT    = The type of the label's value.
        values    = The struct or class to fetch stat values from.
        label_val = The label value to annotate the stats with.
        buffer    = The buffer to add the formatted stats to.

*******************************************************************************/

public static void formatStats ( istring LabelName, ValuesT, LabelT ) (
    ValuesT values, LabelT label_val, ref mstring buffer )
{
    static assert (is(ValuesT == struct) || is(ValuesT == class),
        "'values' parameter must be a struct or a class.");

    foreach (i, ValMemberT; typeof(ValuesT.tupleof))
    {
        static if (Traits.isPrimitiveType!(ValMemberT))
        {
            sformat(buffer, "{} {{", Traits.FieldName!(i, ValuesT));

            appendLabel!(LabelName)(label_val, buffer);

            sformat(buffer, "}");
            appendValue(*Traits.GetField!(i, ValMemberT, ValuesT)(&values),
                buffer);
        }
    }
}

/*******************************************************************************

    Format data members from a struct or a class, with an additional struct or
    class to fetch label names and values from, into a string that can be added
    to a stat collection buffer for exporting to prometheus.

    Params:
        ValuesT = The struct or class type to fetch the stat names from.
        LabelsT = The struct or class type to fetch the label names from.
        values  = The struct or class to fetch stat values from.
        labels  = The struct or class holding the label values to annotate
                    the stats with.
        buffer  = The buffer to add the formatted stats to.

*******************************************************************************/

public static void formatStats ( ValuesT, LabelsT ) ( ValuesT values,
    LabelsT labels, ref mstring buffer )
{
    static assert (is(ValuesT == struct) || is(ValuesT == class),
        "'values' parameter must be a struct or a class.");
    static assert (is(LabelsT == struct) || is(LabelsT == class),
        "'labels' parameter must be a struct or a class.");

    foreach (i, ValMemberT; typeof(ValuesT.tupleof))
    {
        static if (Traits.isPrimitiveType!(ValMemberT))
        {
            sformat(buffer, "{} {{", Traits.FieldName!(i, ValuesT));

            bool first_label = true;

            foreach (j, LabelMemberT; typeof(LabelsT.tupleof))
            {
                if (first_label)
                {
                    first_label = false;
                }
                else
                {
                    sformat(buffer, ",");
                }

                appendLabel!(Traits.FieldName!(j, LabelsT))(
                    *Traits.GetField!(j, LabelMemberT, LabelsT)(&labels),
                    buffer);
            }

            sformat(buffer, "}");
            appendValue(*Traits.GetField!(i, ValMemberT, ValuesT)(&values),
                buffer);
        }
    }
}

/*******************************************************************************

    Appends a label name and value to a given buffer. If the value is of a
    floating-point type, then appends it with a precision upto 6 decimal places.

    Params:
        LabelName = The name of the label to annotate the stats with.
        LabelT    = The type of the label's value.
        label_val = The label value to annotate the stats with.
        buffer    = The buffer to append the label to.

*******************************************************************************/

private static void appendLabel ( istring LabelName, LabelT ) (
    LabelT label_val, ref mstring buffer )
{
    static if (Traits.isFloatingPointType!(LabelT))
    {
        sformat(buffer, "{}=\"{:6.}\"", LabelName,
            getSanitized(label_val));
    }
    else
    {
        sformat(buffer, "{}=\"{}\"", LabelName, label_val);
    }
}

// Test appending a label with a value of type string
unittest
{
    mstring buffer;
    appendLabel!("labelname")("labelval", buffer);
    test!("==")(buffer, "labelname=\"labelval\"");
}

// Test appending a label with an integer type value
unittest
{
    mstring buffer;
    appendLabel!("labelname")(2345678UL, buffer);
    test!("==")(buffer, "labelname=\"2345678\"");
}

// Test appending a label with a floting point type value
unittest
{
    mstring buffer;
    appendLabel!("labelname")(3.1415926, buffer);
    test!("==")(buffer, "labelname=\"3.141593\"");
}

/*******************************************************************************

    Appends a stat value to a given buffer. If the value is of a floating-point
    type, then appends it with a precision of upto 6 decimal places.

    Params:
        T      = The datatype of the value.
        value  = The value to append to the buffer.
        buffer = The buffer to which the stat value will be appended.

*******************************************************************************/

private static void appendValue ( T ) ( T value, ref mstring buffer )
{
    static if (Traits.isFloatingPointType!(T))
    {
        sformat(buffer, " {:6.}\n", getSanitized(value));
    }
    else
    {
        sformat(buffer, " {}\n", value);
    }
}

// Test appending a non-floating-point values
unittest
{
    mstring buffer;
    appendValue(32768UL, buffer);
    test!("==")(buffer, " 32768\n");
}

// Test appending a floating-point value having less than 6 decimal places
unittest
{
    mstring buffer;
    appendValue(3.14159, buffer);
    test!("==")(buffer, " 3.14159\n");
}

// Test appending a floating-point value having more than 6 decimal places
unittest
{
    mstring buffer;
    appendValue(3.1415926, buffer);
    test!("==")(buffer, " 3.141593\n");
}

/*******************************************************************************

    Sanitizes floating-point type values.

    If the datatype of the value is a floating-point type, then returns 0.0
    for NaN and the datatype's maximum value for +/-Inf.
    If the datatype of the value is not a floating-point type, then returns
    the given value without any modification.

    Params:
        T      = The datatype of the value.
        value  = The value to append to sanitize.

    Returns:
        The sanitized value, if the input is of a floating-point type,
        otherwise the given value itself.

*******************************************************************************/

private static T getSanitized ( T ) ( T val )
{
    static if (Traits.isFloatingPointType!(T))
    {
        if (isNaN(val))
        {
            return 0.0;
        }
        else if (isInfinity(val))
        {
            return T.max;
        }
    }

    return val;
}

// Test sanitization of a floating type value as NaN
unittest
{
    test!("==")(getSanitized(double.init), 0.0);
}

// Test sanitization of a floating point value as infinity
unittest
{
    test!("==")(getSanitized(double.infinity), double.max);
}

// Test that sanitization does not alter any floating point value that is
// not NaN or Inf.
unittest
{
    double pi = 3.141592;
    test!("==")(getSanitized(pi), 3.141592);
}


version (UnitTest)
{
    import ocean.core.Test;
    import ocean.transition;

    struct Statistics
    {
        ulong up_time_s;
        size_t count;
        float ratio;
        double fraction;
        real very_real;
    }

    struct Labels
    {
        hash_t id;
        cstring job;
        float perf;
    }
}

/// Test collecting populated stats, but without any label.
unittest
{
    auto expected = "up_time_s 3600\ncount 347\nratio 3.14\nfraction 6.023\n" ~
        "very_real 0.43\n";

    mstring actual;
    formatStats(Statistics(3600, 347, 3.14, 6.023, 0.43), actual);

    test!("==")(actual, expected);
}

/// Test collecting populated stats with one label
unittest
{
    auto expected =
        "up_time_s {id=\"123.034\"} 3600\ncount {id=\"123.034\"} 347\n" ~
        "ratio {id=\"123.034\"} 3.14\nfraction {id=\"123.034\"} 6.023\n" ~
        "very_real {id=\"123.034\"} 0.43\n";

    mstring actual;
    formatStats!("id")(
        Statistics(3600, 347, 3.14, 6.023, 0.43), 123.034, actual);

    test!("==")(actual, expected);
}

/// Test collecting stats having initial values with multiple labels
unittest
{
    auto expected =
        "up_time_s {id=\"1235813\",job=\"ocean\",perf=\"3.14159\"} 3600\n" ~
        "count {id=\"1235813\",job=\"ocean\",perf=\"3.14159\"} 347\n" ~
        "ratio {id=\"1235813\",job=\"ocean\",perf=\"3.14159\"} 3.14\n" ~
        "fraction {id=\"1235813\",job=\"ocean\",perf=\"3.14159\"} 6.023\n" ~
        "very_real {id=\"1235813\",job=\"ocean\",perf=\"3.14159\"} 0.43\n";

    mstring actual;
    formatStats(Statistics(3600, 347, 3.14, 6.023, 0.43),
        Labels(1_235_813, "ocean", 3.14159), actual);

    test!("==")(actual, expected);
}
