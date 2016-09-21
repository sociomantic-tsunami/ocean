/*******************************************************************************

    A set of functions for converting between string and integer
    values.

    Applying the D "import alias" mechanism to this module is highly
    recommended, in order to limit namespace pollution:
    ---
    import Integer = ocean.text.convert.Integer_tango;

    auto i = Integer.parse ("32767");
    ---

    Copyright:
        Copyright (c) 2004 Kris Bell.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

    Version: Initial release: Nov 2005

    Authors: Kris

 *******************************************************************************/

module ocean.text.convert.Integer_tango;

import ocean.transition;
import ocean.core.Exception_tango;
import ocean.core.Traits_tango;

/******************************************************************************

    Parse an integer value from the provided 'digits' string.

    The string is inspected for a sign and an optional radix
    prefix. A radix may be provided as an argument instead,
    whereupon it must match the prefix (where present). When
    radix is set to zero, conversion will default to decimal.

    Throws: IllegalArgumentException where the input text is not parsable
    in its entirety.

    See_also: the low level functions parse() and convert()

 ******************************************************************************/

int toInt(T) (T[] digits, uint radix=0)
{
    auto x = toLong (digits, radix);
    if (x > int.max)
        throw new IllegalArgumentException ("Integer.toInt :: integer overflow");
    return cast(int) x;
}

unittest
{
    auto x = toInt("42");
    assert(x == 42);
}

/******************************************************************************

  Parse an integer value from the provided 'digits' string.

  The string is inspected for a sign and an optional radix
  prefix. A radix may be provided as an argument instead,
  whereupon it must match the prefix (where present). When
  radix is set to zero, conversion will default to decimal.

Throws: IllegalArgumentException where the input text is not parsable
in its entirety.

See_also: the low level functions parse() and convert()

 ******************************************************************************/

long toLong(T) (T[] digits, uint radix=0)
{
    uint len;

    auto x = parse (digits, radix, &len);
    if (len < digits.length)
        throw new IllegalArgumentException ("Integer.toLong :: invalid literal");
    return x;
}

unittest
{
    auto x = toLong("42");
    assert(x == 42);
}

/******************************************************************************

  Parse an unsignedinteger value from the provided 'digits' string.

  The string is inspected for an optional radix prefix. A
  radix may be provided as an argument instead, whereupon
  it must match the prefix (where present). When radix is
  set to zero, conversion will default to decimal.

Throws: IllegalArgumentException where the input text is not parsable
in its entirety.

See_also: the low level functions parse() and convert()

 ******************************************************************************/

ulong toUlong(T) (T[] digits, uint radix=0)
{
    bool sign = false;

    auto eaten = trim (digits, sign, radix);
    if (sign)
        throw new IllegalArgumentException ("Integer.toUlong :: invalid literal");

    uint len = 0;
    auto value = convert (digits[eaten..$], radix, &len);
    if (len == 0 || eaten + len < digits.length)
        throw new IllegalArgumentException ("Integer.toUlong :: invalid literal");

    return value;
}

unittest
{
    auto x = toUlong("42");
    assert(x == 42);
}

/******************************************************************************

  Wrapper to make life simpler. Returns a text version
  of the provided value.

  See format() for details

 ******************************************************************************/

char[] toString (long i, char[] fmt = null)
{
    char[66] tmp = void;
    return format (tmp, i, fmt).dup;
}

unittest
{
    auto x = toString(42);
    assert(x == "42");
}

/******************************************************************************

  Wrapper to make life simpler. Returns a text version
  of the provided value.

  See format() for details

 ******************************************************************************/

wchar[] toString16 (long i, wchar[] fmt = null)
{
    wchar[66] tmp = void;
    return format (tmp, i, fmt).dup;
}

unittest
{
    wchar[] x = toString16(42);
    assert(x == "42");
}

/******************************************************************************

  Wrapper to make life simpler. Returns a text version
  of the provided value.

  See format() for details

 ******************************************************************************/

dchar[] toString32 (long i, dchar[] fmt = null)
{
    dchar[66] tmp = void;
    return format (tmp, i, fmt).dup;
}

unittest
{
    dchar[] x = toString32(42);
    assert(x == "42");
}

/*******************************************************************************

  Supports format specifications via an array, where format follows
  the notation given below:
  ---
  type width prefix
  ---

  Type is one of [d, g, u, b, x, o] or uppercase equivalent, and
  dictates the conversion radix or other semantics.

  Width is optional and indicates a minimum width for zero-padding,
  while the optional prefix is one of ['#', ' ', '+'] and indicates
  what variety of prefix should be placed in the output. e.g.
  ---
  "d"     => integer
  "u"     => unsigned
  "o"     => octal
  "b"     => binary
  "x"     => hexadecimal
  "X"     => hexadecimal uppercase

  "d+"    => integer prefixed with "+"
  "b#"    => binary prefixed with "0b"
  "x#"    => hexadecimal prefixed with "0x"
  "X#"    => hexadecimal prefixed with "0X"

  "d8"    => decimal padded to 8 places as required
  "b8"    => binary padded to 8 places as required
  "b8#"   => binary padded to 8 places and prefixed with "0b"
  ---

  Note that the specified width is exclusive of the prefix, though
  the width padding will be shrunk as necessary in order to ensure
  a requested prefix can be inserted into the provided output.

 *******************************************************************************/

Const!(T)[] format(T, N) (T[] dst, N i, in T[] fmt = null)
{
    static assert(isIntegerType!(N),
                  "Integer_tango.format only supports integers");

    char    pre,
            type;
    int     width;

    decode (fmt, type, pre, width);
    return formatter (dst, i, type, pre, width);
}

unittest
{
    char[10] buff;
    auto s = format(buff, 42, "x");
    assert (s == "2a", s);

    int x = 43;
    s = format(buff, x);
    assert (s == "43");
}

private void decode(T) (T[] fmt, ref char type, out char pre, out int width)
{
    if (fmt.length is 0)
        type = 'd';
    else
    {
        type = cast(char) fmt[0];
        if (fmt.length > 1)
        {
            auto p = &fmt[1];
            for (int j=1; j < fmt.length; ++j, ++p)
            {
                if (*p >= '0' && *p <= '9')
                    width = width * 10 + (*p - '0');
                else
                    pre = cast(char) *p;
            }
        }
    }
}

private struct _FormatterInfo(T)
{
    byte    radix;
    T[]     prefix;
    T[]     numbers;
}

Const!(T)[] formatter(T, N) (T[] dst, N i, char type, char pre, int width)
{
    static assert(isIntegerType!(N),
                  "Integer_tango.formatter only supports integers");


    const Immut!(T)[] lower = "0123456789abcdef";
    const Immut!(T)[] upper = "0123456789ABCDEF";

    alias _FormatterInfo!(Immut!(T)) Info;

    const Info[] formats = [
        { 10, null, lower},
        { -10, "-" , lower},
        { 10, " " , lower},
        { 10, "+" , lower},
        {  2, "0b", lower},
        {  8, "0o", lower},
        { 16, "0x", lower},
        { 16, "0X", upper},
    ];

    ubyte index;
    int len = cast(int) dst.length;

    if (len)
    {
        switch (type)
        {
            case 'd':
            case 'D':
            case 'g':
            case 'G':
                if (i < 0)
                    index = 1;
                else
                    if (pre is ' ')
                        index = 2;
                    else
                        if (pre is '+')
                            index = 3;
                goto case;
            case 'u':
            case 'U':
                pre = '#';
                break;

            case 'b':
            case 'B':
                index = 4;
                break;

            case 'o':
            case 'O':
                index = 5;
                break;

            case 'x':
                index = 6;
                break;

            case 'X':
                index = 7;
                break;

            default:
                return cast(T[])"{unknown format '"~cast(T)type~"'}";
        }

        auto info = &formats[index];
        auto numbers = info.numbers;
        auto radix = info.radix;

        // convert number to text
        auto p = dst.ptr + len;


        // Base 10 formatting
        if (index <= 3 && index)
        {
            assert((i >= 0 && radix > 0) || (i < 0 && radix < 0));

            do
                *--p = numbers[abs(i % radix)];
            while ((i /= radix) && --len);
         }
        else // Those numbers are not signed
        {
            ulong v = reinterpretInteger!(ulong)(i);
            do
                *--p = numbers[v % radix];
            while ((v /= radix) && --len);
        }

        auto prefix = (pre is '#') ? info.prefix : null;
        if (len > prefix.length)
        {
            len -= prefix.length + 1;

            // prefix number with zeros?
            if (width)
            {
                width = cast(int) (dst.length - width - prefix.length);
                while (len > width && len > 0)
                {
                    *--p = '0';
                    --len;
                }
            }
            // write optional prefix string ...
            dst [len .. len + prefix.length] = prefix;

            // return slice of provided output buffer
            return dst [len .. $];
        }
    }

    return "{output width too small}";
}

/******************************************************************************

  Parse an integer value from the provided 'digits' string.

  The string is inspected for a sign and an optional radix
  prefix. A radix may be provided as an argument instead,
  whereupon it must match the prefix (where present). When
  radix is set to zero, conversion will default to decimal.

  A non-null 'ate' will return the number of characters used
  to construct the returned value.

Throws: none. The 'ate' param should be checked for valid input.

 ******************************************************************************/

long parse(T) (T[] digits, uint radix=0, uint* ate=null)
{
    bool sign;

    auto eaten = trim (digits, sign, radix);
    auto value = convert (digits[eaten..$], radix, ate);

    // check *ate > 0 to make sure we don't parse "-" as 0.
    if (ate && *ate > 0)
        *ate += eaten;

    return cast(long) (sign ? -value : value);
}

unittest
{
    uint ate;
    auto x = parse("-422", 0, &ate);
    assert (x == -422);
    assert (ate == 4);
}

/******************************************************************************

  Convert the provided 'digits' into an integer value,
  without checking for a sign or radix. The radix defaults
  to decimal (10).

  Returns the value and updates 'ate' with the number of
  characters consumed.

Throws: none. The 'ate' param should be checked for valid input.

 ******************************************************************************/

ulong convert(T) (T[] digits, uint radix=10, uint* ate=null)
{
    uint  eaten;
    ulong value;

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
            value = value * radix + c;
            ++eaten;
        }
        else
            break;
    }

    if (ate)
        *ate = eaten;

    return value;
}

unittest
{
    uint ate;
    auto x = convert("422", 10, &ate);
    assert (x == 422);
    assert (ate == 3);
}

/******************************************************************************

  Strip leading whitespace, extract an optional +/- sign,
  and an optional radix prefix. If the radix value matches
  an optional prefix, or the radix is zero, the prefix will
  be consumed and assigned. Where the radix is non zero and
  does not match an explicit prefix, the latter will remain
  unconsumed. Otherwise, radix will default to 10.

  Returns the number of characters consumed.

 ******************************************************************************/

uint trim(T) (T[] digits, ref bool sign, ref uint radix)
{
    Unqual!(T) c;
    auto       p = digits.ptr;
    auto       len = digits.length;

    if (len)
    {
        // strip off whitespace and sign characters
        for (c = *p; len; c = *++p, --len)
            if (c is ' ' || c is '\t')
            {}
            else
                if (c is '-')
                    sign = true;
                else
                    if (c is '+')
                        sign = false;
                    else
                        break;

        // strip off a radix specifier also?
        auto r = radix;
        if (c is '0' && len > 1)
        {
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
        }

        // default the radix to 10
        if (r is 0)
            radix = 10;
        else
        {
            // explicit radix must match (optional) prefix
            if (radix != r)
            {
                if (radix)
                    p -= 2;
                else
                    radix = r;
            }
        }
    }

    // return number of characters eaten
    auto charcount = (p - digits.ptr);
    assert(charcount >= 0);
    return cast(uint) charcount;
}

unittest
{
    bool sign;
    uint radix;
    auto x = trim("  0xFF ", sign, radix);
    assert (x == 4);
    assert (sign == false);
    assert (radix == 16);
}


/******************************************************************************

  quick & dirty text-to-unsigned int converter. Use only when you
  know what the content is, or use parse() or convert() instead.

  Return the parsed uint

 ******************************************************************************/

uint atoi(T) (T[] s, int radix = 10)
{
    uint value;

    foreach (c; s)
        if (c >= '0' && c <= '9')
            value = value * radix + (c - '0');
        else
            break;
    return value;
}


/******************************************************************************

  quick & dirty unsigned to text converter, where the provided output
  must be large enough to house the result (10 digits in the largest
  case). For mainstream use, consider utilizing format() instead.

  Returns a populated slice of the provided output

 ******************************************************************************/

T[] itoa(T) (T[] output, uint value, int radix = 10)
{
    T* p = output.ptr + output.length;

    do {
        *--p = cast(T)(value % radix + '0');
    } while (value /= radix);
    return output[cast(size_t) (p-output.ptr) .. $];
}

unittest
{
    char[10] buff;
    auto s = itoa(buff, 42);
    assert (s == "42");
}

/******************************************************************************

  Consume a number from the input without converting it. Argument
  'fp' enables floating-point consumption. Supports hex input for
  numbers which are prefixed appropriately

  Since version 0.99.9

 ******************************************************************************/

T[] consume(T) (T[] src, bool fp=false)
{
    Unqual!(T) c;
    bool       sign;
    uint       radix;

    // remove leading space, and sign
    auto e = src.ptr + src.length;
    auto p = src.ptr + trim (src, sign, radix);
    auto b = p;

    // bail out if the string is empty
    if (src.length is 0 || p > &src[$-1])
        return null;

    // read leading digits
    for (c=*p; p < e && ((c >= '0' && c <= '9') ||
                (radix is 16 && ((c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))));)
        c = *++p;

    if (fp)
    {
        // gobble up a point
        if (c is '.' && p < e)
            c = *++p;

        // read fractional digits
        while (c >= '0' && c <= '9' && p < e)
            c = *++p;

        // did we consume anything?
        if (p > b)
        {
            // consume exponent?
            if ((c is 'e' || c is 'E') && p < e )
            {
                c = *++p;
                if (c is '+' || c is '-')
                    c = *++p;
                while (c >= '0' && c <= '9' && p < e)
                    c = *++p;
            }
        }
    }
    return src [0 .. p-src.ptr];
}

unittest
{
    auto s = consume("422 abc");
    assert (s == "422");
}


/*******************************************************************************

    Get the absolute value of a number

    The number should not be == `T.min` if `T` is a signed number.
    Since signed numbers use the two's complement, `-T.min` cannot be
    represented: It would be `T.max + 1`.
    Trying to calculate `-T.min` causes an integer overflow and results in
    `T.min`.

    Params:
        x = A value between `T.min` (exclusive for signed number) and `T.max`

    Returns:
        The absolute value of `x` (`|x|`)

*******************************************************************************/

private T abs (T) (T x)
in
{
    static if (T.min < 0)
        assert(x != T.min, "abs cannot be called with x == " ~ T.stringof ~ ".min");
}
body
{
    return x >= 0 ? x : -x;
}


/*******************************************************************************

    Truncates or zero-extend a value of type `From` to fit into `To`.

    Getting the same binary representation of a number in a larger type can be
    quite tedious, especially when it comes to negative numbers.
    For example, turning `byte(-1)` into `long` or `ulong` gives different
    result.
    This functions allows to get the same exact binary representation of an
    integral type into another. If the representation is truncating, it is
    just a cast. If it is widening, it zero extends `val`.

    Params:
        To      = Type to convert to
        From    = Type to convert from. If not specified, it is infered from
                  val, so it will be an `int` when passing a literal.
        val     = Value to reinterpret

    Returns:
        Binary representation of `val` typed as `To`

*******************************************************************************/

private To reinterpretInteger (To, From) (From val)
{
    static if (From.sizeof >= To.sizeof)
        return cast(To) val;
    else
    {
        static struct Reinterpreter
        {
            version (LittleEndian) From value;
            // 0 padding
            ubyte[To.sizeof - From.sizeof] pad;
            version (BigEndian) From value;
        }

        Reinterpreter r = { value: val };
        return *(cast(To*) &r.value);
    }
}


/******************************************************************************

 ******************************************************************************/

unittest
{
    char[64] tmp;

    assert (toInt("1") is 1);
    assert (toLong("1") is 1);
    assert (toInt("1", 10) is 1);
    assert (toLong("1", 10) is 1);
    assert (toUlong("1", 10) is 1);
    assert (toUlong("18446744073709551615") is ulong.max);

    assert (atoi ("12345") is 12345);
    assert (itoa (tmp, 12345) == "12345");

    assert(parse( "0"w ) ==  0 );
    assert(parse( "1"w ) ==  1 );
    assert(parse( "-1"w ) ==  -1 );
    assert(parse( "+1"w ) ==  1 );

    // numerical limits
    assert(parse( "-2147483648" ) == int.min );
    assert(parse(  "2147483647" ) == int.max );
    assert(parse(  "4294967295" ) == uint.max );

    assert(parse( "-9223372036854775808" ) == long.min );
    assert(parse( "9223372036854775807" ) == long.max );
    assert(parse( "18446744073709551615" ) == ulong.max );

    // hex
    assert(parse( "a", 16) == 0x0A );
    assert(parse( "b", 16) == 0x0B );
    assert(parse( "c", 16) == 0x0C );
    assert(parse( "d", 16) == 0x0D );
    assert(parse( "e", 16) == 0x0E );
    assert(parse( "f", 16) == 0x0F );
    assert(parse( "A", 16) == 0x0A );
    assert(parse( "B", 16) == 0x0B );
    assert(parse( "C", 16) == 0x0C );
    assert(parse( "D", 16) == 0x0D );
    assert(parse( "E", 16) == 0x0E );
    assert(parse( "F", 16) == 0x0F );
    assert(parse( "FFFF", 16) == ushort.max );
    assert(parse( "ffffFFFF", 16) == uint.max );
    assert(parse( "ffffFFFFffffFFFF", 16u ) == ulong.max );
    // oct
    assert(parse( "55", 8) == 5 + 8*5 );
    assert(parse( "100", 8) == 64 );
    // bin
    assert(parse( "10000", 2) == 0x10 );
    // trim
    assert(parse( "    \t20") == 20 );
    assert(parse( "    \t-20") == -20 );
    assert(parse( "-    \t 20") == -20 );
    // recognise radix prefix
    assert(parse( "0xFFFF" ) == ushort.max );
    assert(parse( "0XffffFFFF" ) == uint.max );
    assert(parse( "0o55") == 5 + 8*5 );
    assert(parse( "0O55" ) == 5 + 8*5 );
    assert(parse( "0b10000") == 0x10 );
    assert(parse( "0B10000") == 0x10 );

    // prefix tests
    auto str = "0x";
    assert(parse( str[0..1] ) ==  0 );
    assert(parse("0x10", 10) == 0);
    assert(parse("0b10", 10) == 0);
    assert(parse("0o10", 10) == 0);
    assert(parse("0b10") == 0b10);
    assert(parse("0o10") == 8);
    assert(parse("0b10", 2) == 0b10);
    assert(parse("0o10", 8) == 8);

    // revised tests
    assert (format(tmp, 10, "d") == "10");
    assert (format(tmp, -10, "d") == "-10");

    assert (format(tmp, 10L, "u") == "10");
    assert (format(tmp, 10L, "U") == "10");
    assert (format(tmp, 10L, "g") == "10");
    assert (format(tmp, 10L, "G") == "10");
    assert (format(tmp, 10L, "o") == "12");
    assert (format(tmp, 10L, "O") == "12");
    assert (format(tmp, 10L, "b") == "1010");
    assert (format(tmp, 10L, "B") == "1010");
    assert (format(tmp, 10L, "x") == "a");
    assert (format(tmp, 10L, "X") == "A");

    assert (format(tmp, 10L, "d+") == "+10");
    assert (format(tmp, 10L, "d ") == " 10");
    assert (format(tmp, 10L, "d#") == "10");
    assert (format(tmp, 10L, "x#") == "0xa");
    assert (format(tmp, 10L, "X#") == "0XA");
    assert (format(tmp, 10L, "b#") == "0b1010");
    assert (format(tmp, 10L, "o#") == "0o12");

    assert (format(tmp, 10L, "d1") == "10");
    assert (format(tmp, 10L, "d8") == "00000010");
    assert (format(tmp, 10L, "x8") == "0000000a");
    assert (format(tmp, 10L, "X8") == "0000000A");
    assert (format(tmp, 10L, "b8") == "00001010");
    assert (format(tmp, 10L, "o8") == "00000012");

    assert (format(tmp, 10L, "d1#") == "10");
    assert (format(tmp, 10L, "d6#") == "000010");
    assert (format(tmp, 10L, "x6#") == "0x00000a");
    assert (format(tmp, 10L, "X6#") == "0X00000A");

    char[8] tmp1;
    assert (format(tmp1, 10L, "b12#") == "0b001010");
    assert (format(tmp1, 10L, "o12#") == "0o000012");

    assert(format(tmp, long.min, "d") == "-9223372036854775808", tmp);
    assert(format(tmp, long.max, "d") ==  "9223372036854775807", tmp);
    assert(format(tmp, cast(ubyte) -1, "b") ==  "11111111", tmp);
    assert(format(tmp, -1, "b") ==  "11111111111111111111111111111111", tmp);
}

/******************************************************************************

 ******************************************************************************/

debug (Integer)
{
    import ocean.io.Stdout_tango;

    void main()
    {
        char[8] tmp;

        Stdout.formatln ("d '{}'", format(tmp, 10));
        Stdout.formatln ("d '{}'", format(tmp, -10));

        Stdout.formatln ("u '{}'", format(tmp, 10L, "u"));
        Stdout.formatln ("U '{}'", format(tmp, 10L, "U"));
        Stdout.formatln ("g '{}'", format(tmp, 10L, "g"));
        Stdout.formatln ("G '{}'", format(tmp, 10L, "G"));
        Stdout.formatln ("o '{}'", format(tmp, 10L, "o"));
        Stdout.formatln ("O '{}'", format(tmp, 10L, "O"));
        Stdout.formatln ("b '{}'", format(tmp, 10L, "b"));
        Stdout.formatln ("B '{}'", format(tmp, 10L, "B"));
        Stdout.formatln ("x '{}'", format(tmp, 10L, "x"));
        Stdout.formatln ("X '{}'", format(tmp, 10L, "X"));

        Stdout.formatln ("d+ '{}'", format(tmp, 10L, "d+"));
        Stdout.formatln ("ds '{}'", format(tmp, 10L, "d "));
        Stdout.formatln ("d# '{}'", format(tmp, 10L, "d#"));
        Stdout.formatln ("x# '{}'", format(tmp, 10L, "x#"));
        Stdout.formatln ("X# '{}'", format(tmp, 10L, "X#"));
        Stdout.formatln ("b# '{}'", format(tmp, 10L, "b#"));
        Stdout.formatln ("o# '{}'", format(tmp, 10L, "o#"));

        Stdout.formatln ("d1 '{}'", format(tmp, 10L, "d1"));
        Stdout.formatln ("d8 '{}'", format(tmp, 10L, "d8"));
        Stdout.formatln ("x8 '{}'", format(tmp, 10L, "x8"));
        Stdout.formatln ("X8 '{}'", format(tmp, 10L, "X8"));
        Stdout.formatln ("b8 '{}'", format(tmp, 10L, "b8"));
        Stdout.formatln ("o8 '{}'", format(tmp, 10L, "o8"));

        Stdout.formatln ("d1# '{}'", format(tmp, 10L, "d1#"));
        Stdout.formatln ("d6# '{}'", format(tmp, 10L, "d6#"));
        Stdout.formatln ("x6# '{}'", format(tmp, 10L, "x6#"));
        Stdout.formatln ("X6# '{}'", format(tmp, 10L, "X6#"));

        Stdout.formatln ("b12# '{}'", format(tmp, 10L, "b12#"));
        Stdout.formatln ("o12# '{}'", format(tmp, 10L, "o12#")).newline;

        Stdout.formatln (consume("10"));
        Stdout.formatln (consume("0x1f"));
        Stdout.formatln (consume("0.123"));
        Stdout.formatln (consume("0.123", true));
        Stdout.formatln (consume("0.123e-10", true)).newline;

        Stdout.formatln (consume("10  s"));
        Stdout.formatln (consume("0x1f   s"));
        Stdout.formatln (consume("0.123  s"));
        Stdout.formatln (consume("0.123  s", true));
        Stdout.formatln (consume("0.123e-10  s", true)).newline;
    }
}
