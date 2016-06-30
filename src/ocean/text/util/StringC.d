/******************************************************************************

    Module for the conversion between strings in C and D. Needed for C library
    bindings.

    Usage:

    ---

        char[] text;

        char* cText = StringC.toCString(text);
        char[] text = StringD.toDString(cText);

    ---

    FIXME: the functions here are not memory safe, they need to be re-written to
    accept ref char[].

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/


module ocean.text.util.StringC;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.stdc.string: strlen, wcslen;
import ocean.stdc.stddef: wchar_t;


class StringC
{
    /**************************************************************************

        Wide character type alias (platform dependent)

     **************************************************************************/

    public alias wchar_t Wchar;

    /**************************************************************************

        Null terminators

     **************************************************************************/

    public const char  Term  = '\0';
    public const Wchar Wterm = '\0';

    /**************************************************************************

        Converts str to a C string, that is, if a null terminator is not
        present then it is appended to original string. A pointer to the string
        is returned.

        Params:
            str = input string

        Returns:
            C compatible (null terminated) string

     ***************************************************************************/

    public static char* toCstring (ref char[] str)
    {
        if (str.length && !!str[$ - 1])
            str ~= StringC.Term;

        return str.ptr;
    }

    /**************************************************************************

        Converts str to a C string, that is, if a null terminator is not
        present then it is appended to original string. A pointer to the string
        is returned.

        Params:
            str = input string

        Returns:
            C compatible (null terminated) string

    ***************************************************************************/

    public static Wchar* toCstring (ref Wchar[] str)
    {
        if (str.length && !!str[$ - 1])
            str ~= StringC.Wterm;

        return str.ptr;
    }

    /**************************************************************************

        Converts str to a D string: str is sliced from beginning to its null
        terminator.

        Params:
            str = C compatible input string (pointer to first element of null
                  terminated string)

        Returns:
            C compatible (null terminated) string

     ***************************************************************************/

    public static cstring toDString ( char* str )
    {
        return str? str[0 .. strlen(str)] : "";
    }

    /**************************************************************************

        Converts str to a D string: str is sliced from beginning to its null
        terminator.

        Params:
            str = C compatible input string (pointer to first element of null
                  terminated string)

        Returns:
            C compatible (null terminated) string

    ***************************************************************************/

    public static Const!(Wchar)[] toDString ( Wchar* str )
    {
        return str? str[0 .. wcslen(str)] : "";
    }
}
