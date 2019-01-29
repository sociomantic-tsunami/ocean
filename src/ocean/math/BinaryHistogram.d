/*******************************************************************************

    An integer, binary logarithmic statistics counter

    Collects the following statistical information:
    - a binary logarithmic histogram with bins from ≥1 to <2^MaxPow2
      (see template documentation, below), one bin per power of two, plus one
      bin for each 0 and ≥2^MaxPow2,
    - the total number of entries and the aggregated total amount.

    To reset all counters to zero use `BinaryHistogram.init`.

    Copyright:
        Copyright (c) 2017-2018 dunnhumby Germany GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

*******************************************************************************/

module ocean.math.BinaryHistogram;

import ocean.transition;
import ocean.core.Verify;

/*******************************************************************************

    An integer, binary logarithmic statistics counter

    Params:
        MaxPow2 = the maximum power of two that is tracked in the lower bins of
            the counter. Any values >= 2^MaxPow2 will be aggregated in the upper
            bin.
        Suffix = suffix for the names of the fields of the Bins accessor struct

*******************************************************************************/

public struct BinaryHistogram ( uint MaxPow2, istring Suffix = "" )
{
    // Values above the range of ulong are not supported.
    static assert(MaxPow2 < 64,
        "Buckets for 2^64-bit values or larger unsupported");

    import core.bitop: bsr;

    /// The number of bins. (The specified number of powers of two, plus one bin
    /// for 0B and one for ≥1<<MaxPow2.)
    private enum NumBins = MaxPow2 + 2;

    /// The aggregated total from all calls to `add()`.
    public ulong total;

    /// The total number of calls to `add()`.
    public uint count;

    /***************************************************************************

        The bins of the byte count histogram. Given a number, the index i of the
        bin to increment is calculated as follows:

        - If 1 ≤ n and n < 2^MaxPow2: i = floor(log_2(n)) + 1,
        - otherwise, if t < 1: i = 0,
        - otherwise, t ≥ 2^MaxPow2: i = NumBins - 1.

        For example, for MaxPow2 == 16, the following bins exist:
        0: 0,
        1:       1, 2:  2 -   3, 3:   4 -   7, 4:   8 -  15,  5:  16 -   31,
        6: 32 - 63, 7: 64 - 127, 8: 128 - 255, 9: 256 - 511, 10: 512 - 1023,
        11: 1ki -  (2ki-1), 12:  2ki -  (4ki-1), 13:  4ki -  (8ki-1),
        14: 8ki - (16ki-1), 15: 16ki - (32ki-1), 16: 32ki - (64ki-1),
        17: 64ki - ∞

    ***************************************************************************/

    private uint[NumBins] bins;

    /***************************************************************************

        Struct with one uint field per bin (see this.bins), named as follows
        (assuming Suffix == ""):
            from_0, from_1, from_2, from_4, from_8,
            from_16, ...,
            from_1Ki, from_2Ki, ...,
            etc

        Useful, for example, for logging the whole histogram. An instance of
        this struct is returned by `stats()`.

    ***************************************************************************/

    private struct Bins
    {
        import CTFE = ocean.meta.codegen.CTFE : toString;

        /***********************************************************************

            Interprets the passed bins array as a Bins instance.

            Params:
                array = bins array to reinterpret

            Returns:
                the passed bins array as a Bins instance

        ***********************************************************************/

        public static Bins fromArray ( typeof(BinaryHistogram.bins) array )
        {
            return *(cast(Bins*)array.ptr);
        }

        /***********************************************************************

            Sanity check that the offset of the fields of this struct match the
            offsets of the elements of a BinaryHistogram.bins array. (i.e.
            that the fromArray() function can work as intended.)

        ***********************************************************************/

        static assert(fieldOffsetsCorrect());

        /***********************************************************************

            Returns:
                true if the offset of the fields of this struct match the
                offsets of the elements of a BinaryHistogram.bins array

        ***********************************************************************/

        private static bool fieldOffsetsCorrect ( )
        {
            foreach ( i, field; typeof(Bins.tupleof) )
                if ( Bins.tupleof[i].offsetof != i * BinaryHistogram.init.bins[i].sizeof )
                    return false;
            return true;
        }

        /***********************************************************************

            CTFE generator of the fields of this struct.

            Returns:
                code for the series of fields for bins up to the specified
                maximum power of 2. (See unittest for examples.)

        ***********************************************************************/

        private static istring divisionBinVariables ( )
        {
            enum type = typeof(BinaryHistogram.bins[0]).stringof;

            istring res;

            istring formatCount ( ulong count )
            {
                enum prefixes = [""[], "Ki", "Mi", "Gi", "Ti", "Pi", "Ei"];

                uint prefix;
                while ( (prefix < prefixes.length - 1) && count >= 1024 )
                {
                    count /= 1024;
                    prefix++;
                }
                return CTFE.toString(count) ~ prefixes[prefix] ~ Suffix;
            }

            res ~= type ~ " from_" ~ formatCount(0) ~ ";";

            for ( size_t power = 0; power <= MaxPow2; power++ )
                res ~= type ~ " from_" ~ formatCount(1UL << power) ~ ";";

            return res;
        }

        /// Fields.
        mixin(divisionBinVariables());
    }

    /// The number of fields of Bins must equal the length of the fixed-length
    /// array this.bins.
    static assert(Bins.tupleof.length == bins.length);

    /***************************************************************************

        Adds the specified value to the histogram, incrementing the
        corresponding bin and the total number of transactions and adding `n` to
        the total count.

        Params:
            n = the value to add to the histogram

        Returns:
            n

    ***************************************************************************/

    public ulong add ( ulong n )
    {
        (&this).count++;
        (&this).total += n;
        (&this).bins[n? (n < (1UL << MaxPow2))? bsr(n) + 1 : $ - 1 : 0]++;
        return n;
    }

    /***************************************************************************

        Returns:
            the mean value over all calls to `add`.
            May be NaN if this.count == 0.

    ***************************************************************************/

    public double mean ( )
    {
        verify((&this).count || !(&this).total);

        return (&this).total / cast(double)(&this).count;
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

    /***************************************************************************

        Returns:
            the complete histogram as a Bins struct

    ***************************************************************************/

    public Bins stats ( )
    {
        return Bins.fromArray((&this).bins);
    }
}

version (UnitTest)
{
    import ocean.core.Test;
    import ocean.util.log.Stats;
}

///
unittest
{
    // Histogram of bytes (suffix B) with buckets up to 1MiB.
    BinaryHistogram!(20, "B") hist;

    // Count some transactions.
    hist.add(12);
    hist.add(0);
    hist.add(0);
    hist.add(1_000_000);

    // Get the stats from the histogram.
    auto stats = hist.stats();

    // Extract counts from individual bins.
    auto zeros = stats.from_0B;
    auto too_big = stats.from_1MiB;

    // Log compete histogram stats.
    void logHistogram ( StatsLog stats_log )
    {
        stats_log.add(stats);
    }
}

// Tests for divisionBinVariables function.
unittest
{
    test!("==")(BinaryHistogram!(0, "B").Bins.divisionBinVariables(),
        "uint from_0B;uint from_1B;");
    test!("==")(BinaryHistogram!(16, "B").Bins.divisionBinVariables(),
        "uint from_0B;uint from_1B;uint from_2B;uint from_4B;uint from_8B;uint from_16B;uint from_32B;uint from_64B;uint from_128B;uint from_256B;uint from_512B;uint from_1KiB;uint from_2KiB;uint from_4KiB;uint from_8KiB;uint from_16KiB;uint from_32KiB;uint from_64KiB;");
}

// Corner-case test: MaxPow2 == 0
unittest
{
    BinaryHistogram!(0) hist;
    hist.add(ulong.max);
    test!("==")(hist.stats.from_0, 0);
    test!("==")(hist.stats.from_1, 1);
}

// Corner-case test: MaxPow2 == 63
unittest
{
    BinaryHistogram!(63) hist;
    hist.add(ulong.max);
    test!("==")(hist.stats.from_0, 0);
    test!("==")(hist.stats.from_8Ei, 1);
}

// Corner-case test: MaxPow2 > 63 does not compile
unittest
{
    static assert(!is(typeof({ BinaryHistogram!(64) hist; })));
}

unittest
{
    BinaryHistogram!(16, "B") hist;

    // Tests if hist.count is `expected` and matches the sum of all bin
    // counters.
    void checkBinSum ( uint expected, istring f = __FILE__, int ln = __LINE__ )
    {
        test!("==")(hist.count, expected, f, ln);
        uint sum = 0;
        foreach (bin; hist.bins)
            sum += bin;
        test!("==")(sum, hist.count, f, ln);
    }

    // 0 Bytes: Should increment bins[0] and `count` to 1 and leave
    // `total == 0`. All other bins should remain 0.
    hist.add(0);
    test!("==")(hist.total, 0);
    checkBinSum(1);
    test!("==")(hist.bins[0], 1);
    test!("==")(hist.stats.from_0B, 1);
    test!("==")(hist.countFor!("from_0B"), 1);
    foreach (bin; hist.bins[1 .. $])
        test!("==")(bin, 0);

    // 1500 Bytes: Should increment bins[11] to 1, `count` to 2 and `total` to
    // 1500. bins[0] should stay at 1. All other bins should remain 0.
    hist.add(1500);
    test!("==")(hist.total, 1500);
    checkBinSum(2);
    test!("==")(hist.bins[0], 1);
    test!("==")(hist.stats.from_0B, 1);
    test!("==")(hist.countFor!("from_0B"), 1);
    test!("==")(hist.bins[11], 1);
    test!("==")(hist.stats.from_1KiB, 1);
    test!("==")(hist.countFor!("from_1KiB"), 1);
    foreach (i, bin; hist.bins)
    {
        switch (i)
        {
            default:
                test!("==")(hist.bins[i], 0);
                goto case;
            case 0, 11:
        }
    }

    // 1,234,567,890 (more than 65,535) Bytes: Should increment bins[$ - 1]
    // to 1, `count` to 3 and `total` to 1500 + 1,234,567,890. bins[0] and
    // bins[11] should stay at 1. All other bins should remain 0.
    hist.add(1_234_567_890);
    test!("==")(hist.total, 1_234_567_890 + 1500);
    checkBinSum(3);
    test!("==")(hist.bins[0], 1);
    test!("==")(hist.stats.from_0B, 1);
    test!("==")(hist.countFor!("from_0B"), 1);
    test!("==")(hist.bins[11], 1);
    test!("==")(hist.stats.from_1KiB, 1);
    test!("==")(hist.countFor!("from_1KiB"), 1);
    test!("==")(hist.bins[$ - 1], 1);
    test!("==")(hist.stats.from_64KiB, 1);
    test!("==")(hist.countFor!("from_64KiB"), 1);
    foreach (i, bin; hist.bins)
    {
        switch (i)
        {
            default:
                test!("==")(hist.bins[i], 0);
                goto case;
            case 0, 11, hist.bins.length - 1:
        }
    }
}
