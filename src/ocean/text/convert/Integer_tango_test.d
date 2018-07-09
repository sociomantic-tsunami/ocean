/*******************************************************************************

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

********************************************************************************/

module ocean.text.convert.Integer_tango_test;

import ocean.transition;
import ocean.text.convert.Integer_tango;
import ocean.core.Test;

unittest
{
    char[64] tmp;

    test(toInt("1") is 1);
    test(toLong("1") is 1);
    test(toInt("1", 10) is 1);
    test(toLong("1", 10) is 1);
    test(toUlong("1", 10) is 1);
    test(toUlong("18446744073709551615") is ulong.max);

    test(atoi ("12345") is 12345);
    test(itoa (tmp, 12345) == "12345");

    test(parse( "0"w ) ==  0 );
    test(parse( "1"w ) ==  1 );
    test(parse( "-1"w ) ==  -1 );
    test(parse( "+1"w ) ==  1 );

    // numerical limits
    test(parse( "-2147483648" ) == int.min );
    test(parse(  "2147483647" ) == int.max );
    test(parse(  "4294967295" ) == uint.max );

    test(parse( "-9223372036854775808" ) == long.min );
    test(parse( "9223372036854775807" ) == long.max );
    test(parse( "18446744073709551615" ) == ulong.max );

    // hex
    test(parse( "a", 16) == 0x0A );
    test(parse( "b", 16) == 0x0B );
    test(parse( "c", 16) == 0x0C );
    test(parse( "d", 16) == 0x0D );
    test(parse( "e", 16) == 0x0E );
    test(parse( "f", 16) == 0x0F );
    test(parse( "A", 16) == 0x0A );
    test(parse( "B", 16) == 0x0B );
    test(parse( "C", 16) == 0x0C );
    test(parse( "D", 16) == 0x0D );
    test(parse( "E", 16) == 0x0E );
    test(parse( "F", 16) == 0x0F );
    test(parse( "FFFF", 16) == ushort.max );
    test(parse( "ffffFFFF", 16) == uint.max );
    test(parse( "ffffFFFFffffFFFF", 16u ) == ulong.max );
    // oct
    test(parse( "55", 8) == 5 + 8*5 );
    test(parse( "100", 8) == 64 );
    // bin
    test(parse( "10000", 2) == 0x10 );
    // trim
    test(parse( "    \t20") == 20 );
    test(parse( "    \t-20") == -20 );
    test(parse( "-    \t 20") == -20 );
    // recognise radix prefix
    test(parse( "0xFFFF" ) == ushort.max );
    test(parse( "0XffffFFFF" ) == uint.max );
    test(parse( "0o55") == 5 + 8*5 );
    test(parse( "0O55" ) == 5 + 8*5 );
    test(parse( "0b10000") == 0x10 );
    test(parse( "0B10000") == 0x10 );

    // prefix tests
    auto str = "0x";
    test(parse( str[0..1] ) ==  0 );
    test(parse("0x10", 10) == 0);
    test(parse("0b10", 10) == 0);
    test(parse("0o10", 10) == 0);
    test(parse("0b10") == 0b10);
    test(parse("0o10") == 8);
    test(parse("0b10", 2) == 0b10);
    test(parse("0o10", 8) == 8);

    // revised tests
    test(format(tmp, 10, "d") == "10");
    test(format(tmp, -10, "d") == "-10");

    test(format(tmp, 10L, "u") == "10");
    test(format(tmp, 10L, "U") == "10");
    test(format(tmp, 10L, "g") == "10");
    test(format(tmp, 10L, "G") == "10");
    test(format(tmp, 10L, "o") == "12");
    test(format(tmp, 10L, "O") == "12");
    test(format(tmp, 10L, "b") == "1010");
    test(format(tmp, 10L, "B") == "1010");
    test(format(tmp, 10L, "x") == "a");
    test(format(tmp, 10L, "X") == "A");

    test(format(tmp, 10L, "d+") == "+10");
    test(format(tmp, 10L, "d ") == " 10");
    test(format(tmp, 10L, "d#") == "10");
    test(format(tmp, 10L, "x#") == "0xa");
    test(format(tmp, 10L, "X#") == "0XA");
    test(format(tmp, 10L, "b#") == "0b1010");
    test(format(tmp, 10L, "o#") == "0o12");

    test(format(tmp, 10L, "d1") == "10");
    test(format(tmp, 10L, "d8") == "00000010");
    test(format(tmp, 10L, "x8") == "0000000a");
    test(format(tmp, 10L, "X8") == "0000000A");
    test(format(tmp, 10L, "b8") == "00001010");
    test(format(tmp, 10L, "o8") == "00000012");

    test(format(tmp, 10L, "d1#") == "10");
    test(format(tmp, 10L, "d6#") == "000010");
    test(format(tmp, 10L, "x6#") == "0x00000a");
    test(format(tmp, 10L, "X6#") == "0X00000A");

    char[8] tmp1;
    test(format(tmp1, 10L, "b12#") == "0b001010");
    test(format(tmp1, 10L, "o12#") == "0o000012");

    test(format(tmp, long.min, "d") == "-9223372036854775808", tmp);
    test(format(tmp, long.max, "d") ==  "9223372036854775807", tmp);
    test(format(tmp, cast(ubyte) -1, "b") ==  "11111111", tmp);
    test(format(tmp, -1, "b") ==  "11111111111111111111111111111111", tmp);
}

unittest
{
    auto x = toInt("42");
    test(x == 42);
}

unittest
{
    auto x = toLong("42");
    test(x == 42);
}

unittest
{
    auto x = toUlong("42");
    test(x == 42);
}

unittest
{
    auto x = toString(42);
    test(x == "42");
}

unittest
{
    wchar[] x = toString16(42);
    test(x == "42");
}

unittest
{
    dchar[] x = toString32(42);
    test(x == "42");
}

unittest
{
    char[10] buff;
    auto s = format(buff, 42, "x");
    test(s == "2a", s);

    int x = 43;
    s = format(buff, x);
    test(s == "43");
}

unittest
{
    uint ate;
    auto x = parse("-422", 0, &ate);
    test(x == -422);
    test(ate == 4);
}

unittest
{
    uint ate;
    auto x = convert("422", 10, &ate);
    test(x == 422);
    test(ate == 3);
}

unittest
{
    bool sign;
    uint radix;
    auto x = trim("  0xFF ", sign, radix);
    test(x == 4);
    test(sign == false);
    test(radix == 16);
}

unittest
{
    char[10] buff;
    auto s = itoa(buff, 42);
    test(s == "42");
}

unittest
{
    auto s = consume("422 abc");
    test(s == "422");
}
