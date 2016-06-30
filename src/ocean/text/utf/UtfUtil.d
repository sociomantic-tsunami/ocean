/*******************************************************************************

    Contains utility functions for working with unicode strings. Contains a
    function to return the length of a UTF-8 string, a method to truncate a
    UTF-8 string to the nearest whitespace character that is less than a maximum
    length parameter, and a method to truncate a UTF-8 string and append a set
    ending to it.

    Example usage:

    ---

        char[] utf = ...; // some UTF-8 character sequence

        // using the default unicode error handler
        size_t len1 = utf8Length(utf);

        // using a custom error handler
        // which takes the index of the string as a parameter
        size_t len2 = utf8Length(utf, (size_t i){ // error handling code...  });

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.utf.UtfUtil;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.Exception_tango: onUnicodeError;

import ocean.stdc.string: memrchr;

import ocean.core.Array: append, copy;

import ocean.text.utf.c.glib_unicode;

import ocean.core.Test;

/*******************************************************************************

    This array gives the length of a UTF-8 sequence indexed by the value
    of the leading byte. An FF (ubyte.max) represents an illegal starting value
    of a UTF-8 sequence.
    FF is used instead of 0 to avoid having loops hang.

*******************************************************************************/

private const ubyte[char.max + 1] utf8_stride =
[
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,
    ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,
    ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,
    ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
    4,4,4,4,4,4,4,4,5,5,5,5,6,6,ubyte.max,ubyte.max,
];


/*******************************************************************************

    Calculates the number of UTF8 code points in a UTF8-encoded string.
    Calls the standard unicode error handler on error,
    which throws a new UnicodeException.

    Params:
        str = The string to calculate the length of.

    Returns:
        The length of the given string.

    Throws:
        UnicodeException if an invalid UTF8 code unit is detected.

*******************************************************************************/

public size_t utf8Length ( cstring str )
{
    void error ( size_t i )
    {
        onUnicodeError("invalid UTF-8 sequence", i);
    }

    return utf8Length(str, &error);
}


/*******************************************************************************

    Calculates the number of UTF8 code points in a UTF8-encoded string.
    Calls error_dg if an invalid UTF8 code unit is detected,
    which may throw an exception to abort processing.

    Params:
        str = The string to calculate the length of.
        error_dg = The error delegate to call upon finding an invalid code unit.
            Takes a size_t parameter representing the index of the current
            code point in the string.

    Returns:
        The length of the given string.

*******************************************************************************/

public size_t utf8Length ( cstring str, void delegate ( size_t ) error_dg )
{
    size_t length;
    size_t i;
    size_t stride;

    for ( i = 0; i < str.length; i += stride )
    {
        // check how much we should increment the index
        // based on the size of the current UTF8 code point
        stride = utf8_stride[str[i]];

        if ( stride == ubyte.max )
        {
            error_dg(i);
        }

        length++;
    }

    if ( i > str.length )
    {
        assert(i >= stride, "i should be stride or greater");
        i -= stride;
        assert(i < str.length, "i - stride should be less than str.length");
        error_dg(i);
    }

    return length;
}

unittest
{
    assert(utf8Length(null) == 0,
        "the length of a null string should be 0");

    assert(utf8Length("") == 0,
        "the length of an empty string should be 0");

    assert(utf8Length("foo bar baz xyzzy") == 17,
        "the length of \"foo bar baz xyzzy\" should be 17");

    assert(utf8Length("ðäß ßøø+ ì$ æ ¢ööđ µøvi€ →→→") == 28,
        "the length of \"ðäß ßøø+ ì$ æ ¢ööđ µøvi€ →→→\" should be 28");

    // test if error delegate is called for an invalid string
    bool error_caught = false;
    const istring error_str = "error in " ~ char.init ~ " the middle";
    utf8Length(error_str, ( size_t i ) { error_caught = true; });
    assert(error_caught,
        "the call to utf8Length should have caught an error");

    // test if error delegate is called for a valid string
    error_caught = false;
    const istring valid_str = "There are no errors in this string!";
    utf8Length(valid_str, ( size_t i ) { error_caught = true; });
    assert(!error_caught,
        "the call to utf8Length should not have caught an error");
}


/*******************************************************************************

    Limits str to a length of n UTF-8 code points, cutting off on the last
    space, if found. If str is not valid UTF-8, str.length is assumed to be the
    number of code points.

    Params:
        str = string to limit the length
        n = maximum number of code points in the resulting string

    Out:
        The maximum number of code points in str is n.

    Returns:
        The truncated string for method chaining

*******************************************************************************/

public mstring truncateAtWordBreak ( ref mstring str, size_t n )
out (result)
{
    if (result.length > n)
    {
        assert(g_utf8_validate(result.ptr, result.length, null));
        assert(g_utf8_strlen(result.ptr, result.length) <= n);
    }
}
body
{
    if (n < str.length)
    {
        bool valid_utf8 = g_utf8_validate(str.ptr, str.length, null);

        auto utf8_len = valid_utf8 ? utf8Length(str) : str.length;

        if (n < utf8_len)
        {
            size_t last = n;

            if (valid_utf8)
            {
                last = g_utf8_offset_to_pointer(str.ptr, last) - str.ptr;
            }

            auto c = cast (char*) memrchr(str.ptr, ' ', last);
            if (c)
            {
                // Skip consecutive ' ' characters.
                while (*c == ' ' && c > str.ptr)
                {
                    c--;
                }

                str.length = c - str.ptr + (c != str.ptr);
            }
            else
            {
                // If no ' ' is found to break on, set the break to the maximum
                // number of code points
                str.length = last;
            }
        }
    }

    return str;
}

unittest
{
    void doTest ( cstring input, cstring expected_output, int length, int line = __LINE__ )
    {
        mstring buffer;
        buffer.copy(input);
        test!("==")(truncateAtWordBreak(buffer, length), expected_output, __FILE__, line);
    }

    doTest("Hello World!", "Hello World!", "Hello World!".length);

    doTest("Hello World!", "Hello World!", "Hello World!".length + 5);

    doTest("Hello World!", "Hello", 9);

    doTest("Hällö World!", "Hällö", 9);

    doTest("äöü", "äöü", 3);

    doTest("Hello  World!", "Hello", 9);
}


/*******************************************************************************

    Truncate the length of a UTF-8 string and append a set ending. The string
    is initially truncated so that it is of maximum length n (this includes
    the extra ending paramter so the string is truncated to position
    n - ending.length).

    Params:
        str = string to truncate and append the ending to
        n = maximum number of code points in the resulting string
        ending = the ending to append to the string, defaults to "..."

    In:
        n must be at least `ending.length`

    Returns:
        The truncated and appended string for method chaining

*******************************************************************************/

public mstring truncateAppendEnding ( ref mstring str, size_t n, cstring ending = "...")
in
{
    assert (n >= ending.length);
}
body
{
    bool valid_utf8 = g_utf8_validate(str.ptr, str.length, null);

    auto utf8_len = valid_utf8 ? utf8Length(str) : str.length;

    if (n < utf8_len)
    {
        truncateAtWordBreak(str, (n - ending.length));
        str.append(ending);
    }

    return str;
}

unittest
{
    mstring buffer;

    void doTest ( cstring input, cstring expected_output, int length,
        cstring ending = "..." , int line = __LINE__ )
    {
        buffer.copy(input);
        test!("==")(truncateAppendEnding(buffer, length, ending),
            expected_output, __FILE__, line);
    }

    doTest("Hello World!", "Hello World!", "Hello World!".length);

    doTest("Hello World!", "Hello World!", "Hello World!".length + 5);

    doTest("Hello World!", "Hello...", 9);

    doTest("Hällö World!", "Hällö...", 9);

    doTest("äöü äöü", "ä...", 4);

    doTest("Hello  World!", "Hello...", 9);

    doTest("HelloW"  ~ cast (char) 0x81 ~ "rld!",
        "HelloW"  ~ cast (char) 0x81 ~ "...", 10);

    doTest("HelloWörld!", "HelloWörl+", 10, "+");

    doTest("Designstarker Couchtisch in hochwertiger Holznachbildung. Mit "
        "praktischem Ablagebogen in Kernnussbaumfarben oder Schwarz. "
        "Winkelfüße mit Alukante. B", "Designstarker Couchtisch in hochwertiger"
        " Holznachbildung. Mit praktischem Ablagebogen...", 90);
}
