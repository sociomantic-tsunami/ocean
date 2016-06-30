/*******************************************************************************

    Copyright:
        Copyright (c) 2006 Keinfarbton.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

    Version: Initial release: October 2006

    Authors: Keinfarbton & Kris

*******************************************************************************/

module ocean.stdc.stringz;

import ocean.transition;

/*********************************
 * Convert array of chars to a C-style 0 terminated string.
 * Providing a tmp will use that instead of the heap, where
 * appropriate.
 */

Const!(char)* toStringz (cstring s, char[] tmp = null)
{
    mixin(global(`static char[] empty = "\0".dup`));

    auto len = s.length;
    if (s.ptr)
    {
        if (len is 0)
            return empty.ptr;
        else
        {
            if (s[len-1] != 0)
            {
                if (tmp.length <= len)
                    tmp = new char[len+1];
                tmp [0..len] = s;
                tmp [len] = 0;
                return tmp.ptr;
            }
            else
                return s.ptr;
        }
    }
    else
        return empty.ptr;
}

version (UnitTest)
{
    import ocean.stdc.string;
}

unittest
{
    cstring        input;
    Const!(char)*  sptr;

    // makes use of the fact literals are always 0-terminated

    sptr = toStringz(input);
    assert (strcmp(sptr, "".ptr) == 0);

    input = "aaa".dup;
    sptr = toStringz(input);
    assert (strcmp(sptr, "aaa".ptr) == 0);

    input = "";
    sptr = toStringz(input);
    assert (strcmp(sptr, "".ptr) == 0);

    input = "abcde"[0..2];
    sptr = toStringz(input);
    assert (strcmp(sptr, "ab".ptr) == 0);

    char[20] buf;
    sptr = toStringz(input, buf[]);
    assert (sptr is buf.ptr);
}

/*********************************
 * Convert a series of char[] to C-style 0 terminated strings, using
 * tmp as a workspace and dst as a place to put the resulting char*'s.
 * This is handy for efficiently converting multiple strings at once.
 *
 * Returns a populated slice of dst
 */

Const!(char)*[] toStringz (char[] tmp, Const!(char)*[] dst, cstring[] strings...)
{
    assert (dst.length >= strings.length);

    size_t len = strings.length; // space of /0 chars
    foreach (s; strings)
        len += s.length;
    if (tmp.length < len)
        tmp.length = len;

    foreach (i, s; strings)
    {
        dst[i] = toStringz (s, tmp);
        tmp = tmp [s.length + 1 .. $];
    }
    return dst [0 .. strings.length];
}

unittest
{
    char[] buf;
    Const!(char)*[2] dst;

    auto result = toStringz(buf, dst, "one", "two");

    assert (result.ptr is dst.ptr);
    assert (strcmp(dst[0], "one".ptr) == 0);
    assert (strcmp(dst[1], "two".ptr) == 0);
}

/*********************************
 * Convert a C-style 0 terminated string to an array of char
 */

Const!(char)[] fromStringz (Const!(char)* s)
{
    return s ? s[0 .. strlenz(s)] : null;
}

/*********************************
 * Convert array of wchars s[] to a C-style 0 terminated string.
 */

wchar* toString16z (wchar[] s)
{
    if (s.ptr)
        if (! (s.length && s[$-1] is 0))
            s = s ~ "\0"w;
    return s.ptr;
}

/*********************************
 * Convert a C-style 0 terminated string to an array of wchar
 */

Const!(wchar)[] fromString16z (Const!(wchar)* s)
{
    return s ? s[0 .. strlenz(s)] : null;
}

/*********************************
 * Convert array of dchars s[] to a C-style 0 terminated string.
 */

dchar* toString32z (dchar[] s)
{
    if (s.ptr)
        if (! (s.length && s[$-1] is 0))
            s = s ~ "\0"d;
    return s.ptr;
}

/*********************************
 * Convert a C-style 0 terminated string to an array of dchar
 */

Const!(dchar)[] fromString32z (Const!(dchar)* s)
{
    return s ? s[0 .. strlenz(s)] : null;
}

/*********************************
 * portable strlen
 */

size_t strlenz(T) (T* s)
{
    size_t i;

    if (s)
        while (*s++)
            ++i;
    return i;
}



unittest
{
    auto p = toStringz("foo");
    assert(strlenz(p) == 3);
    auto foo = "abbzxyzzy";
    p = toStringz(foo[3..5]);
    assert(strlenz(p) == 2);

    auto test = "\0";
    p = toStringz(test);
    assert(*p == 0);
    assert(p == test.ptr);
}
