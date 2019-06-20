/*******************************************************************************

    Classes that can be used to parse the graphite stats.

    Parses an `InputStream` to `StatsLine`. The lines can be iterated using a
    foreach. Sometimes only the last stat line is important.
    The `StatsLogReader.last` method will return only that line.

    The `StatsLine` struct parses one stat line.

    Refer to the class' description for information about their actual usage.

    Copyright:
        Copyright (C) 2018 dunnhumby Germany GmbH. All rights reserved

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.log.StatsReader;

import ocean.transition;
import ocean.core.Buffer;
import ocean.core.Enforce;
import ocean.core.array.Search;
import ocean.io.model.IConduit;
import ocean.io.stream.Iterator;
import ocean.io.stream.Lines;

version (UnitTest)
{
    import ocean.io.device.Array;
    import ocean.util.app.DaemonApp;
    import ocean.core.Test;
}

/**************************************************************************

    Struct that parses a stats line

**************************************************************************/

public struct StatsLine
{
    /**************************************************************************

        The stats after the date and time were removed

    **************************************************************************/

    private cstring line;

    /**************************************************************************

        The line date

    **************************************************************************/

    public cstring date;

    /**************************************************************************

        The line time

    **************************************************************************/

    public cstring time;

    /**************************************************************************

        Create an StatsLine

        Params:
            line = a line stat

        Returns:
            A StatsLine

    **************************************************************************/

    static public StatsLine opCall (cstring line)
    {
        enforce(line.length > 0, "Can not parse an empty line");
        StatsLine stats_line;
        auto len = line.length;

        auto date_end_position = find(line, " ");
        stats_line.date = line[0 .. date_end_position];

        auto time_begin_position = date_end_position + 1;
        auto time_end_position = find(line[time_begin_position .. len], " ") + time_begin_position;
        stats_line.time = line[time_begin_position .. time_end_position];

        stats_line.line = line[time_end_position .. len];

        return stats_line;
    }

    /**************************************************************************

        Returns the value associated to a key

        Params:
            key = the stats key

        Return:
            the value associated with the key

    **************************************************************************/

    public cstring opIndex (cstring key) const
    {
        auto position = find(line[], key);

        enforce(position < line.length, idup(key ~ " is not present in the stats"));

        enforce(line[position - 1 .. position] == " ",
            idup(key ~ " is not present in the stats"));
        enforce(line[position + key.length .. position + key.length + 1] == ":",
            idup(key ~ " is not present in the stats"));

        auto rest = line[position .. line.length];

        auto begin = find(rest, ':') + 1;
        auto end = find(rest, ' ');

        return rest[begin .. end];
    }

    /**************************************************************************

        Copy the structure

        Return:
            a new copy of the structure

    **************************************************************************/

    public StatsLine dup()
    {
        StatsLine stats_line;

        stats_line.line = (&this).line.dup;
        stats_line.date = (&this).date.dup;
        stats_line.time = (&this).time.dup;

        return stats_line;
    }
}

/// Parsing a valid stat line
unittest
{
    auto line = StatsLine("2018-09-12 10:03:07,598 cpu_usage:64.96 memory:330.19");

    /// It should not extract a missing key
    testThrown!(Exception)(line["missing_key"]);

    /// It should not extract a key when the name is not fully provided
    testThrown!(Exception)(line["pu_usage"]);
    testThrown!(Exception)(line["cpu_usag"]);

    /// Valid indexes
    test!("==")(line["cpu_usage"], "64.96");
    test!("==")(line["memory"], "330.19");
    test!("==")(line.date, "2018-09-12");
    test!("==")(line.time, "10:03:07,598");
}

/// Parsing a stat line with missing values
unittest
{
    auto line = StatsLine("2018-09-12 10:03:07,598 cpu_usage: memory:");

    /// It should return an empty string
    test!("==")(line["cpu_usage"], "");
    test!("==")(line["memory"], "");
}

/// Parsing a stat line with missing space separator
unittest
{
    auto line = StatsLine("2018-09-12 10:03:07,598 2018-09-12 10:03:07,598 cpu_usage:64.96memory:330.19");

    /// It should return the value after column
    test!("==")(line["cpu_usage"], "64.96memory:330.19");

    /// It should not find the key memory, since is parsed as a value for cpu_usage
    testThrown!(Exception)(line["memory"]);
}

/// Duplicating a stat line
unittest
{
    auto line = StatsLine("2018-09-12 10:03:07,598 2018-09-12 10:03:07,598 cpu_usage:64.96 memory:330.19");
    auto line_copy = line.dup;

    line.line.length = 0;
    line.date.length = 0;
    line.time.length = 0;

    /// It should return an empty string
    test!("==")(line_copy["cpu_usage"], "64.96");
    test!("==")(line_copy.date, "2018-09-12");
    test!("==")(line_copy.time, "10:03:07,598");
}

/******************************************************************************

    Class that iterarates through a char stream and extracts the StatsLines

******************************************************************************/

public class StatsLogReader
{
    /**************************************************************************

        Struct used to iterate through stat lines that are not empty

    **************************************************************************/

    private struct StatLinesIterator
    {
        /**********************************************************************

            The line stream

        **********************************************************************/

        private Lines lines;

        /***************************************************************************

            Enables 'foreach' iteration over the stat lines.

            Params:
                dg = delegate called for each argument

        ***************************************************************************/

        public int opApply ( scope int delegate(ref Const!(char[])) dg )
        {
            int result;

            foreach (line; (&this).lines)
            {
                if (line.length == 0)
                {
                    continue;
                }

                result = dg(line);

                if ( result != 0 )
                {
                    break;
                }
            }

            return result;
        }
    }

    /******************************************************************************

        Line iterator

    ******************************************************************************/

    private StatLinesIterator lines;

    /**************************************************************************

        Constructor

        Params:
            stream = a char stream that contains stats

    **************************************************************************/

    this (InputStream stream)
    {
        this.lines = StatLinesIterator(new Lines(stream));
    }

    /***************************************************************************

        Get the last line from the stats

        Returns:
            The last line

    ***************************************************************************/

    public Const!(StatsLine) last ( )
    {
        auto last_line = Buffer!(char)();

        foreach (line; this.lines)
        {
            last_line = line;
        }

        enforce(last_line.length > 0, "The stats are empty");

        Const!(StatsLine) stats_line = StatsLine(last_line[]);

        return stats_line;
    }


    /***************************************************************************

        Enables 'foreach' iteration over the stat lines.

        Params:
            dg = delegate called for each argument

    ***************************************************************************/

    public int opApply ( scope int delegate(ref Const!(StatsLine)) dg )
    {
        int result;

        foreach (line; this.lines)
        {
            Const!(StatsLine) stats_line = StatsLine(line);
            result = dg(stats_line);

            if ( result != 0 )
            {
                break;
            }
        }

        return result;
    }

    /******************************************************************************

        ditto

    ******************************************************************************/

    public int opApply ( scope int delegate(ref size_t index, ref Const!(StatsLine)) dg )
    {
        int result;
        size_t index;

        foreach (line; this.lines)
        {
            Const!(StatsLine) stats_line = StatsLine(line);
            result = dg(index, stats_line);
            index++;

            if ( result != 0 )
            {
                break;
            }
        }

        return result;
    }
}

/// Read a list of stats
unittest
{
    auto data = new Array(
        "2018-09-12 10:03:07,598 2018-09-12 10:03:07,598 cpu_usage:1 memory:3\n" ~
        "2018-09-12 10:03:07,598 2018-09-12 10:03:07,598 cpu_usage:2 memory:4\n".dup);

    auto reader = new StatsLogReader(data);

    /// Iteration without index
    size_t index;
    foreach (line; reader)
    {
        if (index == 0)
        {
            test!("==")(line["cpu_usage"], "1");
            test!("==")(line["memory"], "3");
        }
        else
        {
            test!("==")(line["cpu_usage"], "2");
            test!("==")(line["memory"], "4");
        }
        index++;
    }

    test!("==")(index, 2);

    /// Iteration with index
    data = new Array(
        "2018-09-12 10:03:07,598 2018-09-12 10:03:07,598 cpu_usage:1 memory:3\n" ~
        "2018-09-12 10:03:07,598 2018-09-12 10:03:07,598 cpu_usage:2 memory:4\n".dup);
    reader = new StatsLogReader(data);
    index = 0;
    foreach (i, line; reader)
    {
        if (i == 0)
        {
            test!("==")(line["cpu_usage"], "1");
            test!("==")(line["memory"], "3");
        }
        else
        {
            test!("==")(line["cpu_usage"], "2");
            test!("==")(line["memory"], "4");
        }

        index = i;
    }

    test!("==")(index, 1);
}

/// Get the last line
unittest
{
    auto data = new Array(
        "2018-09-12 10:03:07,598 2018-09-12 10:03:07,598 cpu_usage:1 memory:3\n" ~
        "2018-09-12 10:03:07,598 2018-09-12 10:03:07,598 cpu_usage:2 memory:4\n".dup);

    /// It should be able to get the last line with a function call
    auto reader = new StatsLogReader(data);
    auto line = reader.last();

    test!("==")(line["cpu_usage"], "2");
    test!("==")(line["memory"], "4");

    /// It should raise an error for an empty string
    data = new Array("".dup);
    reader = new StatsLogReader(data);

    testThrown!(Exception)(reader.last());
}
