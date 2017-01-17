/*******************************************************************************

    A set of functions for converting strings to integer values.

    This module is adapted from ocean.text.convert.Integer_tango. The functions have
    been modified so that they do not throw exceptions, instead denoting errors
    via their bool return value. This is more efficient and avoids the tango
    style of always throwing new Exceptions upon error.

    Copyright:
        Copyright (c) 2004 Kris Bell.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

    Version:
        Initial release: Nov 2005
        Ocean adaptation: July 2012

    Authors: Kris Bell, Gavin Norman

*******************************************************************************/

module ocean.text.convert.Integer;

import ocean.transition;

import ocean.core.Traits;


/*******************************************************************************

    Parse an integer value from the provided string. The exact type of integer
    parsed is determined by the template parameter T (see below).

    The string is inspected for a sign and an optional radix prefix. A radix may
    be provided as an argument instead, whereupon it must match the prefix
    (where present). When radix is set to zero, conversion will default to
    decimal.

    Template_Params:
        C = char type of string
        T = type of integer to parse (must be byte, ubyte, short, ushort,
            int, uint, long or ulong)

    Params:
        digits = string to parse
        value = receives parsed integer
        radix = specifies which radix to interpret the string as

    Returns:
        true if parsing succeeded

*******************************************************************************/

public bool toInteger ( C, T ) ( C[] digits, out T value, uint radix = 0 )
{
    static if (is(T == byte))
    {
        return toByte(digits, value, radix);
    }
    else static if (is(T == ubyte))
    {
        return toUbyte(digits, value, radix);
    }
    else static if (is(T == short))
    {
        return toShort(digits, value, radix);
    }
    else static if (is(T == ushort))
    {
        return toUshort(digits, value, radix);
    }
    else static if (is(T == int))
    {
        return toInt(digits, value, radix);
    }
    else static if (is(T == uint))
    {
        return toUint(digits, value, radix);
    }
    else static if (is(T == long))
    {
        return toLong(digits, value, radix);
    }
    else static if (is(T == ulong))
    {
        return toUlong(digits, value, radix);
    }
    else
    {
        static assert(false, "toInteger: T must be one of {byte, ubyte, short, "
                    ~ "ushort, int, uint, long, ulong}, not " ~ T.stringof);
    }
}


/*******************************************************************************

    Parse an integer value from the provided string.

    The string is inspected for a sign and an optional radix prefix. A radix may
    be provided as an argument instead, whereupon it must match the prefix
    (where present). When radix is set to zero, conversion will default to
    decimal.

    Template_Params:
        T = char type of string

    Params:
        digits = string to parse
        value = receives parsed integer
        radix = specifies which radix to interpret the string as

    Returns:
        true if parsing succeeded

*******************************************************************************/

public bool toByte ( T ) ( T[] digits, out byte value, uint radix = 0 )
{
    return toSignedInteger(digits, value, radix);
}

/// Ditto
public bool toUbyte ( T ) ( T[] digits, out ubyte value, uint radix = 0 )
{
    return toUnsignedInteger(digits, value, radix);
}

/// Ditto
public bool toShort ( T ) ( T[] digits, out short value, uint radix = 0 )
{
    return toSignedInteger(digits, value, radix);
}

/// Ditto
public bool toUshort ( T ) ( T[] digits, out ushort value, uint radix = 0 )
{
    return toUnsignedInteger(digits, value, radix);
}

/// Ditto
public bool toInt ( T ) ( T[] digits, out int value, uint radix = 0 )
{
    return toSignedInteger(digits, value, radix);
}

/// Ditto
public bool toUint ( T ) ( T[] digits, out uint value, uint radix = 0 )
{
    return toUnsignedInteger(digits, value, radix);
}

/// Ditto
public bool toLong ( T ) ( T[] digits, out long value, uint radix = 0 )
{
    return toSignedInteger(digits, value, radix);
}

/// Ditto
public bool toUlong ( T ) ( T[] digits, out ulong value, uint radix = 0 )
{
    return toUnsignedInteger(digits, value, radix);
}


/*******************************************************************************

    Parse a signed integer value from the provided string.

    The string is inspected for a sign and an optional radix prefix. A radix may
    be provided as an argument instead, whereupon it must match the prefix
    (where present). When radix is set to zero, conversion will default to
    decimal.

    Template_Params:
        T = char type of string
        I = type of integer to extract

    Params:
        digits = string to parse
        value = receives parsed integer
        radix = specifies which radix to interpret the string as

    Returns:
        true if parsing succeeded

*******************************************************************************/

private bool toSignedInteger ( T, I ) ( T[] digits, out I value, uint radix = 0 )
{
    static assert(isSignedIntegerType!(I), "I must be signed integer type.");
    static assert(I.max <= long.max, "I cannot be larger than long.");

    static if (I.max < long.max)
    {
        long long_value;
        if ( !toSignedInteger(digits, long_value, radix) )
        {
            return false;
        }

        if ( long_value > value.max || long_value < value.min )
        {
            return false;
        }

        value = cast(I) long_value;
        return true;
    }
    else
    {
        static assert(is(I == long),
                      "Largest signed integer type should be long.");

        bool negative;
        uint len;
        ulong x;

        auto trimmed = trim(digits, negative, radix);
        convert(digits[trimmed..$], x, len, radix);

        if (len == 0 || trimmed + len < digits.length)
        {
            return false;
        }

        if ((negative && -x < value.min) || (!negative && x > value.max))
        {
            return false;
        }

        value = cast(long)(negative ? -x : x);
        return true;
    }
}


/*******************************************************************************

    Parse an unsigned integer value from the provided string.

    The string is inspected for a sign and an optional radix prefix. A radix may
    be provided as an argument instead, whereupon it must match the prefix
    (where present). When radix is set to zero, conversion will default to
    decimal.

    Template_Params:
        T = char type of string
        U = type of unsigned integer to extract

    Params:
        digits = string to parse
        value = receives parsed unsigned integer
        radix = specifies which radix to interpret the string as

    Returns:
        true if parsing succeeded

*******************************************************************************/

private bool toUnsignedInteger ( T, U ) ( T[] digits, out U value, uint radix = 0 )
{
    static assert(isUnsignedIntegerType!(U), "U must be unsigned integer type.");

    static if (U.max < ulong.max)
    {
        ulong long_value;
        if (!toUnsignedInteger(digits, long_value, radix))
        {
            return false;
        }

        if (long_value > value.max || long_value < value.min)
        {
            return false;
        }

        value = cast(typeof(value)) long_value;
        return true;
    }
    else
    {
        static assert(is(U == ulong),
                      "Largest unsigned integer type should be ulong.");

        bool negative;
        uint len;
        ulong x;

        auto trimmed = trim(digits, negative, radix);
        if ( negative )
        {
            return false;
        }

        convert(digits[trimmed..$], x, len, radix);
        if (len == 0 || trimmed + len < digits.length)
        {
            return false;
        }

        value = x;
        return true;
    }
}


/*******************************************************************************

    Convert the provided 'digits' into an integer value, without checking for a
    sign or radix. The radix defaults to decimal (10).

    Parsing fails (returning false) if 'digits' represents an integer of greater
    magnitude than the type T can store.

    Template_Params:
        T = char type of string

    Params:
        digits = string to parse
        value = receives parsed integer
        eaten = receives the number of characters parsed
        radix = specifies which radix to interpret the string as

    Returns:
        true if parsing succeeded

*******************************************************************************/

private bool convert ( T ) ( T[] digits, out ulong value, out uint eaten,
    uint radix = 10 )
{
    foreach (Unqual!(T) c; digits)
    {
        if (c >= '0' && c <= '9')
        {}
        else
           if (c >= 'a' && c <= 'z')
               c -= 39;
           else
              if (c >= 'A' && c <= 'Z')
                  c -= 7;
              else
                 break;

        if ((c -= '0') < radix)
        {
            if ( value > 0 && radix > value.max / value )
            {
                return false; // multiplication overflow
            }
            value *= radix;

            if ( (value.max - value) < c )
            {
                return false; // addition overflow
            }
            value += c;

            ++eaten;
        }
        else
           break;
    }

    return true;
}


/*******************************************************************************

    Strip leading whitespace, extract an optional +/- sign, and an optional
    radix prefix. If the radix value matches an optional prefix, or the radix is
    zero, the prefix will be consumed and assigned. Where the radix is non zero
    and does not match an explicit prefix, the latter will remain unconsumed.
    Otherwise, radix will default to 10.

    Template_Params:
        T = char type of string

    Params:
        digits = string to parse
        negative = set to true if the string indicates a negative number
        radix = receives the radix parsed form the string

    Returns:
        the number of characters consumed

*******************************************************************************/

private ptrdiff_t trim ( T ) ( T[] digits, ref bool negative, ref uint radix )
{
    Unqual!(T) c;
    T*         p = digits.ptr;
    auto       len = digits.length;

    if (len)
       {
       // strip off whitespace and sign characters
       for (c = *p; len; c = *++p, --len)
            if (c is ' ' || c is '\t')
               {}
            else
               if (c is '-')
                   negative = true;
               else
                  if (c is '+')
                      negative = false;
               else
                  break;

       // strip off a radix specifier also?
       auto r = radix;
       if (c is '0' && len > 1)
           switch (*++p)
                  {
                  case 'x':
                  case 'X':
                       ++p;
                       r = 16;
                       break;

                  case 'b':
                  case 'B':
                       ++p;
                       r = 2;
                       break;

                  case 'o':
                  case 'O':
                       ++p;
                       r = 8;
                       break;

                  default:
                        --p;
                       break;
                  }

       // default the radix to 10
       if (r is 0)
           radix = 10;
       else
          // explicit radix must match (optional) prefix
          if (radix != r)
          {
              if (radix)
                  p -= 2;
              else
                 radix = r;
          }
       }

    // return number of characters eaten
    return (p - digits.ptr);
}



/*******************************************************************************

    Unit test

*******************************************************************************/

unittest
{
    byte b;
    ubyte ub;
    short s;
    ushort us;
    int i;
    uint ui;
    long l;
    ulong ul;

    // basic functionality
    toByte("1", b); assert(b == 1);
    toUbyte("1", ub); assert(ub == 1);
    toShort("1", s); assert(s == 1);
    toUshort("1", us); assert(us == 1);
    toInt("1", i); assert(i == 1);
    toUint("1", ui); assert(ui == 1);
    toLong("1", l); assert(l == 1);
    toUlong("1", ul); assert(ul == 1);

    // basic functionality with wide chars
    toByte("1"w, b); assert(b == 1);
    toUbyte("1"w, ub); assert(ub == 1);
    toShort("1"w, s); assert(s == 1);
    toUshort("1"w, us); assert(us == 1);
    toInt("1"w, i); assert(i == 1);
    toUint("1"w, ui); assert(ui == 1);
    toLong("1"w, l); assert(l == 1);
    toUlong("1"w, ul); assert(ul == 1);

    // basic functionality with double chars
    toByte("1"d, b); assert(b == 1);
    toUbyte("1"d, ub); assert(ub == 1);
    toShort("1"d, s); assert(s == 1);
    toUshort("1"d, us); assert(us == 1);
    toInt("1"d, i); assert(i == 1);
    toUint("1"d, ui); assert(ui == 1);
    toLong("1"d, l); assert(l == 1);
    toUlong("1"d, ul); assert(ul == 1);

    // basic signed functionality
    toByte("+1", b); assert(b == 1);
    toUbyte("+1", ub); assert(ub == 1);
    toShort("+1", s); assert(s == 1);
    toUshort("+1", us); assert(us == 1);
    toInt("+1", i); assert(i == 1);
    toUint("+1", ui); assert(ui == 1);
    toLong("+1", l); assert(l == 1);
    toUlong("+1", ul); assert(ul == 1);

    toByte("-1", b); assert(b == -1);
    assert(!toUbyte("-1", ub));
    toShort("-1", s); assert(s == -1);
    assert(!toUshort("-1", us));
    toInt("-1", i); assert(i == -1);
    assert(!toUint("-1", ui));
    toLong("-1", l); assert(l == -1);
    assert(!toUlong("-1", ul));

    // basic functionality + radix
    toByte("1", b, 10); assert(b == 1);
    toUbyte("1", ub, 10); assert(ub == 1);
    toShort("1", s, 10); assert(s == 1);
    toUshort("1", us, 10); assert(us == 1);
    toInt("1", i, 10); assert(i == 1);
    toUint("1", ui, 10); assert(ui == 1);
    toLong("1", l, 10); assert(l == 1);
    toUlong("1", ul, 10); assert(ul == 1);

    // numerical limits
    toByte("-128", b); assert(b == byte.min);
    toByte("127", b); assert(b == byte.max);
    toUbyte("255", ub); assert(ub == ubyte.max);
    toShort("-32768", s); assert(s == short.min);
    toShort("32767", s); assert(s == short.max);
    toUshort("65535", us); assert(us == ushort.max);
    toInt("-2147483648", i); assert(i == int.min);
    toInt("2147483647", i); assert(i == int.max);
    toUint("4294967295", ui); assert(ui == uint.max);
    toLong("-9223372036854775808", l); assert(l == long.min);
    toLong("9223372036854775807", l); assert(l == long.max);
    toUlong("18446744073709551615", ul); assert(ul == ulong.max);

    // beyond numerical limits
    assert(!toByte("-129", b));
    assert(!toByte("128", b));
    assert(!toUbyte("256", ub));
    assert(!toShort("-32769", s));
    assert(!toShort("32768", s));
    assert(!toUshort("65536", us));
    assert(!toInt("-2147483649", i));
    assert(!toInt("2147483648", i));
    assert(!toUint("4294967296", ui));
    assert(!toLong("-9223372036854775809", l));
    assert(!toLong("9223372036854775808", l));
    assert(!toUlong("18446744073709551616", ul));

    assert(!toLong("-0x12345678123456789", l));
    assert(!toLong("0x12345678123456789", l));
    assert(!toUlong("0x12345678123456789", ul));

    // hex
    toInt("a", i, 16); assert(i == 0xa);
    toInt("b", i, 16); assert(i == 0xb);
    toInt("c", i, 16); assert(i == 0xc);
    toInt("d", i, 16); assert(i == 0xd);
    toInt("e", i, 16); assert(i == 0xe);
    toInt("f", i, 16); assert(i == 0xf);
    toInt("A", i, 16); assert(i == 0xa);
    toInt("B", i, 16); assert(i == 0xb);
    toInt("C", i, 16); assert(i == 0xc);
    toInt("D", i, 16); assert(i == 0xd);
    toInt("E", i, 16); assert(i == 0xe);
    toInt("F", i, 16); assert(i == 0xf);

    toUlong("FF", ul, 16); assert(ul == ubyte.max);
    toUlong("FFFF", ul, 16); assert(ul == ushort.max);
    toUlong("ffffFFFF", ul, 16); assert(ul == uint.max);
    toUlong("ffffFFFFffffFFFF", ul, 16); assert(ul == ulong.max);

    // oct
    toInt("55", i, 8); assert(i == 45);
    toInt("100", i, 8); assert(i == 64);

    // bin
    toInt("10000", i, 2); assert(i == 0b10000);

    // trim
    toInt("    \t20", i); assert(i == 20);
    toInt("    \t-20", i); assert(i == -20);
    toInt("-    \t 20", i); assert(i == -20);

    // recognise radix prefix
    toUlong("0xFFFF", ul); assert(ul == ushort.max);
    toUlong("0XffffFFFF", ul); assert(ul == uint.max);
    toUlong("0o55", ul); assert(ul == 45);
    toUlong("0O100", ul); assert(ul == 64);
    toUlong("0b10000", ul); assert(ul == 0b10000);
    toUlong("0B1010", ul); assert(ul == 0b1010);

    // recognise wrong radix prefix
    assert(!toUlong("0x10", ul, 10));
    assert(!toUlong("0b10", ul, 10));
    assert(!toUlong("0o10", ul, 10));

    // empty string handling (pasring error)
    assert(!toInt("", i));
    assert(!toUint("", ui));
    assert(!toLong("", l));
    assert(!toUlong("", ul));
}
