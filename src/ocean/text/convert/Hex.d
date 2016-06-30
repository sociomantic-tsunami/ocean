/*******************************************************************************

    Utility functions for converting hexadecimal strings.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.convert.Hex;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import Integer = ocean.text.convert.Integer_tango;

import ocean.core.TypeConvert;

version (UnitTest)
{
    import ocean.core.Test;
}

/*******************************************************************************

    Checks whether str is a hex string (contains only valid hex digits),
    optionally with radix specifier ("0x").

    Params:
        str = string to check
        allow_radix = if true, the radix specified "0x" is allowed at the start
            of str

    Returns:
        true if str is a hex string

*******************************************************************************/

public bool isHex ( cstring str, bool allow_radix = false )
{
    return handleRadix(str, allow_radix,
        ( cstring str )
        {
            foreach ( c; str )
            {
                if ( !isHex(c) )
                {
                    return false;
                }
            }
            return true;
        });
}

unittest
{
    // empty string
    test!("==")(isHex(""), true);

    // radix only, allowed
    test!("==")(isHex("0x", true), true);

    // radix only, disallowed
    test!("==")(isHex("0x"), false);

    // non-hex
    test!("==")(isHex("zzz"), false);

    // simple hex
    test!("==")(isHex("1234567890abcdef"), true);

    // simple hex, upper case
    test!("==")(isHex("1234567890ABCDEF"), true);

    // simple hex with radix, allowed
    test!("==")(isHex("0x1234567890abcdef", true), true);

    // simple hex with radix, disallowed
    test!("==")(isHex("0x1234567890abcdef"), false);
}


/*******************************************************************************

    Checks whether a character is a valid hexadecimal digit.

    Params:
        c = character to check

    Returns:
        true if the character is a valid hex digit, false otherwise

*******************************************************************************/

public bool isHex ( char c )
{
    return (c >= '0' && c <= '9')
        || (c >= 'a' && c <= 'f')
        || (c >= 'A' && c <= 'F');
}

unittest
{
    bool contains ( cstring str, char c )
    {
        foreach ( cc; str )
        {
            if ( cc == c )
            {
                return true;
            }
        }
        return false;
    }

    istring good = "0123456789abcdefABCDEF";

    for ( int i = char.min; i <= char.max; i++ )
    {
        // can't use char for i because of expected overflow
        auto c = castFrom!(int).to!(char)(i);
        if ( contains(good, c) )
        {
            test!("==")(isHex(c), true);
        }
        else
        {
            test!("==")(!isHex(c), true);
        }
    }
}


/*******************************************************************************

    Converts any characters in the range A..F in a hex string to lower case
    (a..f).

    Params:
        str = string to convert

    Returns:
        converted string (characters modified in-place)

*******************************************************************************/

public mstring hexToLower ( mstring str )
{
    const to_lower = ('A' - 'a');
    foreach ( ref c; str )
    {
        if ( c >= 'A' && c <= 'F' )
        {
            c -= to_lower;
        }
    }

    return str;
}

unittest
{
    // empty string
    test!("==")(hexToLower(null), "");

    // numbers only
    test!("==")(hexToLower("123456678".dup), "123456678");

    // lower case letters
    test!("==")(hexToLower("abcdef".dup), "abcdef");

    // upper case letters
    test!("==")(hexToLower("ABCDEF".dup), "abcdef");

    // non-hex letters, lower case
    test!("==")(hexToLower("uvwxyz".dup), "uvwxyz");

    // non-hex letters, upper case
    test!("==")(hexToLower("UVWXYZ".dup), "UVWXYZ");

    // mixed
    test!("==")(hexToLower("12345678abcdefABCDEFUVWXYZ".dup), "12345678abcdefabcdefUVWXYZ");

    // check that string is modified in-place
    mstring str = "ABCDEF".dup;
    auto converted = hexToLower(str);
    test!("==")(converted.ptr, str.ptr);
}


/*******************************************************************************

    Checks whether the radix in str (if present) matches the allow_radix flag,
    and passes the radix-stripped string to the provided delegate.

    Params:
        str = string to convert
        allow_radix = if true, the radix specified "0x" is allowed at the start
            of str
        process = process to perform on string if radix is as expected

    Returns:
        if str starts with "0x" and allow_radix is false, returns false
        otherwise, passes on the return value of the process delegate

*******************************************************************************/

package bool handleRadix ( cstring str, bool allow_radix,
    bool delegate ( cstring ) process )
{
    if ( str.length >= 2 && str[0..2] == "0x" )
    {
        if ( !allow_radix )
        {
            return false;
        }
        else
        {
            str = str[2..$];
        }
    }

    return process(str);
}


/*********************************************************************

    Convert a string of hex digits to a byte array. This is only useful
    for RT strings. If one needs to do this with literals, x"FF FF" is
    a better approach.

    Params:
        str = the string of hex digits to be converted
        buf = a byte array where the values will be stored

    Returns:
        true if conversion succeeded, false if the length of the
        string is odd, or any of the characters is not valid hex digit.

 *********************************************************************/

public bool hexToBin (cstring str, ref ubyte[] buf)
{
    static uint digit_for_character (char c)
    {
        if ( c >= '0' && c <= '9' )
              return c - '0';
        else if ( c >= 'a' && c <= 'f' )
              return c - 'a' + 10;
        else if ( c >= 'A' && c <= 'F' )
              return c - 'A' + 10;

        // c is guaranteed to be a valid hex string
        // by the caller
        assert (false);
    }

    if (str.length % 2 != 0)
    {
        return false;
    }

    if (!isHex(str))
    {
        return false;
    }

    buf.length = str.length / 2;

    foreach (i, ref b; buf)
    {
        auto j = i * 2;

        b = cast(ubyte)(((digit_for_character(str[j]) & 0x0F) << 4) |
                       (digit_for_character(str[j + 1]) & 0x0F));
    }

    return true;
}

unittest
{
    ubyte[] arr;
    test!("==")(hexToBin("FFFF", arr), true);
    test!("==")(arr, cast(ubyte[])[255, 255]);
    arr.length = 0;
    enableStomping(arr);

    test!("==")(hexToBin("0000", arr), true);
    test!("==")(arr, cast(ubyte[])[0, 0]);
    arr.length = 0;
    enableStomping(arr);

    test!("==")(hexToBin("", arr), true);
    test!("==")(arr, cast(ubyte[])[]);
    arr.length = 0;
    enableStomping(arr);

    test!("==")(hexToBin("FFF", arr), false);
    arr.length = 0;
    enableStomping(arr);

    test!("==")(hexToBin("(FFF", arr), false);
    arr.length = 0;
    enableStomping(arr);
}
