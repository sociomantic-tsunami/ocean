/******************************************************************************

    C string and character tool functions

    C string and character tool functions and null terminator utilities

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.text.util.StringSearch;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.transition;

import c_stddef = ocean.stdc.stddef: wchar_t;
import c_wctype = ocean.stdc.wctype;
import c_ctype  = ocean.stdc.ctype;
import c_string = ocean.stdc.string;

import ocean.math.Math:   min;

version (UnitTest)
{
    import ocean.core.Test;
}


/++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    /**************************************************************************

        Descriptions for public alias methods

     **************************************************************************/

    /**
     * Returns the length of "str" without null terminator.
     *
     * Params:
     *      str = string (must be null terminated)
     *
     * Returns:
     *      length of "str" without null terminator
     */
    size_t lengthOf ( Char* str );


    /**
     * Tells whether "chr" is
     *  isCntrl -- a control character or
     *  isSpace -- whitespace or
     *  isGraph -- a character associated with a graph or
     *  isPrint -- printable or
     *  isAlpha -- a letter or
     *  isLower -- a lower case letter or
     *  isUpper -- an upper case letter or
     *  isAlNum -- a letter or a decimal digit or
     *  isDigit -- a decimalt digit or
     *  isHexDigit -- a hexadecimal digit.
     *
     * Params:
     *      chr = character to identify
     * Returns:
     *      true if the character is of the specified class or false otherwise
     */
    bool isCntrl ( Char chr );
    bool isSpace ( Char chr );

    bool isGraph ( Char chr );
    bool isPrint ( Char chr );
    bool isPunct ( Char chr );

    bool isAlpha ( Char chr );
    bool isAlNum ( Char chr );
    bool isDigit ( Char chr );
    bool isHexDigit ( Char chr );


    bool isLower ( Char chr );
    bool isUpper ( Char chr );


    /**
     * Converts "chr"
     *  toLower -- to lower case or
     *  toUpper -- to upper case.
     *
     * Params:
     *      chr = character to convert
     *
     * Returns:
     *      converted character
     */
    Char toLower ( Char chr );
    Char toUpper ( Char chr );


    /**************************************************************************

        Explanations for private alias methods

     **************************************************************************/

    /**
     * Returns the index of the first occurrence of one of the characters in
     * "charset" in "str".
     *
     * Params:
     *     str =     string to scan for characters in "charset"
     *     charset = search character set
     * Returns:
     */
    size_t pLocateFirstInSet ( Char* str, Char* charset );


    /**
     * Returns a pointer to the first occurrence of "pattern" in "str".
     *
     * Params:
     *     str = string to scan for "pattern"
     *     pattern = search pattern
     * Returns:
     */
    Char* pLocatePattern ( Char* str, Char* pattern );


    /**
     * Moves src[0 .. n] to dst[0 .. n]. "src" and "dst" may overlap.
     *
     * Params:
     *     dst = pointer to destination
     *     src = pointer to source
     *     n   = number of elements to move
     * Returns:
     */
    Char* pMemMove ( Char* dst, Char* src, size_t n );


    /**
     * Returns a pointer to the first occurrence of "chr" within the first "n"
     * elements of "str".
     *
     * Params:
     *     str = string to scan for "chr"
     *     chr = search character
     *     n =   number of characters to scan for "chr"
     * Returns:
     */
    Char* pLocateBinChar ( Char* str, Char chr, size_t n );


 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++/

/******************************************************************************

    StringSearch structure

 ******************************************************************************/

struct StringSearch ( bool wide_char = false )
{
    alias c_stddef.wchar_t WcharT;

    static if (wide_char)
    {
        alias WcharT            Char;

        alias c_wctype.iswcntrl  isCntrl;
        alias c_wctype.iswspace  isSpace;

        alias c_wctype.iswgraph  isGraph;
        alias c_wctype.iswprint  isPrint;
        alias c_wctype.iswpunct  isPunct;

        alias c_wctype.iswalpha  isAlpha;
        alias c_wctype.iswalnum  isAlNum;
        alias c_wctype.iswdigit  isDigit;
        alias c_wctype.iswxdigit isHexDigit;

        alias c_wctype.iswlower  isLower;
        alias c_wctype.iswupper  isUpper;

        alias c_wctype.towlower  toLower;
        alias c_wctype.towupper  toUpper;

        alias c_string.wcslen    lengthOf;

        alias c_string.wmemchr   pLocateBinChar;

        alias c_string.wcsstr    pLocatePattern;
        alias c_string.wmemmove  pMemMove;
        alias c_string.wcscspn   pLocateFirstInSet;

        alias c_string.wcstok    pSplit;
    }
    else
    {
        alias char              Char;

        alias c_ctype.iscntrl    isCntrl;
        alias c_ctype.isspace    isSpace;

        alias c_ctype.isgraph    isGraph;
        alias c_ctype.isprint    isPrint;
        alias c_ctype.ispunct    isPunct;

        alias c_ctype.isalpha    isAlpha;
        alias c_ctype.isalnum    isAlNum;
        alias c_ctype.isdigit    isDigit;
        alias c_ctype.isxdigit   isHexDigit;

        alias c_ctype.islower    isLower;
        alias c_ctype.isupper    isUpper;

        alias c_ctype.tolower    toLower;
        alias c_ctype.toupper    toUpper;

        alias c_string.strlen    lengthOf;

        alias c_string.memchr    pLocateBinChar;

        alias c_string.strstr    pLocatePattern;
        alias c_string.memmove   pMemMove;
        alias c_string.strcspn   pLocateFirstInSet;

        alias c_string.strtok    pSplit;

    }

    static:

    const Char TERM = '\0';

    /**
     * Locates the first occurence of value within the first length characters
     * of str. If greater, length is truncated to the length of str.
     *
     * Params:
     *      str    = string to search for value
     *      value  = element value to find
     *      start  = start index
     *      length = number of elements to examine
     *
     * Returns:
     *      the index of the first element with value "value" or the index of
     *      the last examined element + 1
     */
    size_t locateChar ( in Char[] str, Char value, size_t start, size_t length )
    in
    {
        assert (start <= str.length, "locateChar: start index out of range");
    }
    body
    {
        length = min(length, str.length);

        void* item = pLocateBinChar(str.ptr + start, value, length - start);

        return item? (item - str.ptr) : length;
    }

    ///
    unittest
    {
        test!("==")(StringSearch!().locateChar("Hello", 'l', 5, size_t.max), 5);
        test!("==")(StringSearch!().locateChar("Hello", 'l', 2, size_t.max), 2);
        test!("==")(StringSearch!().locateChar("Hello", 'l', 3, size_t.max), 3);
        test!("==")(StringSearch!().locateChar("Hello", 'o', 5, size_t.max), 5);
        test!("==")(StringSearch!().locateChar("Hello", 'o', 4, size_t.max), 4);
        test!("==")(StringSearch!().locateChar("Hello", 'o', 0, size_t.max), 4);
        // Test searches in a limited region of the input string
        test!("==")(StringSearch!().locateChar("Hello", 'l', 0, 0), 0);
        test!("==")(StringSearch!().locateChar("Hello", 'l', 0, 2), 2);
        test!("==")(StringSearch!().locateChar("Hello", 'l', 0, 3), 2);
    }


    /**
     * Locates the first occurence of value within str.
     *
     * Params:
     *      str    = string to search for "value"
     *      value  = element value to find
     *      start  = start index
     *
     * Returns:
     *      the index of the first element with value "value" or the index of
     *      the last examined element + 1
     */
    size_t locateChar ( in Char[] str, Char value, size_t start = 0 )
    {
        return locateChar(str, value, start, size_t.max);
    }

    /**
     * Tells whether the first length characters of str, starting fromo start,
     * contain value. If greater, length is truncated to the length of str.
     *
     * Params:
     *     str    = string to search for value
     *     value  = value to search for
     *     start  = start index
     *     length = number of elements to examine
     *
     * Returns:
     *      true if str contains value or false otherwise
     */
    bool containsChar ( in Char[] str, Char value, size_t start, size_t length )
    in
    {
        assert (start <= str.length, "containsChar: start index out of range");
    }
    body
    {
        length = min(length, str.length);

        return !!pLocateBinChar(str.ptr + start, value, length - start);
    }

    ///
    unittest
    {
        test(!StringSearch!().containsChar("Hello", 'l', 5, size_t.max));
        test(StringSearch!().containsChar("Hello", 'l', 2, size_t.max));
        test(StringSearch!().containsChar("Hello", 'l', 3, size_t.max));
        test(!StringSearch!().containsChar("Hello", 'o', 5, size_t.max));
        test(StringSearch!().containsChar("Hello", 'o', 4, size_t.max));
        test(StringSearch!().containsChar("Hello", 'o', 0, size_t.max));

        test(!StringSearch!().containsChar("Hello", 'l', 0, 0));
        test(!StringSearch!().containsChar("Hello", 'l', 0, 2));
        test(StringSearch!().containsChar("Hello", 'l', 0, 3));
    }

    bool containsChar ( in Char[] str, Char value, size_t start = 0 )
    {
        return containsChar(str, value, start, size_t.max);
    }


    /**
     * Scans "str" for "pattern" and returns the index of the first occurrence
     * if found.
     *
     * Params:
     *      str     = string to scan
     *      pattern = search pattern
     *      start   = start location to start searching
     *
     * Returns:
     *      If found, the index of the first occurrence, or the length of "str"
     *      otherwise.
     */
    size_t locatePattern ( in Char[] str, in Char[] pattern, size_t start = 0 )
    {
        if (str.length)
        {
            start = min(start, str.length - 1);
        }

        auto str_search = str[start .. $] ~ TERM;

        Const!(Char)* item = pLocatePattern(str_search.ptr, (pattern ~ TERM).ptr);

        return item? ((item - str_search.ptr) + start) : str.length;
    }

    ///
    unittest
    {
        test!("==")(StringSearch!().locatePattern("Hello World!", "World", 0), 6);
        test!("==")(StringSearch!().locatePattern("[Hello]", "[", 1), "[Hello]".length);
        test!("==")(StringSearch!().locatePattern("[Hello]", "[", 256), "[Hello]".length);
        // Crazy/inconsistent behavior: It should return 1
        test!("==")(StringSearch!().locatePattern("[", "[", 1), 0);
        test!("==")(StringSearch!().locatePattern("[", "[", 256), 0);
    }


    /**
     * Scans "str" for "pattern" and returns the index of the first occurrence
     * if found.
     *
     * Params:
     *      str     = string to scan
     *      pattern = search pattern
     *      start   = index to start searching from
     *
     * Returns:
     *      If found, the index of the first occurrence, or the length of "str"
     *      otherwise.
     */
    size_t locatePatternT ( istring pattern ) ( in Char[] str, size_t start = 0 )
    in
    {
        assert (start <= str.length, "locatePatternT: start index out of range");
    }
    body
    {
        if (str.length)
        {
            start = min(start, str.length - 1);
        }

        auto str_search = str[start .. $] ~ TERM;

        auto item = pLocatePattern(str_search.ptr, pattern.ptr);

        return item? ((item - str_search.ptr) + start) : str.length;
    }

    ///
    unittest
    {
        test!("==")(StringSearch!().locatePatternT!("World")("Hello World!", 0), 6);
        test!("==")(StringSearch!().locatePatternT!("[")("[Hello]", 1), "[Hello]".length);
        // Crazy/inconsistent behavior: It should return 1
        test!("==")(StringSearch!().locatePatternT!("[")("[", 1), 0);
        // Fail unittests, because reasons
        //test!("==")(StringSearch!().locatePattern("[", "[", 256), 0);
    }


    /**************************************************************************

         Tells whether str contains pattern

         Params:
              str     = string to scan
              pattern = search pattern
              start   = search start index

         Returns:
              true if str contains pattern or false otherwise

     **************************************************************************/

    bool containsPattern ( in Char[] str, in Char[] pattern, size_t start = 0 )
    in
    {
        assert (start <= str.length, "containsPattern: start index out of range");
    }
    body
    {
        return !!pLocatePattern((str ~ TERM).ptr + start, (pattern ~ TERM).ptr);
    }

    ///
    unittest
    {
        test(!StringSearch!().containsPattern("Hello", "ll", 5));
        test(StringSearch!().containsPattern("Hello", "ll", 2));
        test(StringSearch!().containsPattern("Hello", "lo", 3));
        test(!StringSearch!().containsPattern("Hello", "lo", 4));
        test(StringSearch!().containsPattern("Hello", "lo", 3));
        test(StringSearch!().containsPattern("Hello", "lo", 0));
    }


    /**************************************************************************

        Locates the first occurrence of any of the characters of charset in str.

        Params:
             str     = string to scan
             charset = set of characters to look for
             start   = search start index

        Returns:
             index of first occurrence of any of the characters of charset in
             str

    **************************************************************************/

    size_t locateCharSet ( in Char[] str, in Char[] charset, size_t start = 0 )
    in
    {
        assert (start <= str.length, "locateCharSet: start index out of range");
    }
    body
    {
        size_t item = pLocateFirstInSet((str ~ TERM).ptr + start, (charset ~ TERM).ptr);

        return item + start;
    }


    /**************************************************************************

        Locates the first occurrence of any of the characters of charset in str.
        Passing charset as template parameter makes this method somewhat more
        efficient when used very frequently.

        Params:
             str     = string to scan
             start   = search start index

        Returns:
             index of first occurrence of any of the characters of charset in
             str

    **************************************************************************/

    size_t locateCharSetT ( istring charset ) ( in Char[] str, size_t start = 0 )
    in
    {
        assert (start <= str.length, "locateCharSetT: start index out of range");
    }
    body
    {
        return pLocateFirstInSet((str ~ TERM).ptr + start, charset.ptr);
    }


    /**************************************************************************

         Shifts "length" characters inside "string" from "src_pos" to "dst_pos".
         This effectively does the same thing as

         ---
              string[src_pos .. src_pos + length] =  string[dst_pos .. dst_pos + length];
         ---

         but allows overlapping ranges.

         Params:
             str     = string to process
             dst_pos = destination start position (index)
             src_pos = source start position (index)
             length  = number of array elements to shift

     **************************************************************************/

    Char[] shiftString ( ref Char[] str, size_t dst_pos, size_t src_pos, size_t length )
    in
    {
        const PREFIX = "shiftString(): ";

        assert (src_pos <= str.length, PREFIX ~ "source start out of range");
        assert (dst_pos <= str.length, PREFIX ~ "destination start out of range");
        assert (src_pos + length <= str.length, PREFIX ~ "source end out of range");
        assert (dst_pos + length <= str.length, PREFIX ~ "destination end out of range");
    }
    body
    {
        pMemMove(str.ptr + dst_pos, str.ptr + src_pos, length);

        return str;
    }



    /**************************************************************************

         Returns the length of "str" without null terminator.

         Params:
              str = input string (may or may not be null terminated)

         Returns:
              the length of the string of this segment

     **************************************************************************/
    size_t lengthOf ( in Char[] str )
    {
        return str.length? (str[$ - 1]? str.length : lengthOf(str.ptr)) : 0;
    }



    /**************************************************************************

         Asserts that "str" is null-terminated.

         Params:
             str = input string

     ***************************************************************************/
    void assertTerm ( istring func ) ( in Char[] str )
    {
        assert (hasTerm(str), msgFunc!(func) ~ ": unterminated string");
    }



    /**************************************************************************

        Adds a '\0' terminator to "str" if not present.

        Params:
             str = string to '\0'-terminate

        Returns:
             true if the string did not have a '\0'-terminator and therefore was
             changed, or false otherwise.

     **************************************************************************/

    bool appendTerm ( ref Char[] str )
    {
        bool terminated = str.length? !str[$ - 1] : false;

        if (!terminated)
        {
            str ~= TERM;
        }

        return !terminated;
    }


    /**************************************************************************

        Strips the null terminator from str, if any.

        Params:
             str = input to '\0'-unterminate

        Returns:
             true if the string had a '\0'-terminator and therefore was changed,
             or false otherwise.

     **************************************************************************/
    bool stripTerm ( ref Char[] str )
    {
        bool terminated = str.length? !str[$ - 1] : false;

        if (terminated)
        {
            str = str[0 .. lengthOf(str)];
        }

        return terminated;
    }



    /**************************************************************************

         Tells whether "str" is null-terminated.

         Params:
              str = input string

         Returns:
              true if "str" is null-terminated or false otherwise

     **************************************************************************/
    bool hasTerm ( in Char[] str )
    {
        return str.length? !str[$ - 1] : false;
    }



    /**************************************************************************

         Tells whether "str" and "pattern" are equal regardless of null
         terminators.

         Params:
              str     = str to compare to "pattern"
              pattern = comparison pattern for "str"

         Returns:
              true on match or false otherwise

     **************************************************************************/
    bool matches ( Char[] str, Char[] pattern )
    {
        return (stripTerm(str) == stripTerm(pattern));
    }



   /***************************************************************************

        Trims white space from "str".

        Params:
             str       = input string
             terminate = set to true to null-terminate the resulting string if
                         the input string is null-terminated

        Returns:
             the resulting string

    ***************************************************************************/
    TChar[] trim (TChar) ( TChar[] str, bool terminate = false )
    {
        static assert (is(Unqual!(TChar) == Char));

        terminate &= hasTerm(str);

        foreach_reverse (i, c; str[0 .. lengthOf(str)])
        {
            if (!isSpace(c))
            {
                str = str[0 .. i + terminate + 1];
                break;
            }
        }

        foreach (i, c; str)
        {
            if (!isSpace(c))
            {
                return str[i .. $];
            }
        }

        return null;
    }

    ///
    unittest
    {
        test!("==")(StringSearch!().trim("trim"), "trim"[]);

        test!("==")(StringSearch!().trim("  trim"), "trim"[]);
        test!("==")(StringSearch!().trim("\ttrim"), "trim"[]);
        test!("==")(StringSearch!().trim(" \t trim"), "trim"[]);

        test!("==")(StringSearch!().trim("trim  "), "trim"[]);
        test!("==")(StringSearch!().trim("trim\t"), "trim"[]);
        test!("==")(StringSearch!().trim("trim \t "), "trim"[]);

        test!("==")(StringSearch!().trim("  trim  "), "trim"[]);
        test!("==")(StringSearch!().trim("\ttrim\t"), "trim"[]);
        test!("==")(StringSearch!().trim("\t \ttrim \t "), "trim"[]);
    }


    /**************************************************************************

         Converts each character of str in-place using convert. convert must be
         a function that takes a character in the first argument and returns the
         converted character.

         Params:
              str = string to convert

         Returns:
              converted string

     **************************************************************************/

    Char[] charConv ( alias convert ) ( ref Char[] str )
    {
        foreach (ref c; str)
        {
            c = cast(Char) convert(c);
        }

        return str;
    }

    /**************************************************************************

        Checks if all symbols of `str` are not modified by predicate
        `convert`, creates a duplicate otherwise.

        Params
            str = string to check/convert

        Returns:
            `str` untouched if all symbols are already converted, duplicated
            and converted string otherwise

     **************************************************************************/

    Const!(Char)[] charConvDup ( alias convert ) ( Const!(Char)[] str )
    {
        foreach (Char c; str)
        {
            if (c != cast(Char) convert(c))
            {
                auto newstr = str.dup;
                foreach (ref Char c2; newstr)
                    c2 = cast(Char) convert(c2);
                return newstr;
            }
        }

        return str;
    }

    /**************************************************************************

         Converts "str" in-place to lower case.

         Params:
              str = string to convert

         Returns:
              converted string

     **************************************************************************/

    alias charConv!(toLower) strToLower;

    /**************************************************************************

         Ensures "str" is all lower case, allocates new copy and converts it
         otherwise.

         Params:
              str = string to check

         Returns:
              converted/verified string

     **************************************************************************/

    alias charConvDup!(toLower) strEnsureLower;

    /**************************************************************************

         Converts "str" in-place to upper case.

         Params:
              str = string to convert

         Returns:
              converted string

     **************************************************************************/

    alias charConv!(toUpper) strToUpper;



    /**************************************************************************

         Tells if all letter characters in "str" match the condition checked by
         "check". "check" must be something that takes a character in the first
         argument and returns an integer type where a value different from 0 means
         that the condition is satisfied.

         Params:
              str = string to convert

         Returns:
              true if all letter characters match the the condition checked by
              "check" or false otherwise

     **************************************************************************/
    bool caseCheck ( alias check ) ( in Char[] str )
    {
        bool result = true;

        foreach (c; str)
        {
            result &= (!isAlpha(c) || !!check(c));
        }

        return result;
    }


    /**************************************************************************

         Checks if all letter characters in "str" are lower case.

         Params:
              str = string to check

         Returns:
              true if all letter characters in "str" are lower case or false
              otherwise

     **************************************************************************/

    alias caseCheck!(isLower) strIsLower;



    /**************************************************************************

     Checks if all letter characters in "str" are upper case.

     Params:
          str = string to check

     Returns:
          true if all letter characters in "str" are upper case or false
          otherwise

     **************************************************************************/
    alias caseCheck!(isUpper) strIsUpper;

    /**************************************************************************

        Splits str into at most n slices on each occurrence of delim. collapse
        indicates whether to collapse consecutive occurrences  to a single one
        to prevent producing empty slices.

        Params:
             slices   = resulting slices buffer
             str      = input string
             delim    = delimiter character
             n        = maximum number of slices; set to 0 to indicate no limit
             collapse = set to true to collapse consecutive occurrences to
                        prevent producing empty "slices"

        Returns:
             the resulting slices

     **************************************************************************/

    TElem[] split (TElem) ( ref TElem[] slices, TElem str, Char delim, uint n = 0,
                     bool collapse = false )
    {
        return split_!(Char, TElem)(slices, str, delim, &locateChar, n, collapse);
    }

    ///
    unittest
    {
        cstring[] slices;

        test!("==")(StringSearch!().split(slices, "a;b;c", ';'),
                    ["a", "b", "c"][]);
        test!("==")(StringSearch!().split(slices, "a;b;c", '.'),
                    ["a;b;c"][]);
        test!("==")(StringSearch!().split(slices, "abc;", ';'),
                    ["abc", ""][]);
        test!("==")(StringSearch!().split(slices, ";abc;", ';'),
                    ["", "abc", ""][]);
        test!("==")(StringSearch!().split(slices, "a;;bc", ';'),
                    ["a", "", "bc"][]);


        test!("==")(StringSearch!().split(slices, "a;b;c", ';', 2),
                    ["a", "b"][]);

        test!("==")(StringSearch!().split(slices, "abc;", ';', 0, true),
                    ["abc"][]);
        test!("==")(StringSearch!().split(slices, ";abc;", ';', 0, true),
                    ["abc"][]);
        test!("==")(StringSearch!().split(slices, "a;;bc", ';', 0, true),
                    ["a", "bc"][]);

        mstring[] mslices;
        test!("==")(StringSearch!().split(slices, "a;b;c".dup, ';'),
                    ["a", "b", "c"][]);
    }


    /**************************************************************************

        Splits str on each occurrence of delim. collapse indicates whether to
        collapse consecutive occurrences  to a single one to prevent producing
        empty slices.

        Params:
             slices   = array to put the resulting slices
             str      = input string
             delim    = delimiter character
             n = maximum number of slices; set to 0 to indicate no limit

        Returns:
             the resulting slices

     **************************************************************************/

    TElem[] splitCollapse (TElem) ( ref TElem[] slices, TElem str, Char delim,
                                    uint n = 0 )
    {
        return split(slices,  str, delim, n, true);
    }


    /**************************************************************************

        Splits str into at most n slices on each occurrence of any character in
        delims. collapse indicates whether to collapse consecutive occurrences
        to a single one to prevent producing empty slices.

        Params:
             slices   = destination array of slices
             str      = input string
             delims   = delimiter character
             n        = maximum number of slices; set to 0 to indicate no limit
             collapse = set to true to collapse consecutive occurrences to
                        prevent producing empty "slices"

     **************************************************************************/

    TElem[] split (TElem) ( ref TElem[] slices, TElem str, in Char[] delims,
                            uint n = 0, bool collapse = false )
    {
        return split_!(Char[], TElem)(slices, str, delims, &locateCharSet, n,
                                      collapse);
    }


    /**************************************************************************

        Splits str on each occurrence of any character in delims. collapse
        indicates whether to collapse consecutive occurrences to a single one to
        prevent producing empty slices.

        Params:
             str      = input string
             delim    = delimiter character
             slices   = destination array of slices
             n        = maximum number of slices; set to 0 to indicate no limit

        Returns:
             the resulting slices

     **************************************************************************/

    TElem[] splitCollapse (TElem) ( ref TElem[] slices, in TElem str,
                                     in Char[] delim, uint n = 0 )
    {
        return split(slices, str, delim, n, true);
    }


    /**************************************************************************

        Locate delimiter function definition template. LocateDelimDg is the type
        of the function callback used by split_().

        LocateDelimDg params:
            str   = string to search for delim
            delim = search pattern of arbitrary type: single character, set of
                    characters, search string, ...
            start = search start start index

        LocateDelimDg shall return:
            index of first occurrence of delim in str, starting from start

     **************************************************************************/

    template LocateDelimDg ( T )
    {
        alias size_t function ( in Char[] str, T delim, size_t start ) LocateDelimDg;
    }

    /**************************************************************************

        Splits str into at most n slices on each occurrence reported by
        locateDelim. collapse indicates whether to collapse consecutive
        occurrences to a single one to prevent producing empty slices.

        Params:
             slices      = destination array of slices
             str         = input string
             delim       = delimiter(s), depending on locateDelim
             locateDelim = callback function which shall locate the
                           occurrence of delim in str; see LocateDelimDg

             collapse = set to true to collapse consecutive occurrences to
                        prevent producing empty "slices"

     **************************************************************************/

    private TElem[] split_  ( T , TElem ) ( ref TElem[] slices, TElem str,
                                            T delim, LocateDelimDg!(T) locateDelim,
                                            uint n, bool collapse )
    {
        static if (is(Unqual!(TElem) E : E[]))
        {
            static assert (is (Unqual!(E) == Char),
                           "TElem should be [const] Char[], not : "
                           ~ TElem.stringof);
        }
        else
        {
            static assert (false, "TElem should be [const] Char[], not : "
                           ~ TElem.stringof);
        }
        uint   i     = 0;

        size_t start = collapse? skipLeadingDelims(str, delim) : 0;

        size_t pos   = locateDelim(str, delim, start);

        slices.length = 0;
        enableStomping(slices);

        while ((pos < str.length) && (!n || (i < n)))
        {
            if (!((pos == start) && collapse))
            {
                slices ~= str[start .. pos];

                i++;
            }

            start = pos + 1;

            pos = locateDelim(str, delim, start);
        }

        if ((!n || (i < n)) && (!((start == str.length) && collapse)))
        {
            slices ~= str[start .. $];                                          // append tail
        }

        return slices;
    }

    /**************************************************************************

        Skips leading occurrences of delim in string.

        Params:
             str      = input string
             delim    = delimiter character

        Returns:
             index of character in str after skipping leading occurrences of
             delim (length of str if str consists of delim characters)

     **************************************************************************/

    private size_t skipLeadingDelims ( T ) ( in Char[] str, T delim )
    {
        foreach (i, c; str)
        {
            bool found;

            static if (is (T U : U[]))
            {
                found = containsChar(delim, c);
            }
            else static if (is (T : Char))
            {
                found = c == delim;
            }
            else static assert (false, "skipLeadingDelims: delim must be of type '" ~
                                       Char.stringof ~ "' or '" ~ (Char[]).stringof ~
                                       "', not '" ~ T.stringof ~ '\'');



            if (!found) return i;
        }

        return str.length;
    }
}
