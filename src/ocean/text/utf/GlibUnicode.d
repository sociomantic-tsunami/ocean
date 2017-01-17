/******************************************************************************

    Unicode character case conversion based on GLIB

    Note: Requires linking against glib-2: "libglib-2.0.so" on Linux

    TODO: Conversion from UTF-8

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.text.utf.GlibUnicode;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.text.utf.c.glib_unicode: g_unichar_to_utf8,
                                      g_unichar_tolower,
                                      g_unichar_toupper,
                                      g_unichar_totitle;

public  import ocean.text.utf.c.glib_unicode: GUtf8Validation;

/******************************************************************************

    GlibUnicode structure

 ******************************************************************************/

struct GlibUnicode
{

    /**************************************************************************

        Converter function alias definition

     **************************************************************************/

    extern (C) alias dchar function ( dchar c ) Converter;

    /**************************************************************************

        Converts UTF-32 input to lower case

        Params:
            input  = UTF-32 input string
            output = result output (UTF-32 as input)

     **************************************************************************/

    static void toLower ( dchar[] input, ref dchar[] output )
    {
        return convert(input, output, &g_unichar_tolower);
    }

    /**************************************************************************

        Converts UTF-32 input to UTF-8 lower case

        Params:
            input  = UTF-32 input string
            output = result output (UTF-8)

     **************************************************************************/

    static void toLower ( dchar[] input, ref char[] output )
    {
        return convert(input, output, &g_unichar_tolower);
    }

    /**************************************************************************

        Converts UTF-32 content in-place to lower case

        Params:
            content = content buffer

     **************************************************************************/

    static void toLower ( ref dchar[] content )
    {
        return convert(content, &g_unichar_tolower);
    }

    /**************************************************************************

        Converts UTF-32 input to upper case

        Params:
            input  = UTF-32 input string
            output = result output (UTF-32 as input)

     **************************************************************************/

    static void toUpper ( dchar[] input, ref dchar[] output )
    {
        return convert(input, output, &g_unichar_toupper);
    }

    /**************************************************************************

        Converts UTF-32 input to UTF-8 upper case

        Params:
            input  = UTF-32 input string
            output = result output (UTF-8)

     **************************************************************************/

    static void toUpper ( dchar[] input, ref char[] output )
    {
        return convert(input, output, &g_unichar_toupper);
    }

    /**************************************************************************

        Converts UTF-32 content in-place to upper case

        Params:
            content = content buffer

     **************************************************************************/

    static void toUpper ( ref dchar[] content )
    {
        return convert(content, &g_unichar_toupper);
    }

    /**************************************************************************

        Converts UTF-32 input to title case

        Params:
            input  = UTF-32 input string
            output = result output (UTF-32 as input)

     **************************************************************************/

    static void toTitle ( dchar[] input, ref dchar[] output )
    {
        return convert(input, output, &g_unichar_totitle);
    }

    /**************************************************************************

        Converts UTF-32 input to UTF-8 title case

        Params:
            input  = UTF-32 input string
            output = result output (UTF-8)

     **************************************************************************/

    static void toTitle ( dchar[] input, ref char[] output )
    {
        return convert(input, output, &g_unichar_totitle);
    }

    /**************************************************************************

        Converts UTF-32 content in-place to title case

        Params:
            content = content buffer

     **************************************************************************/

    static void toTitle ( ref dchar[] content )
    {
        return convert(content, &g_unichar_totitle);
    }

    /**************************************************************************

        Converts UTF-32 input using convert_fn

        Params:
            input      = UTF-32 input string
            output     = result output (UTF-32 as input)
            convert_fn = convert function

     **************************************************************************/

    static void convert ( dchar[] input, ref char[] output, Converter convert_fn )
    {
        char[6] tmp;

        output.length = 0;

        foreach ( c; input )
        {
            int n = g_unichar_to_utf8(convert_fn(c), tmp.ptr);

            output ~= tmp[0 .. n].dup;
        }
    }

    /**************************************************************************

        Converts UTF-32 input using convert_fn

        Params:
            input      = UTF-32 input string
            output     = result output (UTF-8)
            convert_fn = convert function

     **************************************************************************/

    static void convert ( dchar[] input, ref dchar[] output, Converter convert_fn )
    {
        output.length = input.length;

        foreach ( i, c; input )
        {
            output[i] = convert_fn(c);
        }
    }

    /**************************************************************************

        Converts UTF-32 content in-place using convert_fn

        Params:
            content    = content buffer
            convert_fn = convert function

     **************************************************************************/

    static void convert ( ref dchar[] content, Converter convert_fn )
    {
        foreach ( ref c; content )
        {
            c = convert_fn(c);
        }
    }

    /**************************************************************************

        Converts UTF-32 input to UTF-8

        Params:
            input      = UTF-32 string
            output     = result output (UTF-8)

     **************************************************************************/

    static void toUtf8 ( Char ) ( Char[] input, ref char[] output )
    {
        output.length = 0;

        foreach ( c; input )
        {
            output ~= toUtf8(c);
        }
    }


    /**************************************************************************

        Converts an UTF-32 charachter to UTF-8

        Params:
            c = UTF-32 character

        Returns:
            UTF-8 character

     **************************************************************************/

    static char[] toUtf8 ( Char ) ( Char c )
    {
        static if (Char.sizeof == wchar.sizeof)
            pragma (msg, typeof (*this).stringof
                    ~ ".toUtf8: Only Basic Multilingual Plane supported with "
                    ~ "type '" ~ Char.stringof ~ "'; use 'dchar' "
                    ~ "for full Unicode support");

        char[6] tmp;

        int n = g_unichar_to_utf8(c, tmp.ptr);

        return tmp[0 .. n].dup;
    }

    /**************************************************************************

        Converts an UTF-8 character to UTF-32. If the input character is not
        valid or incomplete, a GUtf8Validation code is returned instead of the
        character.

        Params:
            c = UTF-8 character

        Returns:
            UTF-32 character or GUtf8Validation code

     **************************************************************************/

    static Char toUtf32 ( Char ) ( char[] c )
    {
        static if (Char.sizeof == wchar.sizeof)
            pragma (msg, typeof (*this).stringof
                    ~ ".toUtf8: Only Basic Multilingual Plane supported with "
                    ~ "type '" ~ Char.stringof ~ "'; use 'dchar' "
                    ~ "for full Unicode support");

        return result = g_utf8_get_char_validated(c.ptr, c.length);
    }

}
