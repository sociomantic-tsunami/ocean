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

import ocean.math.IEEE: isNaN;

import ocean.text.Unicode : isSpace;

import ocean.text.utf.c.glib_unicode;

import ocean.core.Test;


/*******************************************************************************

    UTF-8 representation of "…".

*******************************************************************************/

public istring ellipsis = "\xE2\x80\xA6";  // The char '…'


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
      ~ "praktischem Ablagebogen in Kernnussbaumfarben oder Schwarz. "
      ~ "Winkelfüße mit Alukante. B", "Designstarker Couchtisch in hochwertiger"
      ~ " Holznachbildung. Mit praktischem Ablagebogen...", 90);
}


/*******************************************************************************

    Limits the length of a UTF-8 string, to at most the specified number of
    bytes.

    This is conceptually equal to str[0..max_len], except that we take care to
    avoid chopping a multi-byte UTF-8 character in half.

    Params:
        str     = the string to be sliced
        max_len = the maximum allowable length (in bytes) of the string

    Returns:
        a slice of the original string, of length at most max_len.

*******************************************************************************/

public Inout!(mstring) limitStringLength ( Inout!(mstring) str, size_t max_len )
{
    if ( str.length <= max_len )
    {
        return str;
    }

    // Make sure we don't chop a character in half.
    // All UTF-8 continuation bytes are of the form 0b10xxxxxxx,
    // so we must skip all such bytes

    auto k = max_len;

    while ( k != 0 && ( (str[k] & 0xC0 ) ==  0x80) )
    {
        --k;
    }

    return str[ 0 .. k ];

}


unittest
{
    // String ending with a 1-byte character

    test!("==")(limitStringLength("abc", 5), "abc");
    test!("==")(limitStringLength("abc", 2), "ab");

    // String ending with a 2-byte character

    test!("==")(limitStringLength("ÜÄ", 5), "ÜÄ");
    test!("==")(limitStringLength("ÜÄ", 4), "ÜÄ");
    test!("==")(limitStringLength("ÜÄ", 3), "Ü");
    test!("==")(limitStringLength("ÜÄ", 2), "Ü");
    test!("==")(limitStringLength("ÜÄ", 1), "");

    // String ending with a 3-byte character

    test!("==")(limitStringLength("Ü眼", 6), "Ü眼");
    test!("==")(limitStringLength("Ü眼", 5), "Ü眼");
    test!("==")(limitStringLength("Ü眼", 4), "Ü");

    // Ensure it compiles with an mstring

    mstring x = "abcd".dup;
    mstring y = limitStringLength(x, 2);
}


/*******************************************************************************

    Truncates a string at the last space before the n-th Unicode character or,
    if the resulting string is too short, at the n-th Unicode character.
    The string should be a valid UTF-8 (the caller should have validated it
    before calling this function).

    If a string is truncated before the end, then the final Unicode chartacter
    is made an ending. Trailing space is removed before the ending is added.
    The returned string will always be no more than n Unicode characters
    (including the ending).

    The basic algorithm is to walk through src keeping track of how many
    bytes needed to be sliced at any particular time until we know when
    we need to end. Because we don't know till the end if we need an
    ending we need to keep track of one Unicode character behind as well as the
    position of the Unicode character berore the last space. We have to be
    careful we never point at spaces.

    Important points when reading the algorithm:

    1) Unicode character != byte
    2) i == the number of bytes required to include the _previous_
        Unicode character (i.e. the number of bytes to the start of c)

    Params:
        src        = the string to truncate (must be UTF-8 encoded)
        n          = the maximum number of Unicode characters allowed in the
                     returned string
        buffer     = a buffer to be used to store the result in (may be
                     resized). The buffer is required because "ending" may
                     contain Unicode characters taking more bytes than the
                     Unicode characters in src they replace, thus leading to a
                     string with fewer Unicode characters but more bytes.
        ending     = These Unicode characters will be appended when "src" needs
                     to be truncated.
        fill_ratio = if cutting the string in the last space would make its
                     Unicode character length smaller than "n*fill_ratio",
                     then we cut it on the n-th Unicode character

    Returns:
        buffer

*******************************************************************************/

public mstring truncateAtN(cstring src, size_t n, ref mstring buffer,
    cstring ending = ellipsis, float fill_ratio = 0.75)
in
{
    size_t ending_length = 0;   // Ending's number of Unicode characters
    foreach ( dchar c; ending )
    {
        ++ending_length;
    }

    assert(n > ending_length);

    assert(!isNaN(fill_ratio));
    assert(fill_ratio>=0 && fill_ratio<=1);
}
out (result)
{
    size_t result_length = 0;
    foreach ( dchar c; result )
    {
        ++result_length;
    }

    assert(result_length <= n);
}
body
{
    size_t ending_length = 0;   // Ending's number of Unicode characters
    foreach ( size_t i, dchar c; ending )
    {
        ++ending_length;
    }

    size_t net_length = n - ending_length;  // The maximum number of Unicode
                                            // characters that can be kept, if
                                            // ending is used.

    size_t code_point_count;    // Which Unicode character are we up to.
    size_t bytes_needed = 0;    // Number of bytes needed to include the last
                                // valid looking Unicode character.
    size_t last_space_bytes_net = 0; // Number of bytes needed to include the
                                     // last valid Unicode character which is
                                     // before the last known space, if ending
                                     // is used.
    size_t last_space_code_points_net = 0; // The number of Unicode characters
                                     // that precede the last space, if ending
                                     // is used.
    size_t last_space_bytes_n = 0;   // Number of bytes needed to include the
                                     // last valid Unicode character which is
                                     // before the last known space, if ending
                                     // is not used.
    size_t last_space_code_points_n = 0; // The number of Unicode characters
                                     // that precede the last space, if ending
                                     // is not used.
    bool need_ending;       // Do we know we need an ending already?
    bool last_was_space;    // Was the previous character a space?

    foreach ( size_t i, dchar c; src )
    {
        bool curr_is_space = isSpace(c);

        // Keep Unicode characters that will be returned if the ending is used.
        if ( code_point_count <= net_length )
        {
            // We still need more Unicode characters so we update the counters.
            // In the edge case (code_point_count == net_length), the
            // current Unicode character is not needed. However, we need its "i"
            // in order to find the bytes of the string which includes the
            // previous Unicode character.
            if ( ! last_was_space )
            {
                bytes_needed = i;

                if ( curr_is_space )
                {
                    // If the current Unicode character is a space, the previous
                    // is not a space and we are not at the end, keep its
                    // position.
                    last_space_bytes_net = i;
                    last_space_code_points_net = code_point_count;
                }
            }
        }

        // Keep Unicode characters that will be returned if the ending is not
        // used.
        if ( code_point_count <= n
            && ! last_was_space
            && curr_is_space )
        {
            // Use "n" instead of "net_length".
            last_space_bytes_n = i;
            last_space_code_points_n = code_point_count;
        }

        last_was_space = curr_is_space;

        // This Unicode character will be truncated, but we need to check if it
        // is a space character. If the Unicode characters that we ommit are
        // spaces, we will not append the ending, we will just remove the spaces.
        if ( code_point_count >= n )
        {
            if ( ! curr_is_space )
            {
                // This is a non-space Unicode character so we are truncating.
                need_ending = true;
                break;
            }
        }

        // Track which Unicode character we are up to (as opposed to byte)
        ++code_point_count;
    }

    // We may have fallen off the end of src before we had time to set up all
    // our variables. If need_ending is true though we know that isn't the case.
    if ( need_ending )
    {
        // Check if there is a long enough string before the last space.
        if ( last_space_bytes_net
            && (last_space_code_points_net / (cast(float)n) > fill_ratio) )
        {
            bytes_needed = last_space_bytes_net;
        }
        // Copy up to the prev positon, which may be the 2nd last Unicode
        // character or the Unicode character before the last space.
        enableStomping(buffer);
        buffer.length = bytes_needed + ending.length;
        enableStomping(buffer);
        buffer[0 .. bytes_needed] = src[0 .. bytes_needed];
        // And append an ending
        buffer[bytes_needed .. bytes_needed + ending.length] = ending[];
    }
    else
    {
        // We need to check if we finished one or more iterations short
        if ( code_point_count <= n )
        {
            // We did so src is short and if there is no trailing space
            // we can just use it as is. If there was trailing space then
            // "last_space_bytes" will have already been set correctly on the
            // iteration caused by the space
            if ( ! last_was_space )
            {
                last_space_bytes_n = src.length;
            }
        }
        // No need to append the ending so use the full string we found
        enableStomping(buffer);
        buffer.length = last_space_bytes_n;
        enableStomping(buffer);
        buffer[] = src[0 .. last_space_bytes_n];
    }
    return(buffer);
}

unittest
{
    auto t = new NamedTest(
        "truncateAtN"
    );

    mstring buffer;

    // Old test
    foreach (i, char c; "…")
    {
        t.test!("==")(ellipsis[i], c);
    }

    istring str = "Hello World!";
    t.test!("==")(str.truncateAtN(str.length, buffer), "Hello World!");
    t.test!("==")(str.truncateAtN(str.length + 5, buffer), "Hello World!");
    t.test!("==")(str.truncateAtN(10, buffer), "Hello Wor" ~ ellipsis);

    t.test!("==")("Hällö World!"c.truncateAtN(10, buffer),
        "Hällö Wor"c ~ ellipsis);
    t.test!("==")("äöü"c.truncateAtN(3, buffer), "äöü"c);
    t.test!("==")("Hello  World!".dup.truncateAtN(10, buffer),
        "Hello  Wo" ~ ellipsis);
    t.test!("==")("HelloWörld!"c.truncateAtN(10, buffer, "+"), "HelloWörl+"c);
    t.test!("==")(
        "Designstarker Couchtisch in hochwertiger Holznachbildung. Mit praktischem Ablagebogen in Kernnussbaumfarben oder Schwarz. Winkelfüße mit Alukante. B"c.truncateAtN(100, buffer),
        "Designstarker Couchtisch in hochwertiger Holznachbildung. Mit praktischem Ablagebogen in"c ~ ellipsis
    );

    // Andrew's tests

    t.test!("==")(("This should be the longest string of all the unit tests.\n"
      ~ "We do this so that the buffer never needs expanding again.\n"
      ~ "This way we can check for unnecessary allocations.")
        .truncateAtN(160, buffer),
        "This should be the longest string of all the unit tests.\n"
      ~ "We do this so that the buffer never needs expanding again.\n"
      ~ "This way we can check for unnecessary…"
    );

    typeof(buffer.ptr) orig_ptr = buffer.ptr;

    t.test!("==")("     ".truncateAtN(2, buffer), "");
    t.test!("==")("12   ".truncateAtN(4, buffer), "12");
    t.test!("==")("12   ".truncateAtN(6, buffer), "12");
    t.test!("==")("hello".truncateAtN(2, buffer), "h…");
    t.test!("==")("hello".truncateAtN(4, buffer), "hel…");
    t.test!("==")("hello".truncateAtN(5, buffer), "hello");
    t.test!("==")("hello".truncateAtN(6, buffer), "hello");
    t.test!("==")("hello".truncateAtN(10, buffer), "hello");
    t.test!("==")("h l o".truncateAtN(5, buffer), "h l o");
    t.test!("==")("hello ".truncateAtN(5, buffer), "hello");
    t.test!("==")("hello ".truncateAtN(6, buffer), "hello");
    t.test!("==")("hello ".truncateAtN(7, buffer), "hello");
    t.test!("==")("hello ".truncateAtN(10, buffer), "hello");
    t.test!("==")("hello   world".truncateAtN(8, buffer), "hello…");
    t.test!("==")("hello | world".truncateAtN(7, buffer), "hello…");
    t.test!("==")("hello | world".truncateAtN(8, buffer), "hello |…");
    t.test!("==")("hello | world".truncateAtN(32, buffer), "hello | world");
    t.test!("==")("h llo world".truncateAtN(3, buffer), "h…");
    t.test!("==")("he  ll  o  world".truncateAtN(9, buffer), "he  ll…");
    t.test!("==")("he  ll  o  world".truncateAtN(10, buffer), "he  ll  o…");
    t.test!("==")("he  ll  o  world".truncateAtN(32, buffer),
        "he  ll  o  world");

    t.test!("==")("a".truncateAtN(4, buffer), "a");
    t.test!("==")("ab".truncateAtN(4, buffer), "ab");
    t.test!("==")("a|".truncateAtN(4, buffer), "a|");
    t.test!("==")("ab|".truncateAtN(4, buffer), "ab|");
    t.test!("==")("ab|d".truncateAtN(4, buffer), "ab|d");
    t.test!("==")("abc|".truncateAtN(4, buffer), "abc|");
    t.test!("==")("abcd| ".truncateAtN(4, buffer), "abc…");
    t.test!("==")("a| d".truncateAtN(4, buffer), "a| d");

    t.test!("==")("По оживлённым берегам"c.truncateAtN(2, buffer), "П…"c);
    t.test!("==")("По оживлённым берегам"c.truncateAtN(3, buffer), "По…"c);
    t.test!("==")("По оживлённым берегам"c.truncateAtN(4, buffer), "По…"c);
    t.test!("==")("По оживлённым берегам"c.truncateAtN(5, buffer), "По о…"c);
    t.test!("==")("Ἰοὺ ἰού· τὰ πάντʼ ἂν ἐξήκοι σαφῆ."c.truncateAtN(2, buffer),
        "Ἰ…"c);
    t.test!("==")("Ἰοὺ ἰού· τὰ πάντʼ ἂν ἐξήκοι σαφῆ."c.truncateAtN(3, buffer),
        "Ἰο…"c);
    t.test!("==")("Ἰοὺ ἰού· τὰ πάντʼ ἂν ἐξήκοι σαφῆ."c.truncateAtN(4, buffer),
        "Ἰοὺ…"c);
    t.test!("==")("Ἰοὺ ἰού· τὰ πάντʼ ἂν ἐξήκοι σαφῆ."c.truncateAtN(5, buffer),
        "Ἰοὺ…"c);
    t.test!("==")("Ἰοὺ ἰού· τὰ πάντʼ ἂν ἐξήκοι σαφῆ."c.truncateAtN(6, buffer),
        "Ἰοὺ ἰ…"c);
    t.test!("==")("Ξεσκεπάζω τὴν ψυχοφθόρα βδελυγμία"c.truncateAtN(256, buffer),
        "Ξεσκεπάζω τὴν ψυχοφθόρα βδελυγμία"c);
    t.test!("==")("पशुपतिरपि तान्यहानि कृच्छ्राद्"c.truncateAtN(6,buffer), "पशुपत…"c); // NB शु is 2 chars
    t.test!("==")("पशुपतिरपि तान्यहानि कृच्छ्राद्"c.truncateAtN(8, buffer), "पशुपतिर…"c);
    t.test!("==")("子曰：「學而時習之，不亦說乎？有朋自遠方來，不亦樂乎？"c.truncateAtN(5, buffer), "子曰：「…"c);

    // we don't yet support R-To-L languages so don't test Arabic
    //test(truncate_at_n("بِسْمِ ٱللّٰهِ ٱلرَّحْمـَبنِ ٱلرَّحِيمِ", 5c, buffer) = "…رَّحِيمِ"c);

    // Use some other ending that is not one character.
    t.test!("==")("a| d".truncateAtN(4, buffer, "..."), "a| d");
    t.test!("==")("a| d1".truncateAtN(4, buffer, "..."), "a...");
    t.test!("==")("1234567890".truncateAtN(7, buffer, "..."), "1234...");
    t.test!("==")("1234567890".truncateAtN(70, buffer, "..."), "1234567890");
    t.test!("==")("1234 6789 1234 6789 1234 6789".truncateAtN(25, buffer, "..."),
        "1234 6789 1234 6789...");

    // check nothing has allocated
    t.test!("==")(orig_ptr, buffer.ptr);
}
