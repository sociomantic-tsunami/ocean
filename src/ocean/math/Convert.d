/*******************************************************************************

    Module contains utility functions to convert floats to integer types.
    Old conversion functions eg. ocean.math.Math.rndint or
    ocean.math.Math.rndlong currently round x.5 to the nearest even integer. So
    `rndint(4.5) == 4` and `rndint(5.5) == 6`. This is undesired behaviour for some
    situations, so the functions in this module round to the nearest integer. So
    `floatToInt(4.5, output)` sets `output == 5` and `floatToInt(5.5, output)` sets
    output == 6 (this is round to nearest integer away from zero rounding see
    `http://man7.org/linux/man-pages/man3/lround.3.html` for details on the
    stdc lround, lroundf, llround, and llroundf functions).

    To check for errors the functions feclearexcept and fetestexcept are used.
    The feclearexcept(FE_ALL_EXCEPT) method is called before calling the
    mathematical function and after the mathematical function has been called
    the fetestexcept method is called to check for errors that occured in the
    mathematical function $(LPAREN)for more details in these functions see
    http://man7.org/linux/man-pages/man7/math_error.7.html$(RPAREN).

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.math.Convert;

/*******************************************************************************

    Imports

*******************************************************************************/

import core.stdc.fenv;

import core.stdc.math;

/*******************************************************************************

    Rounds a float, double, or real value to the nearest (away from zero) int
    value using lroundf.

    Params:
        input = the value to round - can be either a float, double, or real
        output = the converted value

    Returns:
        true if the conversion has succeeded (no errors)

*******************************************************************************/

public bool roundToInt ( T )( T input, out int output )
{
    feclearexcept(FE_ALL_EXCEPT);
    static if ( is(T == float) )
    {
        auto tmp = lroundf(input);
    }
    else static if ( is(T == double) )
    {
        auto tmp = lround(input);
    }
    else
    {
        static assert (is(T == real), "roundToInt(): Input argument expected to"
          ~ " be of type float, double or real, not \"" ~ T.stringof ~ "\"");
        auto tmp = lroundl(input);
    }

    if (tmp > int.max || tmp < int.min)
        return false;
    output = cast(int) tmp;
    return !fetestexcept(FE_INVALID | FE_OVERFLOW | FE_UNDERFLOW);
}


/*******************************************************************************

    Rounds a float, double, or real value to the nearest (away from zero) long
    value using llroundf.

    Params:
        input = the value to round - can be either a float, double, or real
        output = the converted value

    Returns:
        true if the conversion has succeeded (no errors)

*******************************************************************************/

public bool roundToLong ( T )( T input, out long output )
{
    feclearexcept(FE_ALL_EXCEPT);
    static if ( is(T == float) )
    {
        output = llroundf(input);
    }
    else static if ( is(T == double) )
    {
        output = llround(input);
    }
    else
    {
        static assert (is(T == real), "roundToLong(): Input argument expected to"
          ~ " be of type float, double or real, not \"" ~ T.stringof ~ "\"");
        output = lroundl(input);
    }

    return !fetestexcept(FE_INVALID | FE_OVERFLOW | FE_UNDERFLOW);
}


/*******************************************************************************

    Method to test the conversions for the float, double, or real types.

    Params:
        T = the type of input value to test the conversions for

*******************************************************************************/

private void testConversions ( T ) ( )
{
    static assert ( is(T == float) || is(T == double) || is(T == real),
        "Type " ~ T.stringof ~ " unsupported for testConversions");

    int int_result;
    long long_result;

    // Check that converting a NaN always fails
    assert(!roundToInt(T.nan, int_result), "Error converting NaN");
    assert(!roundToLong(T.nan, long_result), "Error converting NaN");

    // Check conversion of a negative number (should fail for the unsigneds)
    assert(roundToInt(cast(T)-4.2, int_result), "Error converting " ~ T.stringof);
    assert(int_result == -4, "Incorrect " ~ T.stringof ~ " conversion");

    assert(roundToLong(cast(T)-4.2, long_result), "Error converting " ~ T.stringof);
    assert(int_result == -4, "Incorrect " ~ T.stringof ~ " conversion");

    // Check conversion of x.5, should round up
    assert(roundToInt(cast(T)6.5, int_result), "Error converting " ~ T.stringof);
    assert(int_result == 7, "Incorrect " ~ T.stringof ~ " conversion");

    assert(roundToLong(cast(T)6.5, long_result), "Error converting " ~ T.stringof);
    assert(long_result == 7, "Incorrect " ~ T.stringof ~ " conversion");

    // Check conversion of x.4 should round down
    assert(roundToInt(cast(T)9.49, int_result), "Error converting " ~ T.stringof);
    assert(int_result == 9, "Incorrect " ~ T.stringof ~ " conversion");

    assert(roundToLong(cast(T)9.49, long_result), "Error converting " ~ T.stringof);
    assert(long_result == 9, "Incorrect " ~ T.stringof ~ " conversion");
}


/*******************************************************************************

    Unittest; tests the float, double, and real conversions

*******************************************************************************/

unittest
{
    testConversions!(float)();
    testConversions!(double)();
    testConversions!(real)();
}
