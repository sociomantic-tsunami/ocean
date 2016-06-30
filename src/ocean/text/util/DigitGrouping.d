/*******************************************************************************

    Functions for generating thousands separated string representations of a
    number.

    Usage:

    ---

        import ocean.text.util.DigitGrouping;

        // Number to convert
        const number = 12345678;

        // Generating a thousands separated string.
        char[] number_as_string;
        DigitGrouping.format(number, number_as_string);

        // Checking how many characters would be required for a thousands
        // separated number.
        cont max_len = 10;
        assert(DigitGrouping.length(number) <= max_len);

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.util.DigitGrouping;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.TypeConvert;

import ocean.core.Array;

import ocean.text.util.MetricPrefix;

import ocean.core.Traits;

import ocean.text.convert.Format;



/*******************************************************************************

    Digit grouping class -- just a container for static functions.

*******************************************************************************/

public class DigitGrouping
{
    private alias typeof(this) This;


    /***************************************************************************

        Calculates the number of characters in the string representation of a
        thousands separated number.

        Note: this method is faster than generating the string then checking its
        .length property.

        Template_Params:
            T = type of number

        Params:
            num = number to work out length of

        Returns:
            number of characters in the string representation of the thousands
            separated number

    ***************************************************************************/

    public static size_t length ( T ) ( T num )
    {
        static assert(isIntegerType!(T), This.stringof ~ ".length - only works with integer types");

        bool negative = num < 0;
        if ( negative ) num = -num;

        // Calculate the number of digits in the number.
        size_t len = 1; // every number has at least 1 digit
        do
        {
            num /= 10;
            if ( num > 0 )
            {
                len++;
            }
        }
        while ( num > 0);

        // Extra characters for any thousands separating commas required.
        if ( len > 3 )
        {
            len += (len - 1) / 3;
        }

        // An extra character for a minus sign.
        if ( negative ) len++;

        return len;
    }


    /***************************************************************************

        Formats a number to a string, with comma separation every 3 digits

        Template_Params:
            T = type of number

        Params:
            num = number to be formatted
            output = string in which to store the formatted number

        Returns:
            formatted string

    ***************************************************************************/

    public static mstring format ( T ) ( T num, ref mstring output )
    {
        static assert(isIntegerType!(T), This.stringof ~ ".format - only works with integer types");

        output.length = 0;

        char[20] string_buf; // 20 characters is enough to store ulong.max
        size_t layout_pos;

        size_t layoutSink ( cstring s )
        {
            string_buf[layout_pos .. layout_pos + s.length] = s[];
            layout_pos += s.length;
            return s.length;
        }

        // Format number into a string
        Format.convert(&layoutSink, "{}", num);
        mstring num_as_string = string_buf[0.. layout_pos];

        bool comma;
        size_t left = 0;
        size_t right = left + 3;
        size_t first_comma;

        // Handle negative numbers
        if ( num_as_string[0] == '-' )
        {
            output.append("-"[]);
            num_as_string = num_as_string[1..$];
        }

        // Find position of first comma
        if ( num_as_string.length > 3 )
        {
            comma = true;
            first_comma = num_as_string.length % 3;

            if ( first_comma > 0 )
            {
                right = first_comma;
            }
        }

        // Copy chunks of the formatted number into the destination string, with commas
        do
        {
            if ( right >= num_as_string.length )
            {
                right = num_as_string.length;
                comma = false;
            }

            mstring digits = num_as_string[left..right];
            if ( comma )
            {
                output.append(digits, ","[]);
            }
            else
            {
                output.append(digits);
            }

            left = right;
            right = left + 3;
        }
        while( left < num_as_string.length );

        return output;
    }
}

version ( UnitTest )
{
    import ocean.core.Test : test;
}

unittest
{
    test!("==")(DigitGrouping.length(-100000),  "-100,000".length);
    test!("==")(DigitGrouping.length( -10000),   "-10,000".length);
    test!("==")(DigitGrouping.length(  -1000),    "-1,000".length);
    test!("==")(DigitGrouping.length(   -100),      "-100".length);
    test!("==")(DigitGrouping.length(    -10),       "-10".length);
    test!("==")(DigitGrouping.length(     -0),         "0".length);
    test!("==")(DigitGrouping.length(      0),         "0".length);
    test!("==")(DigitGrouping.length(     10),        "10".length);
    test!("==")(DigitGrouping.length(    100),       "100".length);
    test!("==")(DigitGrouping.length(   1000),     "1,000".length);
    test!("==")(DigitGrouping.length(  10000),    "10,000".length);
    test!("==")(DigitGrouping.length( 100000),   "100,000".length);
    test!("==")(DigitGrouping.length(1000000), "1,000,000".length);

    mstring buf;

    test!("==")(DigitGrouping.format(-100000, buf),  "-100,000"[]);
    test!("==")(DigitGrouping.format( -10000, buf),   "-10,000"[]);
    test!("==")(DigitGrouping.format(  -1000, buf),    "-1,000"[]);
    test!("==")(DigitGrouping.format(   -100, buf),      "-100"[]);
    test!("==")(DigitGrouping.format(    -10, buf),       "-10"[]);
    test!("==")(DigitGrouping.format(     -0, buf),         "0"[]);
    test!("==")(DigitGrouping.format(      0, buf),         "0"[]);
    test!("==")(DigitGrouping.format(     10, buf),        "10"[]);
    test!("==")(DigitGrouping.format(    100, buf),       "100"[]);
    test!("==")(DigitGrouping.format(   1000, buf),     "1,000"[]);
    test!("==")(DigitGrouping.format(  10000, buf),    "10,000"[]);
    test!("==")(DigitGrouping.format( 100000, buf),   "100,000"[]);
    test!("==")(DigitGrouping.format(1000000, buf), "1,000,000"[]);
}



/*******************************************************************************

    Binary digit grouping class -- just a container for static functions.

*******************************************************************************/

public class BitGrouping
{
    /***************************************************************************

        Formats a number to a string, with binary prefix (K, M, T, etc) every
        10 bits.

        Params:
            num = number to be formatted
            output = string in which to store the formatted number
            unit = string, describing the type of unit represented by the
                number, to be appended after each binary prefix

        Returns:
            formatted string

    ***************************************************************************/

    public static mstring format ( ulong num, ref mstring output, cstring unit = null )
    {
        output.length = 0;
        enableStomping(output);

        if ( num == 0 )
        {
            Format.format(output, "0{}", unit);
        }
        else
        {
            void format ( char prefix, uint order, ulong order_val )
            {
                if ( order_val > 0 )
                {
                    if ( order == 0 )
                    {
                        Format.format(output, "{}{}", order_val, unit);
                    }
                    else
                    {
                        Format.format(output, "{}{}{} ", order_val, prefix, unit);
                    }
                }
                else if ( order_val == 0 && order == 0 )
                {
                    // Get rid of the additional space that was appended.

                    output = output[0 .. $ - 1];
                }
            }

            splitBinaryPrefix(num, &format);
        }

        return output;
    }
}

unittest
{
    mstring buf;

    test!("==")(BitGrouping.format(0, buf), "0"[]);
    test!("==")(BitGrouping.format(0, buf, "X"), "0X"[]);

    test!("==")(BitGrouping.format(1000, buf), "1000"[]);
    test!("==")(BitGrouping.format(1000, buf, "X"), "1000X"[]);

    test!("==")(BitGrouping.format(1024, buf), "1K"[]);
    test!("==")(BitGrouping.format(1024, buf, "M"), "1KM"[]);

    test!("==")(BitGrouping.format(1025, buf), "1K 1"[]);
    test!("==")(BitGrouping.format(1025, buf, "TEST"), "1KTEST 1TEST"[]);

    test!("==")(BitGrouping.format(10000, buf), "9K 784"[]);
    test!("==")(BitGrouping.format(10000, buf, "X"), "9KX 784X"[]);

    test!("==")(BitGrouping.format(1000000, buf), "976K 576"[]);
    test!("==")(BitGrouping.format(1000000, buf, "X"), "976KX 576X"[]);

    test!("==")(BitGrouping.format(10000000, buf), "9M 549K 640"[]);
    test!("==")(BitGrouping.format(10000000, buf, "X"), "9MX 549KX 640X"[]);

    test!("==")(BitGrouping.format(10000000000, buf), "9G 320M 761K"[]);
    test!("==")(BitGrouping.format(10000000000, buf, "X"), "9GX 320MX 761KX"[]);
}

