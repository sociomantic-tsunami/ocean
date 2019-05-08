/*******************************************************************************

    A timing statistics counter for any sort of transaction that takes a
    microsecond to a second to complete. Collects the following statistical
    information:
    - a logarithmic time histogram with bins from ≥1µs to <1s, three bins per
      power of ten in a  stepping of 1 .. 2 .. 5 .., plus one bin for each <1µs
      and ≥1s,
    - the total number of transactions and the aggregated total completion time.

    To reset all counters to zero use `TimeHistogram.init`.

    copyright: Copyright (c) 2018 dunnhumby Germany GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

*******************************************************************************/

module ocean.math.TimeHistogram;

import ocean.transition;

/// ditto
struct TimeHistogram
{
    import ocean.transition;
    import ocean.core.Traits : FieldName;

    /***************************************************************************

        The total aggregated transaction completion time in µs.

    ***************************************************************************/

    public ulong total_time_micros;

    /***************************************************************************

        The total number of transactions.

    ***************************************************************************/

    public uint count;

    /***************************************************************************

        The bins of the timing histogram. The stepping of the lower bounds of
        the bins is, in µs:

        0:          0;
        1:          1; 2:        2; 3:        5;
        4:         10; 5:       20; 6:       50;
        7:        100; 8:      200; 9:      500;
        10:     1,000; 11:   2,000; 12:   5,000;
        13:    10,000; 14:  20,000; 15:  50,000;
        16:   100,000; 17: 200,000; 18: 500,000;
        19: 1,000,000

    ***************************************************************************/

    public uint[20] bins;

    /***************************************************************************

        Struct with one uint field per bin (see this.bins), named as follows:
            from_0us ("from 0 microseconds"), from_1us, from_2us, from_5us,
            from_10us, from_20us, from_50us, from_100us, from_200us, from_500us,
            from_1ms, from_2ms, ...,
            from_1s ("from 1 second")

        Useful, for example, for logging the whole histogram.

    ***************************************************************************/

    public struct Bins
    {
        /***********************************************************************

            Interprets the passed bins array as a Bins instance.

            Params:
                array = bins array to reinterpret

            Returns:
                the passed bins array as a Bins instance

        ***********************************************************************/

        public static Bins fromArray ( typeof(TimeHistogram.bins) array )
        {
            return *(cast(Bins*)array.ptr);
        }

        /***********************************************************************

            Sanity check that the offset of the fields of this struct match the
            offsets of the elements of a TimeHistogram.bins array. (i.e. that
            the fromArray() function can work as intended.)

        ***********************************************************************/

        static assert(fieldOffsetsCorrect());

        /***********************************************************************

            Returns:
                true if the offset of the fields of this struct match the
                offsets of the elements of a TimeHistogram.bins array

        ***********************************************************************/

        private static bool fieldOffsetsCorrect ( )
        {
            foreach ( i, field; typeof(Bins.tupleof) )
                if ( Bins.tupleof[i].offsetof != i * TimeHistogram.init.bins[i].sizeof )
                    return false;
            return true;
        }

        /***********************************************************************

            CTFE generator of the fields of this struct.

            Params:
                suffixes = metric suffixes for the series of fields

            Returns:
                code for the series of fields dividing the specified order of
                magnitude range into bands of [1, 2, 5]. (See unittest for
                examples.)

        ***********************************************************************/

        private static istring divisionBinVariables ( istring[] suffixes )
        in
        {
            assert(suffixes.length > 0);
        }
        body
        {
            enum type = typeof(TimeHistogram.bins[0]).stringof;

            istring res;

            res ~= type ~ " from_0" ~ suffixes[0] ~ ";";

            foreach ( suffix; suffixes[0..$-1] )
                foreach ( zeros; ["", "0", "00"] )
                    foreach ( div; ["1", "2", "5"] )
                        res  ~= type ~ " from_" ~ div ~ zeros ~ suffix ~ ";";

            res ~= type ~ " from_1" ~ suffixes[$-1] ~ ";";

            return res;
        }

        unittest
        {
            test!("==")(divisionBinVariables(["us"]), "uint from_0us;uint from_1us;");
            test!("==")(divisionBinVariables(["us", "ms"]),
                "uint from_0us;uint from_1us;uint from_2us;uint from_5us;uint from_10us;uint from_20us;uint from_50us;uint from_100us;uint from_200us;uint from_500us;uint from_1ms;");
        }

        /***********************************************************************

            Fields.

        ***********************************************************************/

        mixin(divisionBinVariables(["us", "ms", "s"]));
    }

    /***************************************************************************

        The number of fields of Bins must equal the length of the fixed-length
        array this.bins.

    ***************************************************************************/

    static assert(Bins.tupleof.length == bins.length);

    /***************************************************************************

        Counts a transaction that took `us` µs to complete by incrementing the
        corresponding histogram bin and the total number of transactions and
        adding `us` to the total transaction time.

        Params:
            us = the transaction completion time in microseconds

        Returns:
            us

    ***************************************************************************/

    public ulong countMicros ( ulong us )
    {
        (&this).count++;
        (&this).total_time_micros += us;
        (&this).bins[binIndex(us)]++;
        return us;
    }

    /***************************************************************************

        Returns:
            the mean time (in microseconds) taken by each transaction (may, of
            course, be NaN, if this.count == 0)

    ***************************************************************************/

    public double mean_time_micros ( )
    in
    {
        assert((&this).count || !(&this).total_time_micros);
    }
    body
    {
        return cast(double)(&this).total_time_micros / (&this).count;
    }

    /***************************************************************************

        Gets the count of transactions in the specified bin.

        Params:
            bin_name = string name of the bin to get the count for. Must match
                the name of one of the fields of Bins

        Returns:
            the number of transactions in the specified bin

    ***************************************************************************/

    public ulong countFor ( istring bin_name ) ( )
    {
        mixin("static assert(is(typeof(Bins.init." ~ bin_name ~ ")));");

        mixin("const offset = Bins.init." ~ bin_name ~ ".offsetof;");
        enum index = offset / (&this).bins[0].sizeof;
        return (&this).bins[index];
    }

    unittest
    {
        TimeHistogram histogram;
        histogram.countMicros(7);
        test!("==")(histogram.countFor!("from_5us")(), 1);
    }

    /***************************************************************************

        Returns:
            the complete histogram as a Bins struct

    ***************************************************************************/

    public Bins stats ( )
    {
        return Bins.fromArray((&this).bins);
    }

    unittest
    {
        TimeHistogram histogram;
        histogram.countMicros(7);
        auto bins = histogram.stats();
        test!("==")(bins.from_5us, 1);
    }

    /***************************************************************************

        Calculates the bin index `i` from `us`:

        - If us = 0 then i = 0.
        - Otherwise, if us < 1_000_000 then i = floor(log_10(us) * 3) + 1.
        - Otherwise i = bins.length - 1.

        Params:
            us = the microseconds value to calculate the bin index from

        Returns:
            the bin index.

    ***************************************************************************/

    private static uint binIndex ( ulong us )
    {
        if (!us)
            return 0;

        static Immut!(uint[4][2]) powers_of_10 = [
            [1,     10,     100,     1_000],
            [1_000, 10_000, 100_000, 1_000_000]
        ];

        foreach (uint i, p1000; powers_of_10)
        {
            if (us < p1000[$ - 1])
            {
                foreach (uint j, p; p1000[1 .. $])
                {
                    if (us < p)
                    {
                        auto b = (i * cast(uint)(p1000.length - 1) + j) * 3 + 1;
                        if (us >= (p1000[j] * 2))
                        {
                            b++;
                            b += (us >= (p / 2));
                        }
                        return b;
                    }
                }
                assert(false);
            }
        }

        return TimeHistogram.bins.length - 1;
    }
}

version (UnitTest)
{
    import ocean.core.Test;
}

unittest
{
    TimeHistogram th;

    // Tests if `expected` matches a) the sum of all bin counters and
    // b) th.count.
    void checkBinSum ( uint expected, istring f = __FILE__, int ln = __LINE__ )
    {
        uint sum = 0;
        foreach (bin; th.bins)
            sum += bin;
        test!("==")(th.count, sum, f, ln);
        test!("==")(sum, expected, f, ln);
    }

    // 0µs: Should increment bins[0] and `count` to 1 and leave `total == 0`.
    // All other bins should remain 0.
    th.countMicros(0);
    test!("==")(th.total_time_micros, 0);
    test!("==")(th.count, 1);
    test!("==")(th.bins[0], 1);
    test!("==")(th.stats.from_0us, 1);
    test!("==")(th.countFor!("from_0us"), 1);
    foreach (bin; th.bins[1 .. $])
        test!("==")(bin, 0);
    checkBinSum(1);

    // 1.500ms: Should increment bins[10] to 1, `count` to 2 and `total` to 1500
    // and leave bin[0] == 1. All other bins should remain 0.
    th.countMicros(1500);
    test!("==")(th.total_time_micros, 1500);
    test!("==")(th.count, 2);
    test!("==")(th.bins[0], 1);
    test!("==")(th.stats.from_0us, 1);
    test!("==")(th.countFor!("from_0us"), 1);
    test!("==")(th.bins[10], 1);
    test!("==")(th.stats.from_1ms, 1);
    test!("==")(th.countFor!("from_1ms"), 1);
    checkBinSum(2);
    foreach (i, bin; th.bins)
    {
        switch (i)
        {
            default:
                test!("==")(th.bins[i], 0);
                goto case;
            case 0, 10:
        }
    }

    // 1,234.567890s (more than 0.999999s): Should increment bins[$ - 1] to 1,
    // `count` to 3 and `total` to 1,234,567,890 + 1500 and leave bin[0] == 1
    // and bin[10] == 1. All other bins should remain 0.
    th.countMicros(1_234_567_890);
    test!("==")(th.total_time_micros, 1_234_567_890 + 1500);
    test!("==")(th.count, 3);
    test!("==")(th.bins[0], 1);
    test!("==")(th.stats.from_0us, 1);
    test!("==")(th.countFor!("from_0us"), 1);
    test!("==")(th.bins[10], 1);
    test!("==")(th.stats.from_1ms, 1);
    test!("==")(th.countFor!("from_1ms"), 1);
    test!("==")(th.bins[$ - 1], 1);
    test!("==")(th.stats.from_1s, 1);
    test!("==")(th.countFor!("from_1s"), 1);
    checkBinSum(3);
    foreach (i, bin; th.bins)
    {
        switch (i)
        {
            default:
                test!("==")(th.bins[i], 0);
                goto case;
            case 0, 10, th.bins.length - 1:
        }
    }
}

unittest
{
    test!("==")(TimeHistogram.binIndex(0), 0);
    test!("==")(TimeHistogram.binIndex(1), 1);
    test!("==")(TimeHistogram.binIndex(555), 9);
    test!("==")(TimeHistogram.binIndex(999_999), TimeHistogram.bins.length - 2);
    test!("==")(TimeHistogram.binIndex(1_000_000), TimeHistogram.bins.length - 1);
    test!("==")(TimeHistogram.binIndex(ulong.max), TimeHistogram.bins.length - 1);
}
