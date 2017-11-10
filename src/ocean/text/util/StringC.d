/*******************************************************************************

    Module for conversion between strings in C and D. Needed for C library
    bindings.

    Usage:

    ---

        mstring text;

        char* cText = StringC.toCString(text);
        mstring text = StringC.toDString(cText);

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

*******************************************************************************/

module ocean.text.util.StringC;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.Buffer;
import ocean.stdc.string: strlen, wcslen;
import core.stdc.stddef: wchar_t;


/*******************************************************************************

    Class containing the string conversion functions

*******************************************************************************/

class StringC
{
    /***************************************************************************

        Wide character type alias (platform dependent)

     **************************************************************************/

    public alias wchar_t Wchar;

    /***************************************************************************

        Null terminators

     **************************************************************************/

    public static immutable char  Term  = '\0';
    public static immutable Wchar Wterm = '\0';

    /***************************************************************************

        Converts str to a C string, that is, if a null terminator is not
        present then it is appended to the original string. A pointer to the
        string is returned.

        Params:
            str = input string

        Returns:
            C compatible (null terminated) string

    ***************************************************************************/

    public static char* toCString ( ref mstring str )
    {
        return typeof(this).toCString(*(cast(Buffer!(char)*)&str));
    }

    /***************************************************************************

        Converts str to a C string, that is, if a null terminator is not
        present then it is appended to the original string. A pointer to the
        string is returned.

        Params:
            str = input string

        Returns:
            C compatible (null terminated) string

    ***************************************************************************/

    deprecated("Usage of Wchar strings is deprecated.")
    public static Wchar* toCString ( ref Wchar[] str )
    {
        if (!str.length || !!str[$ - 1])
        {
            str ~= StringC.Wterm;
        }

        return str.ptr;
    }

    /***************************************************************************

        Converts str to a C string, that is, if a null terminator is not
        present then it is appended to the original string. A pointer to the
        string is returned.

        Params:
            str = input string buffer

        Returns:
            C compatible (null terminated) string

    ***************************************************************************/

    public static char* toCString ( ref Buffer!(char) str )
    {
        if (!str.length || !!*str[str.length - 1])
        {
            str.length = str.length + 1;
            str[str.length - 1] = StringC.Term;
        }

        return str[].ptr;
    }

    /***************************************************************************

        Converts str to a D string: str is sliced from the beginning up to its
        null terminator.

        Params:
            str = C compatible input string (pointer to the first character of
                the null terminated string)

        Returns:
            D compatible (non-null terminated) string

    ***************************************************************************/

    public static Inout!(char)[] toDString ( Inout!(char)* str )
    {
        return str ? str[0 .. strlen(str)] : null;
    }

    /***************************************************************************

        Converts str to a D string: str is sliced from the beginning up to its
        null terminator.

        Params:
            str = C compatible input string (pointer to the first character of
                the null terminated string)

        Returns:
            D compatible (non-null terminated) string

    ***************************************************************************/

    public static Inout!(Wchar)[] toDString ( Inout!(Wchar)* str )
    {
        return str ? str[0 .. wcslen(str)] : null;
    }
}

version ( UnitTest )
{
    import ocean.core.Test;
}

unittest
{
    mstring str;

    str = "".dup;
    test!("!is")(StringC.toCString(str), null);
    test!("==")(str, "\0");

    str = "Already null-terminated\0".dup;
    StringC.toCString(str);
    test!("==")(str, "Already null-terminated\0");

    str = "Regular D string".dup;
    StringC.toCString(str);
    test!("==")(str, "Regular D string\0");

    test!("==")(StringC.toDString(cast(char *)null), "");

    str = "Hello\0".dup;
    test!("==")(StringC.toDString(str.ptr), "Hello");

    // String literals are null terminated
    istring r1 = StringC.toDString("Hello".ptr);
    test!("==")(r1, "Hello");
    Const!(char)* const_empty = "".ptr;
    assert(const_empty !is null);
    cstring r2 = StringC.toDString(const_empty);
    test!("is")(const_empty, r2.ptr);

    Buffer!(char) buff;
    buff = "Regular D string".dup;
    StringC.toCString(buff);
    test!("==")(buff[], "Regular D string\0");
}
