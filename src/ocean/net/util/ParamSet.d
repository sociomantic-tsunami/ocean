/******************************************************************************

    Manages a set of parameters where each parameter is a string key/value pair.

    Wraps an associative array serving as map of parameter key and value
    strings.
    The parameter keys are set on instantiation; that is, a key list is passed
    to the constructor. The keys cannot be changed, added or removed later by
    ParamSet. However, a subclass can add keys.
    All methods that accept a key handle the key case insensitively (except the
    constructor). When keys are output, the original keys are used.
    Note that keys and values are meant to slice string buffers in a subclass or
    external to this class.

    Build note: Requires linking against libglib-2.0: add

    -L-lglib-2.0

    to the DMD build parameters.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.net.util.ParamSet;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.transition;

import ocean.core.TypeConvert;

import ocean.text.util.SplitIterator: ISplitIterator;

import ocean.stdc.ctype:  tolower;

import ocean.core.Exception_tango: ArrayBoundsException;

/******************************************************************************

    Compares each of the the first n characters in s1 and s2 in a
    case-insensitive manner.

    @see http://www.gtk.org/api/2.6/glib/glib-String-Utility-Functions.html#g-ascii-strncasecmp

    Params:
        s1 = string to compare each of the first n characters aganst those in s2
        s2 = string to compare each of the first n characters aganst those in s1
        n  = number of characters to compare

    Returns:
        an integer less than, equal to, or greater than zero if the first n
        characters of s1 is found, respectively, to be less than, to match, or
        to be greater than the first n characters of s2

 ******************************************************************************/

extern (C) private int g_ascii_strncasecmp ( Const!(char)* s1, Const!(char)* s2, size_t n );

/******************************************************************************/

class ParamSet
{
    struct Element
    {
        cstring key, val;
    }

    /**************************************************************************

        Set to true to skip key/value pairs with a null value on 'foreach'
        iteration.

     **************************************************************************/

    public bool skip_null_values_on_iteration = false;

    /**************************************************************************

        Minimum required buffer length for decimal formatting of an uint value

     **************************************************************************/

    public const ulong_dec_length = ulong.max.stringof.length;

    /**************************************************************************

        Key/value map of the parameter set

        Keys are the parameter keys in lower case, values are structs containing
        the original key and the parameter value. The value stored in the struct
        is set to null initially and by reset().

     **************************************************************************/

    private Element[istring] paramset;

    /**************************************************************************

        Reused buffer for case conversion

     **************************************************************************/

    private mstring tolower_buf;


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Called immediately when this instance is deleted.
            (Must be protected to prevent an invariant from failing.)

        ***********************************************************************/

        protected override void dispose ( )
        {
            this.reset();

            delete this.tolower_buf;
        }
    }

    /**************************************************************************

        Obtains the parameter value corresponding to key. key must be one of
        the parameter keys passed on instantiation or added by a subclass.

        Params:
            key = parameter key (case insensitive)

        Returns:
            parameter value; null indicates that no value is currently set for
            this key

        Throws:
            Behaves like regular associative array indexing.

     **************************************************************************/

    cstring opIndex ( cstring key )
    {
        try
        {
            return this.paramset[this.tolower(key)].val;
        }
        catch (ArrayBoundsException e)
        {
            e.msg ~= " [\"" ~ key ~ "\"]";
            throw e;
        }
    }

    /**************************************************************************

        Obtains the parameter value corresponding to key.

        Params:
            key = parameter key (case insensitive)

        Returns:
            pointer to the corresponding parameter value or null if the key is
            unknown. A pointer to null indicates that no value is currently set
            for this key.

     **************************************************************************/

    cstring* opIn_r ( cstring key )
    {
        Element* element = this.get_(key);

        return element? &element.val : null;
    }

    /**************************************************************************

        Obtains the parameter value corresponding to key, bundled with the
        original key.

        Params:
            key = parameter key (case insensitive)

        Returns:
            Struct containing original key and parameter value or null for key
            and value if the key was not found. A non-null key with a null value
            indicates that no value is currently set for this key.

     **************************************************************************/

    Element getElement ( cstring key )
    out (element)
    {
       assert (element.key || !element.val);
    }
    body
    {
        Element* element = this.get_(key);

        return element? *element : Element.init;
    }

    /**************************************************************************

        Obtains the parameter value corresponding to key which is expected to be
        an unsigned decimal integer number and not empty. key must be one of the
        parameter keys passed on instantiation or added by a subclass.

        Params:
            key    = parameter key (case insensitive)
            n      = result destination; will be changed only if a value exists
                     for key
            is_set = will be changed to true if a value exists for key (even if
                     it is empty or not an unsigned decimal integer number)

        Returns:
            true on success or false if either no value exists for key or the
            value is empty or not an unsigned decimal integer number or.

        Throws:
            Behaves like regular associative array indexing using key as key.

     **************************************************************************/

    bool getUnsigned ( T : ulong ) ( cstring key, ref T n, out bool is_set )
    {
        cstring val = this[key];

        is_set = val !is null;

        return is_set? !this.readUnsigned(val, n).length && val.length : false;
    }

    /**************************************************************************

        ditto

     **************************************************************************/

    bool getUnsigned ( T : ulong ) ( cstring key, ref T n )
    {
        cstring val = this[key];

        return val.length? !this.readUnsigned(val, n).length : false;
    }


    /**************************************************************************

        Sets the parameter value for key. Key must be one of the parameter keys
        passed on instantiation or added by a subclass.

        Params:
            val = parameter value (will be sliced)
            key = parameter key (case insensitive)

        Returns:
            val

        Throws:
            Asserts that key is one of the parameter keys passed on
            instantiation or added by a subclass.

     **************************************************************************/

    cstring opIndexAssign ( cstring val, cstring key )
    {
        Element* element = this.get_(key);

        assert (element !is null, "cannot assign to unknown key \"" ~ key ~ "\"");

        return element.val = val;
    }

    /**************************************************************************

        Sets the parameter value for key if key is one of the parameter keys
        passed on instantiation or added by a subclass.

        Params:
            key = parameter key (case insensitive)
            val = parameter value (will be sliced)

        Returns:
            true if key is one of parameter keys passed on instantiation or
            added by a subclass or false otherwise. In case of false nothing has
            changed.

     **************************************************************************/

    bool set ( cstring key, cstring val )
    {
        return this.access(key, (cstring, ref cstring dst){dst = val;});
    }

    /**************************************************************************

        ditto

        Params:
            key = parameter key (case insensitive)
            val = parameter value
            dec = number to string conversion buffer, a slice will be associated
                  as string value for key

        Returns:
            true if key is one of parameter keys passed on instantiation or
            false otherwise. In case of false nothing has changed.

     **************************************************************************/

    bool set ( cstring key, size_t val, mstring dec )
    {
        return this.access(key, (cstring, ref cstring dst)
                                {
                                    dst = this.writeUnsigned(dec, val);
                                });
    }

    /**************************************************************************

        Invokes dg with the original key and a reference to the parameter value
        for key if key is one of parameter keys passed on instantiation or added
        by a subclass.

        Params:
            key = parameter key (case insensitive)
            dg  = callback delegate

        Returns:
            true if key is one of the parameter keys passed on instantiation or
            added by a subclass or false otherwise. In case of false dg was not
            invoked.

     **************************************************************************/

    bool access ( cstring key, void delegate ( cstring key, ref cstring val ) dg )
    {
        Element* element = this.get_(key);

        if (element)
        {
            dg(element.key, element.val);
        }

        return element !is null;
    }

    /**************************************************************************

        Compares the parameter value corresponding to key with val in a
        case-insensitive manner.

        Params:
            key = parameter key (case insensitive)
            val = parameter value (case insensitive)

        Returns:
            true if a parameter for key exists and its value case-insensitively
            equals val.

     **************************************************************************/

    bool matches ( cstring key, cstring val )
    {
        Element* element = this.get_(key);

        return element?
            (element.val.length == val.length) &&
                !this.strncasecmp(element.val, val) :
            false;
    }

    /**************************************************************************

        'foreach' iteration over parameter key/value pairs

     **************************************************************************/

    public int opApply ( int delegate ( ref cstring key, ref cstring val ) dg )
    {
        int result = 0;

        foreach (ref element; this.paramset)
        {
            this.iterate(element, dg, result);

            if (result) break;
        }

        return result;
    }

    /**************************************************************************

        Resets all parameter values to null.

     **************************************************************************/

    public void reset ( )
    {
        foreach (ref element; this.paramset)
        {
            element.val = null;
        }
    }

    /**************************************************************************

        Compares a to b, treating ASCII characters case-insensitively. If a and
        b have a different length, the first common characters are compared. If
        these are equal, the longer string compares greater.

        To see if the content of a and b is the same, use

        ---
            (a.length == b.length) && !strncasecmp (a, b)
        ---
        .

        Treats null strings like empty strings.

        Params:
            a = string to compare against b
            b = string to compare against a

        Returns:
            a value greater than 0 if a compares greater than b, less than 0
            if a compares less than b, or 0 if a and b are of equal length and
            all characters are equal.

     **************************************************************************/

    public static int strncasecmp ( cstring a, cstring b )
    {
        if ( a.length && b.length )
        {
            if ( a.length == b.length )
            {
                return g_ascii_strncasecmp(a.ptr, b.ptr, a.length);
            }
            else
            {
                bool a_is_shorter = a.length < b.length;
                int c = g_ascii_strncasecmp(a.ptr, b.ptr,
                    a_is_shorter? a.length : b.length);
                return c? c : a_is_shorter? -1 : 1;
            }
        }
        else
        {
            return (a.length < b.length)? -1 :
                       (a.length > b.length)?  1 :
                       0;
        }
    }

    unittest
    {
        assert(strncasecmp("a", "b") < 0);
        assert(strncasecmp("b", "a") > 0);
        assert(strncasecmp("hello", "hello") == 0);
        assert(strncasecmp("hello", "Hello") == 0);
        assert(strncasecmp("hello", "HELLO") == 0);
        assert(strncasecmp("hello", "hello there") < 0);
        assert(strncasecmp("hello there", "hello") > 0);
        assert(strncasecmp("", "hell0") < 0);
        assert(strncasecmp("hello", "") > 0);
        assert(strncasecmp("", "") == 0);
    }

    /**************************************************************************

        Adds an entry for key.

        Params:
            keys = parameter key to add

     **************************************************************************/

    protected void addKeys ( in istring[] keys ... )
    {
        foreach (key; keys)
        {
            this.addKey(key);
        }
    }

    /**************************************************************************

        Adds an entry for key.

        Params:
            key = parameter key to add

     **************************************************************************/

    protected cstring addKey ( cstring key )
    {
        mstring lower_key = this.tolower(key);

        if (!(lower_key in this.paramset))
        {
            this.paramset[idup(lower_key)] = Element(key);
        }

        return lower_key;
    }

    /**************************************************************************

        Looks up key in a case-insensitive manner.

        Params:
            key = parameter key

        Returns:
            - Pointer to a a struct which contains the original key and the
              parameter value, where a null value indicates that no value is
              currently set for this key, or
            - null if the key was not found.

     **************************************************************************/

    protected Element* get_ ( cstring key )
    out (element)
    {
        if (element) with (*element) assert (key || !val);
    }
    body
    {
        return this.tolower(key) in this.paramset;
    }

    /**************************************************************************

        Converts key to lower case, writing to a separate buffer so that key is
        left untouched.

        Params:
            key = key to convert to lower case

        Returns:
            result (references an internal buffer)

     **************************************************************************/

    protected mstring tolower ( cstring key )
    {
        if (this.tolower_buf.length < key.length)
        {
            this.tolower_buf.length = key.length;
        }

        foreach (i, c; key)
        {
            this.tolower_buf[i] = castFrom!(int).to!(char)(.tolower(c));
        }

        return this.tolower_buf[0 .. key.length];
    }

    /**************************************************************************

        Rehashes the associative array.

     **************************************************************************/

    protected void rehash ( )
    {
        this.paramset.rehash;
    }

    /**************************************************************************

        opApply() helper, invokes dg with element.key & val.

        Params:
            element = element currently iterating over
            dg      = opApply() iteration delegate
            result  = set to dg() return value if dg is invoked, remains
                      unchanged otherwise.

     **************************************************************************/

    final protected void iterate ( ref Element element,
                                   int delegate ( ref cstring key, ref cstring val ) dg,
                                   ref int result )
    {
        with (element) if (val || !this.skip_null_values_on_iteration)
        {
            result = dg(key, val);
        }
    }

    /**************************************************************************

        Converts n to decimal representation, writing to dst. dst must be long
        enough to hold the result. The result will be written to the end of dst,
        returning a slice to the valid content in dst.

        Params:
            dst = destination string
            n   = number to convert to decimal representation

        Returns:
            result (dst)

     **************************************************************************/

    protected static mstring writeUnsigned ( mstring dst, ulong n )
    out (dec)
    {
        assert (!n);
        assert (&dec[$ - 1] is &dst[$ - 1]);
    }
    body
    {
        foreach_reverse (i, ref c; dst)
        {
            ulong quot = n / 10;

            c = castFrom!(ulong).to!(char)(n - (quot * 10) + '0');
            n = quot;

            if (!n)
            {
                return dst[i .. $];
            }
        }

        assert (false, typeof (this).stringof ~ ".writeUnsigned: dst too short");
    }

    unittest
    {
        char[ulong_dec_length] dec;

        assert (writeUnsigned(dec, 4711)     == "4711");
        assert (writeUnsigned(dec, 0)        == "0");

        assert (writeUnsigned(dec, uint.max) == "4294967295");
        assert (writeUnsigned(dec, ulong.max) == "18446744073709551615");

        assert (strncasecmp("", "a") < 0);

    }

    /**************************************************************************

        Converts str, which is expected to contain a decimal number, to the
        number it represents. Tailing and leading whitespace is allowed and will
        be trimmed. If src contains non-decimal digit characters after trimming,
        conversion will be stopped at the first non-decimal digit character.

        Example:

        ---

            uint n;

            cstring remaining = readUnsigned("  123abc45  ", n);

            // n is now 123
            // remaining is now "abc45"

        ---

        Params:
            src = source string
            x   = result output

        Returns:
            slice of src starting with the first character that is not a decimal
            digit or an empty string if src contains only decimal digits

     **************************************************************************/

    protected static cstring readUnsigned ( T : ulong ) ( cstring src, out T x )
    in
    {
        static assert (T.init == 0, "initial value of type \"" ~ T.stringof ~ "\" is " ~ T.init.stringof ~ " (need 0)");
        static assert (cast (T) (T.max + 1) < T.max);                           // ensure overflow checking works
    }
    body
    {
        cstring trimmed = ISplitIterator.trim(src);

        foreach (i, c; trimmed)
        {
            if ('0' <= c && c <= '9')
            {
                T y = x * 10 + (c - '0');

                if (y >= x)                                                     // overflow checking
                {
                    x = y;
                    continue;
                }
            }

            return trimmed[i .. $];
        }

        return src? src[$ .. $] : null;
    }
}
