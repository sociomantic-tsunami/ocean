/******************************************************************************

    Converts values into a metric representation with a scaled mantissa and a
    decimal exponent unit prefix character.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.text.util.MetricPrefix;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.stdc.math;




/*******************************************************************************

    Metric prefix struct.

    Usage example:

    ---

        import ocean.text.util.MetricPrefix;

        // Number to display in metric prefixed mode.
        const number = 2876873683;

        // Struct instance
        MetricPrefix metric;

        // Calculate the binary metric prefix of the number.
        metric.bin(number);

        // Output metric prefixed string (2.679297405Gb, in this case).
        Stdout.formatln("{}{}b", metric.scaled, metric.prefix);

    ---

*******************************************************************************/

public struct MetricPrefix
{
    /**************************************************************************

        Scaled mantissa; set by bin()/dec()

    **************************************************************************/

    float scaled = 0.;

    /**************************************************************************

        Metric decimal power unit prefix; set by bin()/dec()

    **************************************************************************/

    dchar prefix = ' ';

    public const BinaryPrefixes = [' ', 'K', 'M', 'G', 'T', 'P', 'E'];

    /**************************************************************************

        Converts n into a metric-like prefixed representation, using powers of
        1024.
        Example: For n == 12345678 this.scaled about 11.78 and this.prefix is
        'M'.

        Params:
            n = number to convert

        Returns:
            this instance

    **************************************************************************/

    typeof (this) bin ( T : float ) ( T n )
    {
        this.scaled = n;

        int i;

        static if (is (T : long))
        {
            for (i = 0; (n > 0x400) && (i < BinaryPrefixes.length); i++)
            {
                n >>= 10;
            }
        }
        else
        {
            frexpf(n, &i);
            i /= 10;
        }

        this.scaled = ldexpf(this.scaled, i * -10);

        this.prefix = BinaryPrefixes[i];

        return this;
    }

    public const DecimalPrefixes = [cast(wchar)'p', 'n', 'µ', 'm', ' ', 'k', 'M', 'G', 'T'];

    /**************************************************************************

        Converts n into a metric prefixed representation.
        Example: For n == 12345678 this.scaled is about 12.35 and this.prefix is
                 'M'.

        Params:
            n = number to convert
            e = input prefix: 0 = None, 1 = 'k', -1 = 'm', 2 = 'M', -2 = 'µ' etc.,
                              up to +/- 4

        Returns:
            this instance

    **************************************************************************/

    typeof (this) dec ( T : float ) ( T n, int e = 0 )
    in
    {
        assert (-5 < e && e < 5);
    }
    body
    {
        this.scaled = n;

        int i = 4;

        if (n != 0)
        {
            if (n > 1)
            {
                for (i += e; (n > 1000) && (i+1 < DecimalPrefixes.length); i++)
                {
                    n           /= 1000;
                    this.scaled /= 1000;
                }
            }
            else
            {
                for (i += e; (n < 1) && (i-1 > 0); i--)
                {
                    n           *= 1000;
                    this.scaled *= 1000;
                }
            }
        }

        this.prefix = DecimalPrefixes[i];

        return this;
    }
}



/*******************************************************************************

    Splits the given number by binary prefixes (K, M, T, etc), passing the
    prefix character, the prefix order and the count per prefix to the output
    delegate.

    Params:
        n = number to split
        output_dg = delegate which receives prefix values

    See also: BitGrouping in ocean.text.util.DigitGrouping, for a method which
    automatically formats a split binary prefix string.

    Note that if n == 0, the output delegate will not be called.

    Usage example:

    ---

        import ocean.text.util.MetricPrefix;

        // Number to split by binary prefix.
        const number = 2876873683;

        // Delegate which receives the split info.
        void split ( char prefix, uint order, ulong order_val )
        {
            Stdout.formatln("Order {}: {}{}", order, order_val, prefix);
        }

        // Perform the split.
        splitBinaryPrefix(number, &split);

    ---

*******************************************************************************/

public void splitBinaryPrefix ( ulong n, void delegate ( char prefix, uint order, ulong order_val ) output_dg )
{
    auto length = MetricPrefix.BinaryPrefixes.length;
    assert (length < int.max);
    for ( int order = cast(int) length - 1;  order >= 0; order-- )
    {
        auto shift = order * 10;

        ulong mask = 0x3ff;
        mask <<= shift;

        auto order_val = (n & mask) >> shift;

        output_dg(MetricPrefix.BinaryPrefixes[order], order, order_val);
    }
}

