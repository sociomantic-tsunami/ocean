/*******************************************************************************

        Copyright:
            Copyright (c) 2010 Ulrik Mikaelsson.
            Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Standards: rfc3548, rfc4648

        Authors: Ulrik Mikaelsson

*******************************************************************************/

/*******************************************************************************

    This module is used to decode and encode hex char[] arrays.

    Example:
    ---
    char[] blah = "Hello there, my name is Jeff.";

    scope encodebuf = new char[allocateEncodeSize(cast(ubyte[])blah)];
    char[] encoded = encode(cast(ubyte[])blah, encodebuf);

    scope decodebuf = new ubyte[encoded.length];
    if (cast(char[])decode(encoded, decodebuf) == "Hello there, my name is Jeff.")
        Stdout("yay").newline;
    ---

    Since v1.0

*******************************************************************************/

module ocean.util.encode.Base16;

import ocean.meta.types.Qualifiers;
import ocean.core.Verify;

version (unittest) import ocean.core.Test;

/*******************************************************************************

    calculates and returns the size needed to encode the length of the
    array passed.

    Params:
    data = An array that will be encoded

*******************************************************************************/


size_t allocateEncodeSize(ubyte[] data)
{
    return allocateEncodeSize(data.length);
}

/*******************************************************************************

    calculates and returns the size needed to encode the length passed.

    Params:
    length = Number of bytes to be encoded

*******************************************************************************/

size_t allocateEncodeSize(size_t length)
{
    return length*2;
}


/*******************************************************************************

    encodes data and returns as an ASCII hex string.

    Params:
    data = what is to be encoded
    buff = buffer large enough to hold encoded data

    Example:
    ---
    char[512] encodebuf;
    char[] myEncodedString = encode(cast(ubyte[])"Hello, how are you today?", encodebuf);
    Stdout(myEncodedString).newline; // 48656C6C6F2C20686F772061726520796F7520746F6461793F
    ---


*******************************************************************************/

char[] encode(ubyte[] data, char[] buff)
{
    verify(data !is null);
    verify(buff.length >= allocateEncodeSize(data));

    size_t i;
    foreach (ubyte j; data) {
        buff[i++] = _encodeTable[j >> 4];
        buff[i++] = _encodeTable[j & 0b0000_1111];
    }

    return buff[0..i];
}

/*******************************************************************************

    encodes data and returns as an ASCII hex string.

    Params:
    data = what is to be encoded

    Example:
    ---
    char[] myEncodedString = encode(cast(ubyte[])"Hello, how are you today?");
    Stdout(myEncodedString).newline; // 48656C6C6F2C20686F772061726520796F7520746F6461793F
    ---


*******************************************************************************/


char[] encode(ubyte[] data)
{
    verify(data !is null);

    auto rtn = new char[allocateEncodeSize(data)];
    return encode(data, rtn);
}

/*******************************************************************************

    decodes an ASCII hex string and returns it as ubyte[] data. Pre-allocates
    the size of the array.

    This decoder will ignore non-hex characters. So:
    SGVsbG8sIGhvd
    yBhcmUgeW91IH
    RvZGF5Pw==

    Is valid.

    Params:
    data = what is to be decoded

    Example:
    ---
    char[] myDecodedString = cast(char[])decode("48656C6C6F2C20686F772061726520796F7520746F6461793F");
    Stdout(myDecodeString).newline; // Hello, how are you today?
    ---

*******************************************************************************/

ubyte[] decode(cstring data)
{
    verify(data !is null);

    auto rtn = new ubyte[data.length+1/2];
    return decode(data, rtn);
}

/*******************************************************************************

    decodes an ASCII hex string and returns it as ubyte[] data.

    This decoder will ignore non-hex characters. So:
    SGVsbG8sIGhvd
    yBhcmUgeW91IH
    RvZGF5Pw==

    Is valid.

    Params:
    data = what is to be decoded
    buff = a big enough array to hold the decoded data

    Example:
    ---
    ubyte[512] decodebuf;
    char[] myDecodedString = cast(char[])decode("48656C6C6F2C20686F772061726520796F7520746F6461793F", decodebuf);
    Stdout(myDecodeString).newline; // Hello, how are you today?
    ---

*******************************************************************************/

ubyte[] decode(cstring data, ubyte[] buff)
{
    verify(data !is null);

    bool even=true;
    size_t i;
    foreach (c; data) {
        auto val = _decodeTable[c];
        if (val & 0b1000_0000)
            continue;
        if (even) {
            buff[i] = cast(ubyte) (val << 4); // Store val in high for bits
        } else {
            buff[i] |= val;     // OR-in low 4 bits,
            i += 1;             // and move on to next
        }
        even = !even; // Switch mode for next iteration
    }
    verify(even, "Non-even amount of hex characters in input.");
    return buff[0..i];
}

unittest
{
    static string[] testRaw = [
        "",
        "A",
        "AB",
        "BAC",
        "BACD",
        "Hello, how are you today?",
        "AbCdEfGhIjKlMnOpQrStUvXyZ",
    ];
    static string[] testEnc = [
        "",
        "41",
        "4142",
        "424143",
        "42414344",
        "48656C6C6F2C20686F772061726520796F7520746F6461793F",
        "4162436445664768496A4B6C4D6E4F7051725374557658795A",
    ];

    for (size_t i; i < testRaw.length; i++) {
        auto resultChars = encode(cast(ubyte[])testRaw[i]);
        test(resultChars == testEnc[i],
                testRaw[i]~": ("~resultChars~") != ("~testEnc[i]~")");

        auto resultBytes = decode(testEnc[i]);
        test(resultBytes == cast(ubyte[])testRaw[i],
                testEnc[i]~": ("~cast(char[])resultBytes~") != ("~testRaw[i]~")");
    }
}

private:

/*
    Static immutable tables used for fast lookups to
    encode and decode data.
*/
static immutable ubyte hex_PAD = '=';
static string _encodeTable = "0123456789ABCDEF";

static const(ubyte)[] _decodeTable = [
    0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF,
    0x00,0x01,0x02,0x03, 0x04,0x05,0x06,0x07, 0x08,0x09,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF,
    0xFF,0x0A,0x0B,0x0C, 0x0D,0x0E,0x0F,0x1F, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF,
    0xFF,0x0A,0x0B,0x0C, 0x0D,0x0E,0x0F,0x1F, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF,
];
