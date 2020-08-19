/*******************************************************************************

    A set of functions for converting between string and floating-
    point values.

    Applying the D "import alias" mechanism to this module is highly
    recommended, in order to limit namespace pollution:
    ---
    import Float = ocean.text.convert.Float;

    auto f = Float.parse ("3.14159");
    ---

    Copyright:
        Copyright (c) 2004 Kris Bell.
        Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

    Version:
        Nov 2005: Initial release
        Jan 2010: added internal ecvt()

    Authors: Kris

********************************************************************************/

module ocean.text.convert.Float;

import ocean.core.ExceptionDefinitions;
import ocean.core.Verify;
import ocean.math.IEEE;
import ocean.meta.types.Qualifiers;
static import Integer = ocean.text.convert.Integer_tango;

static import tsm = core.stdc.math;

private alias real NumType;

/******************************************************************************

  Constants

 ******************************************************************************/

private enum
{
    Pad = 0,                // default trailing decimal zero
    Dec = 2,                // default decimal places
    Exp = 10,               // default switch to scientific notation
}

/******************************************************************************

  Convert a formatted string of digits to a floating-point
  number. Throws an exception where the input text is not
  parsable in its entirety.

 ******************************************************************************/

NumType toFloat(T) (T[] src)
{
    uint len;

    auto x = parse (src, &len);
    if (len < src.length || len == 0)
        throw new IllegalArgumentException ("Float.toFloat :: invalid number");
    return x;
}

/******************************************************************************

  Template wrapper to make life simpler. Returns a text version
  of the provided value.

  See format() for details

 ******************************************************************************/

char[] toString (NumType d, uint decimals=Dec, int e=Exp)
{
    char[64] tmp = void;

    return format (tmp, d, decimals, e).dup;
}

/******************************************************************************

  Truncate trailing '0' and '.' from a string, such that 200.000
  becomes 200, and 20.10 becomes 20.1

  Returns a potentially shorter slice of what you give it.

 ******************************************************************************/

T[] truncate(T) (T[] s)
{
    auto tmp = s;
    int i = tmp.length;
    foreach (int idx, T c; tmp)
    {
        if (c is '.')
        {
            while (--i >= idx)
            {
                if (tmp[i] != '0')
                {
                    if (tmp[i] is '.')
                        --i;
                    s = tmp [0 .. i+1];
                    while (--i >= idx)
                        if (tmp[i] is 'e')
                            return tmp;
                    break;
                }
            }
        }
    }
    return s;
}

/******************************************************************************

  Extract a sign-bit

 ******************************************************************************/

private bool negative (NumType x)
{
    static if (NumType.sizeof is 4)
        return ((*cast(uint *)&x) & 0x8000_0000) != 0;
    else
        static if (NumType.sizeof is 8)
            return ((*cast(ulong *)&x) & 0x8000_0000_0000_0000) != 0;
    else
    {
        auto pe = cast(ubyte *)&x;
        return (pe[9] & 0x80) != 0;
    }
}


/*******************************************************************************

    Format a floating-point value according to a format string

    Defaults to 2 decimal places and 10 exponent, as the other format overload
    does.

    Format specifiers (additive unless stated otherwise):
        '.' = Do not pad
        'e' or 'E' = Display exponential notation
        Any number = Set the decimal precision

    Params:
        T      = character type
        V      = Floating point type
        output = Where to write the string to - expected to be large enough
        v      = Number to format
        fmt    = Format string, see this function's description

    Returns:
        A const reference to `output`

*******************************************************************************/

public const(T)[] format (T, V) (T[] output, V v, in T[] fmt)
{
    static assert(is(V : const(real)),
                  "Float.format only support floating point types or types that"
                  ~ "implicitly convert to them");

    int dec = Dec;
    int exp = Exp;
    bool pad = true;

    for (auto p = fmt.ptr, e = p + fmt.length; p < e; ++p)
        switch (*p)
        {
        case '.':
            pad = false;
            break;
        case 'e':
        case 'E':
            exp = 0;
            break;
        default:
            Unqual!(T) c = *p;
            if (c >= '0' && c <= '9')
            {
                dec = c - '0', c = p[1];
                if (c >= '0' && c <= '9' && ++p < e)
                    dec = dec * 10 + c - '0';
            }
            break;
        }

    return format!(T)(output, v, dec, exp, pad);
}

/******************************************************************************

  Convert a floating-point number to a string.

  The e parameter controls the number of exponent places emitted,
  and can thus control where the output switches to the scientific
  notation. For example, setting e=2 for 0.01 or 10.0 would result
  in normal output. Whereas setting e=1 would result in both those
  values being rendered in scientific notation instead. Setting e
  to 0 forces that notation on for everything. Parameter pad will
  append trailing '0' decimals when set ~ otherwise trailing '0's
  will be elided

 ******************************************************************************/

T[] format(T) (T[] dst, NumType x, int decimals=Dec, int e=Exp, bool pad=Pad)
{
    const(char)*  end, str;
    int       exp,
              sign,
              mode=5;
    char[32]  buf = void;

    // test exponent to determine mode
    exp = (x == 0) ? 1 : cast(int) tsm.log10l(x < 0 ? -x : x);
    if (exp <= -e || exp >= e)
        mode = 2, ++decimals;

    str = convertl (buf.ptr, x, decimals, &exp, &sign, mode is 5);

    auto p = dst.ptr;
    if (sign)
        *p++ = '-';

    if (exp is 9999)
        while (*str)
            *p++ = *str++;
    else
    {
        if (mode is 2)
        {
            --exp;
            *p++ = *str++;
            if (*str || pad)
            {
                auto d = p;
                *p++ = '.';
                while (*str)
                    *p++ = *str++;
                if (pad)
                    while (p-d < decimals)
                        *p++ = '0';
            }
            *p++ = 'e';
            if (exp < 0)
                *p++ = '-', exp = -exp;
            else
                *p++ = '+';
            if (exp >= 1000)
            {
                *p++ = cast(T)((exp/1000) + '0');
                exp %= 1000;
            }
            if (exp >= 100)
            {
                *p++ = cast(char) (exp / 100 + '0');
                exp %= 100;
            }
            *p++ = cast(char) (exp / 10 + '0');
            *p++ = cast(char) (exp % 10 + '0');
        }
        else
        {
            if (exp <= 0)
                *p++ = '0';
            else
                for (; exp > 0; --exp)
                    *p++ = (*str) ? *str++ : '0';
            if (*str || pad)
            {
                *p++ = '.';
                auto d = p;
                for (; exp < 0; ++exp)
                    *p++ = '0';
                while (*str)
                    *p++ = *str++;
                if (pad)
                    while (p-d < decimals)
                        *p++ = '0';
            }
        }
    }

    // stuff a C terminator in there too ...
    *p = 0;
    return dst[0..(p - dst.ptr)];
}


/******************************************************************************

  ecvt() and fcvt() for 80bit FP, which DMD does not include. Based
  upon the following:

  Copyright (c) 2009 Ian Piumarta

  All rights reserved.

  Permission is hereby granted, free of charge, to any person
  obtaining a copy of this software and associated documentation
  files (the 'Software'), to deal in the Software without restriction,
  including without limitation the rights to use, copy, modify, merge,
  publish, distribute, and/or sell copies of the Software, and to permit
  persons to whom the Software is furnished to do so, provided that the
  above copyright notice(s) and this permission notice appear in all
  copies of the Software.

 ******************************************************************************/

private const(char)* convertl (char* buf, real value, int ndigit,
    int *decpt, int *sign, int fflag)
{
    if ((*sign = negative(value)) != 0)
        value = -value;

    *decpt = 9999;
    if (tsm.isnan(value))
        return "nan\0".ptr;

    if (isInfinity(value))
        return "inf\0".ptr;

    int exp10 = (value == 0) ? !fflag : cast(int) tsm.ceill(tsm.log10l(value));
    if (exp10 < -4931)
        exp10 = -4931;
    value *= tsm.powl(10.0, -exp10);
    if (value)
    {
        while (value <  0.1) { value *= 10;  --exp10; }
        while (value >= 1.0) { value /= 10;  ++exp10; }
    }
    verify(isZero(value) || (0.1 <= value && value < 1.0));
    //auto zero = pad ? int.max : 1;
    auto zero = 1;
    if (fflag)
    {
        // if (! pad)
        zero = exp10;
        if (ndigit + exp10 < 0)
        {
            *decpt= -ndigit;
            return "\0".ptr;
        }
        ndigit += exp10;
    }
    *decpt = exp10;
    int ptr = 1;

    if (ndigit > real.dig)
        ndigit = real.dig;
    //printf ("< flag %d, digits %d, exp10 %d, decpt %d\n", fflag, ndigit, exp10, *decpt);
    while (ptr <= ndigit)
    {
        real i = void;
        value = tsm.modfl(value * 10, &i);
        buf [ptr++]= cast(char) ('0' + cast(int) i);
    }

    if (value >= 0.5)
        while (--ptr && ++buf[ptr] > '9')
            buf[ptr] = (ptr > zero) ? '\0' : '0';
    else
        for (auto i=ptr; i && --i > zero && buf[i] is '0';)
            buf[i] = '\0';

    if (ptr)
    {
        buf [ndigit + 1] = '\0';
        return buf + 1;
    }
    if (fflag)
    {
        ++ndigit;
    }
    buf[0]= '1';
    ++*decpt;
    buf[ndigit]= '\0';
    return buf;
}


/******************************************************************************

  Convert a formatted string of digits to a floating-point number.
  Good for general use, but use David Gay's dtoa package if serious
  rounding adjustments should be applied.

 ******************************************************************************/

NumType parse(T) (in T[] src, uint* ate=null)
{
    T           c;
    const(T)*  p;
    int         exp;
    bool        sign;
    uint        radix;
    NumType     value = 0.0;

    static bool match (const(T)* aa, in T[] bb)
    {
        foreach (b; bb)
        {
            T a = *aa++;
            if (a >= 'A' && a <= 'Z')
                a += 'a' - 'A';
            if (a != b)
                return false;
        }
        return true;
    }

    // remove leading space, and sign
    p = src.ptr + Integer.trim (src, sign, radix);

    // bail out if the string is empty
    if (src.length == 0 || p > &src[$-1])
        return NumType.nan;
    c = *p;

    // handle non-decimal representations
    if (radix != 10)
    {
        long v = Integer.parse (src, radix, ate);
        return cast(NumType) v;
    }

    // set begin and end checks
    auto begin = p;
    auto end = src.ptr + src.length;

    // read leading digits; note that leading
    // zeros are simply multiplied away
    while (c >= '0' && c <= '9' && p < end)
    {
        value = value * 10 + (c - '0');
        c = *++p;
    }

    // gobble up the point
    if (c is '.' && p < end)
        c = *++p;

    // read fractional digits; note that we accumulate
    // all digits ... very long numbers impact accuracy
    // to a degree, but perhaps not as much as one might
    // expect. A prior version limited the digit count,
    // but did not show marked improvement. For maximum
    // accuracy when reading and writing, use David Gay's
    // dtoa package instead
    while (c >= '0' && c <= '9' && p < end)
    {
        value = value * 10 + (c - '0');
        c = *++p;
        --exp;
    }

    // did we get something?
    if (p > begin)
    {
        // parse base10 exponent?
        if ((c is 'e' || c is 'E') && p < end )
        {
            uint eaten;
            exp += Integer.parse (src[(++p-src.ptr) .. $], 0, &eaten);
            p += eaten;
        }

        // adjust mantissa; note that the exponent has
        // already been adjusted for fractional digits
        if (exp < 0)
            value /= pow10 (-exp);
        else
            value *= pow10 (exp);
    }
    else
    {
        if (end - p >= 3)
        {
            switch (*p)
            {
                case 'I': case 'i':
                    if (match (p+1, "nf"))
                    {
                        value = value.infinity;
                        p += 3;
                        if (end - p >= 5 && match (p, "inity"))
                            p += 5;
                    }
                    break;

                case 'N': case 'n':
                    if (match (p+1, "an"))
                    {
                        value = value.nan;
                        p += 3;
                    }
                    break;
                default:
                    break;
            }
        }
    }

    // set parse length, and return value
    if (ate)
    {
        ptrdiff_t diff = p - src.ptr;
        verify (diff >= 0 && diff <= uint.max);
        *ate = cast(uint) diff;
    }

    if (sign)
        value = -value;
    return value;
}

/******************************************************************************

  Internal function to convert an exponent specifier to a floating
  point value.

 ******************************************************************************/

private NumType pow10 (uint exp)
{
    static NumType[] Powers = [
        1.0e1L,
        1.0e2L,
        1.0e4L,
        1.0e8L,
        1.0e16L,
        1.0e32L,
        1.0e64L,
        1.0e128L,
        1.0e256L,
        1.0e512L,
        1.0e1024L,
        1.0e2048L,
        1.0e4096L,
        1.0e8192L,
    ];

    if (exp >= 16384)
        throw new IllegalArgumentException ("Float.pow10 :: exponent too large");

    NumType mult = 1.0;
    foreach (NumType power; Powers)
    {
        if (exp & 1)
            mult *= power;
        if ((exp >>= 1) == 0)
            break;
    }
    return mult;
}

/******************************************************************************

 ******************************************************************************/

debug (Float)
{
    import ocean.io.Console;

    void main()
    {
        char[500] tmp;
        /+
            Cout (format(tmp, NumType.max)).newline;
        Cout (format(tmp, -NumType.nan)).newline;
        Cout (format(tmp, -NumType.infinity)).newline;
        Cout (format(tmp, toFloat("nan"w))).newline;
        Cout (format(tmp, toFloat("-nan"d))).newline;
        Cout (format(tmp, toFloat("inf"))).newline;
        Cout (format(tmp, toFloat("-inf"))).newline;
        +/
            Cout (format(tmp, toFloat ("0.000000e+00"))).newline;
        Cout (format(tmp, toFloat("0x8000000000000000"))).newline;
        Cout (format(tmp, 1)).newline;
        Cout (format(tmp, -0)).newline;
        Cout (format(tmp, 0.000001)).newline.newline;

        Cout (format(tmp, 3.14159, 6, 0)).newline;
        Cout (format(tmp, 3.0e10, 6, 3)).newline;
        Cout (format(tmp, 314159, 6)).newline;
        Cout (format(tmp, 314159123213, 6, 15)).newline;
        Cout (format(tmp, 3.14159, 6, 2)).newline;
        Cout (format(tmp, 3.14159, 3, 2)).newline;
        Cout (format(tmp, 0.00003333, 6, 2)).newline;
        Cout (format(tmp, 0.00333333, 6, 3)).newline;
        Cout (format(tmp, 0.03333333, 6, 2)).newline;
        Cout.newline;

        Cout (format(tmp, -3.14159, 6, 0)).newline;
        Cout (format(tmp, -3e100, 6, 3)).newline;
        Cout (format(tmp, -314159, 6)).newline;
        Cout (format(tmp, -314159123213, 6, 15)).newline;
        Cout (format(tmp, -3.14159, 6, 2)).newline;
        Cout (format(tmp, -3.14159, 2, 2)).newline;
        Cout (format(tmp, -0.00003333, 6, 2)).newline;
        Cout (format(tmp, -0.00333333, 6, 3)).newline;
        Cout (format(tmp, -0.03333333, 6, 2)).newline;
        Cout.newline;

        Cout (format(tmp, -0.9999999, 7, 3)).newline;
        Cout (format(tmp, -3.0e100, 6, 3)).newline;
        Cout ((format(tmp, 1.0, 6))).newline;
        Cout ((format(tmp, 30, 6))).newline;
        Cout ((format(tmp, 3.14159, 6, 0))).newline;
        Cout ((format(tmp, 3e100, 6, 3))).newline;
        Cout ((format(tmp, 314159, 6))).newline;
        Cout ((format(tmp, 314159123213.0, 3, 15))).newline;
        Cout ((format(tmp, 3.14159, 6, 2))).newline;
        Cout ((format(tmp, 3.14159, 4, 2))).newline;
        Cout ((format(tmp, 0.00003333, 6, 2))).newline;
        Cout ((format(tmp, 0.00333333, 6, 3))).newline;
        Cout ((format(tmp, 0.03333333, 6, 2))).newline;
        Cout (format(tmp, NumType.min, 6)).newline;
        Cout (format(tmp, -1)).newline;
        Cout (format(tmp, toFloat(format(tmp, -1)))).newline;
        Cout.newline;
    }
}
