/*******************************************************************************

    This module is used to decode and encode base64 `cstring` / `ubyte[]` arrays

    ---
    istring blah = "Hello there, my name is Jeff.";
    scope encodebuf = new char[allocateEncodeSize(blah.length)];
    mstring encoded = encode(cast(Const!(ubyte)[])blah, encodebuf);

    scope decodebuf = new ubyte[encoded.length];
    if (cast(cstring)decode(encoded, decodebuf) == "Hello there, my name is Jeff.")
      Stdout("yay").newline;
    ---

        Copyright:
            Copyright (c) 2008 Jeff Davey.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Standards: rfc3548, rfc2045

        Authors: Jeff Davey

*******************************************************************************/

module ocean.util.encode.Base64;

import ocean.transition;

version (UnitTest) import ocean.core.Test;


/*******************************************************************************

    Default base64 encode/decode table

    This manifest constant is the default set of characters used by base64
    encoding/decoding, according to RFC4648.

*******************************************************************************/

public const istring defaultEncodeTable = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

/// Ditto
public const ubyte[char.max + 1] defaultDecodeTable = [
    'A' :  0, 'B' :  1, 'C' :  2, 'D' :  3, 'E' :  4,
    'F' :  5, 'G' :  6, 'H' :  7, 'I' :  8, 'J' :  9,
    'K' : 10, 'L' : 11, 'M' : 12, 'N' : 13, 'O' : 14,
    'P' : 15, 'Q' : 16, 'R' : 17, 'S' : 18, 'T' : 19,
    'U' : 20, 'V' : 21, 'W' : 22, 'X' : 23, 'Y' : 24,
    'Z' : 25,

    'a' : 26, 'b' : 27, 'c' : 28, 'd' : 29, 'e' : 30,
    'f' : 31, 'g' : 32, 'h' : 33, 'i' : 34, 'j' : 35,
    'k' : 36, 'l' : 37, 'm' : 38, 'n' : 39, 'o' : 40,
    'p' : 41, 'q' : 42, 'r' : 43, 's' : 44, 't' : 45,
    'u' : 46, 'v' : 47, 'w' : 48, 'x' : 49, 'y' : 50,
    'z' : 51,

    '0' : 52, '1' : 53, '2' : 54, '3' : 55, '4' : 56,
    '5' : 57, '6' : 58, '7' : 59, '8' : 60, '9' : 61,

    '+' : 62, '/' : 63,

    '=' : BASE64_PAD
];


/*******************************************************************************

    URL-safe base64 encode/decode table

    This manifest constant exposes the url-safe ("base64url") variant of the
    encode/decode table, according to RFC4648.

*******************************************************************************/

public const istring urlSafeEncodeTable = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_=";

/// Ditto
public const ubyte[char.max + 1] urlSafeDecodeTable = [
    'A' :  0, 'B' :  1, 'C' :  2, 'D' :  3, 'E' :  4,
    'F' :  5, 'G' :  6, 'H' :  7, 'I' :  8, 'J' :  9,
    'K' : 10, 'L' : 11, 'M' : 12, 'N' : 13, 'O' : 14,
    'P' : 15, 'Q' : 16, 'R' : 17, 'S' : 18, 'T' : 19,
    'U' : 20, 'V' : 21, 'W' : 22, 'X' : 23, 'Y' : 24,
    'Z' : 25,

    'a' : 26, 'b' : 27, 'c' : 28, 'd' : 29, 'e' : 30,
    'f' : 31, 'g' : 32, 'h' : 33, 'i' : 34, 'j' : 35,
    'k' : 36, 'l' : 37, 'm' : 38, 'n' : 39, 'o' : 40,
    'p' : 41, 'q' : 42, 'r' : 43, 's' : 44, 't' : 45,
    'u' : 46, 'v' : 47, 'w' : 48, 'x' : 49, 'y' : 50,
    'z' : 51,

    '0' : 52, '1' : 53, '2' : 54, '3' : 55, '4' : 56,
    '5' : 57, '6' : 58, '7' : 59, '8' : 60, '9' : 61,

    '-' : 62, '_' : 63,

    '=' : BASE64_PAD
];


/// Value set to the padding
private const ubyte BASE64_PAD = 64;

/*******************************************************************************

    Provide the size of the data once base64 encoded

    When data is encoded in Base64, it is packed in groups of 3 bytes, which
    are then encoded in 4 bytes (by groups of 6 bytes).
    In case length is not a multiple of 3, we add padding.
    It means we need `length / 3 * 4` + `length % 3 ? 4 : 0`.

    Params:
      data = An array that will be encoded

    Returns:
      The size needed to encode `data` in base64

*******************************************************************************/


public size_t allocateEncodeSize (in ubyte[] data)
{
    return allocateEncodeSize(data.length);
}

/*******************************************************************************

    Provide the size of the data once base64 encoded

    When data is encoded in Base64, it is packed in groups of 3 bytes, which
    are then encoded in 4 bytes (by groups of 6 bytes).
    In case length is not a multiple of 3, we add padding.
    It means we need `length / 3 * 4` + `length % 3 ? 4 : 0`.

    Params:
      length = Number of bytes to be encoded

    Returns:
      The size needed to encode a data of the provided length

*******************************************************************************/

public size_t allocateEncodeSize (size_t length)
{
    size_t tripletCount = length / 3;
    size_t tripletFraction = length % 3;
    return (tripletCount + (tripletFraction ? 1 : 0)) * 4;
}


/*******************************************************************************

    Encodes `data` into `buff` and returns the number of bytes encoded.
    This will not terminate and pad any "leftover" bytes, and will instead
    only encode up to the highest number of bytes divisible by three.

    Params:
      table = The encode table to use, either `defaultEncodeTable` (the default)
              or `urlSafeEncodeTable`, or one's own encode table.
      data = what is to be encoded
      buff = buffer large enough to hold encoded data
      bytesEncoded = ref that returns how much of the buffer was filled

    Returns:
      The number of bytes left to encode

*******************************************************************************/

public int encodeChunk (istring table = defaultEncodeTable)
    (in ubyte[] data, mstring buff, ref int bytesEncoded)
{
    static assert(validateEncodeTable(table) is null,
                  validateEncodeTable(table));

    size_t tripletCount = data.length / 3;
    int rtn = 0;
    char *rtnPtr = buff.ptr;
    Const!(ubyte) *dataPtr = data.ptr;

    if (data.length > 0)
    {
        rtn = cast(int) tripletCount * 3;
        bytesEncoded = cast(int) tripletCount * 4;
        for (size_t i; i < tripletCount; i++)
        {
            *rtnPtr++ = table[((dataPtr[0] & 0xFC) >> 2)];
            *rtnPtr++ = table[(((dataPtr[0] & 0x03) << 4) | ((dataPtr[1] & 0xF0) >> 4))];
            *rtnPtr++ = table[(((dataPtr[1] & 0x0F) << 2) | ((dataPtr[2] & 0xC0) >> 6))];
            *rtnPtr++ = table[(dataPtr[2] & 0x3F)];
            dataPtr += 3;
        }
    }

    return rtn;
}

/*******************************************************************************

    Encodes data and returns as an ASCII base64 string.

    Params:
      table = The encode table to use, either `defaultEncodeTable` (the default)
              or `urlSafeEncodeTable`, or one's own encode table.
              An array of 65 chars is expected, where the last char is used
              for padding
      data = what is to be encoded
      buff = buffer large enough to hold encoded data
      pad  = Whether or not to pad the output - default to `true`

    Example:
    ---
    char[512] encodebuf;
    mstring myEncodedString = encode(cast(Const!(ubyte)[])"Hello, how are you today?", encodebuf);
    Stdout(myEncodedString).newline; // SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==
    ---

*******************************************************************************/

public mstring encode (istring table = defaultEncodeTable)
    (in ubyte[] data, mstring buff, bool pad = true)
in
{
    assert(data);
    assert(buff.length >= allocateEncodeSize(data));
}
body
{
    static assert(validateEncodeTable(table) is null,
                  validateEncodeTable(table));

    mstring rtn = null;

    if (data.length > 0)
    {
        int bytesEncoded = 0;
        int numBytes = encodeChunk!(table)(data, buff, bytesEncoded);
        char *rtnPtr = buff.ptr + bytesEncoded;
        Const!(ubyte)* dataPtr = data.ptr + numBytes;
        auto tripletFraction = data.length - (dataPtr - data.ptr);

        switch (tripletFraction)
        {
            case 2:
                *rtnPtr++ = table[((dataPtr[0] & 0xFC) >> 2)];
                *rtnPtr++ = table[(((dataPtr[0] & 0x03) << 4) | ((dataPtr[1] & 0xF0) >> 4))];
                *rtnPtr++ = table[((dataPtr[1] & 0x0F) << 2)];
                if (pad)
                    *rtnPtr++ = table[BASE64_PAD];
                break;
            case 1:
                *rtnPtr++ = table[((dataPtr[0] & 0xFC) >> 2)];
                *rtnPtr++ = table[((dataPtr[0] & 0x03) << 4)];
                if (pad)
                {
                    *rtnPtr++ = table[BASE64_PAD];
                    *rtnPtr++ = table[BASE64_PAD];
                }
                break;
            default:
                break;
        }
        rtn = buff[0..(rtnPtr - buff.ptr)];
    }

    return rtn;
}


/*******************************************************************************

    Encodes data and returns as an ASCII base64 string

    Params:
      table = The encode table to use, either `defaultEncodeTable` (the default)
              or `urlSafeEncodeTable`, or one's own encode table.
      data = what is to be encoded
      pad  = Whether or not to pad the output - default to `true`

    Example:
    ---
    mstring myEncodedString = encode(cast(ubyte[])"Hello, how are you today?");
    Stdout(myEncodedString).newline; // SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==
    ---

*******************************************************************************/

public mstring encode (istring table = defaultEncodeTable)
    (in ubyte[] data, bool pad = true)
in
{
    assert(data);
}
body
{
    auto rtn = new char[allocateEncodeSize(data)];
    return encode!(table)(data, rtn, pad);
}


/*******************************************************************************

    Decodes an ASCII base64 string and returns it as ubyte[] data.
    Allocates the size of the array.

    This decoder will ignore non-base64 characters, so for example data with
    newline in it is valid.
    Note that the entries in the provided decode table are not required to be
    unique. This allows the use of decode tables with alternatives for certain
    characters.

    Params:
      Table = The decode table to use. Variadic template parameter is used to
              allow passing it as an expression in D1, but a single `ubyte[256]`
              is expected.
      data = what is to be decoded

    Example:
    ---
    mstring myDecodedString = cast(mstring)decode("SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==");
    Stdout(myDecodedString).newline; // Hello, how are you today?
    ---

*******************************************************************************/

public ubyte[] decode () (cstring data)
{
    return decode!(defaultDecodeTable)(data);
}

/// Ditto
public ubyte[] decode (Table...) (cstring data)
in
{
    assert(data);
}
body
{
    auto rtn = new ubyte[data.length];
    return decode!(Table)(data, rtn);
}

/*******************************************************************************

    Decodes an ASCCI base64 string and returns it as ubyte[] data.

    This decoder will ignore non-base64 characters, so for example data with
    newline in it is valid.
    Note that the entries in the provided decode table are not required to be
    unique. This allows the use of decode tables with alternatives for certain
    characters.

    Params:
      Table = The decode table to use. Variadic template parameter is used to
              allow passing it as an expression in D1, but a single `ubyte[256]`
              is expected.
      data = what is to be decoded
      buff = a big enough array to hold the decoded data

    Example:
    ---
    ubyte[512] decodebuf;
    mstring myDecodedString = cast(mstring)decode("SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==", decodebuf);
    Stdout(myDecodedString).newline; // Hello, how are you today?
    ---

*******************************************************************************/

public ubyte[] decode () (cstring data, ubyte[] buff)
{
    return decode!(defaultDecodeTable)(data, buff);
}

/// Ditto
public ubyte[] decode (Table...) (cstring data, ubyte[] buff)
in
{
    assert(data);
}
body
{
    static assert(Table.length == 1,
                  "A single argument is expected, not: " ~ Table.stringof);
    static assert(validateDecodeTable(Table[0]) == null,
                  validateDecodeTable(Table[0]));

    const table = Table[0];
    ubyte[] rtn;

    if (data.length > 0)
    {
        ubyte[4] base64Quad;
        ubyte *quadPtr = base64Quad.ptr;
        ubyte *endPtr = base64Quad.ptr + 4;
        ubyte *rtnPt = buff.ptr;
        size_t encodedLength = 0;

        ubyte padCount = 0;
        ubyte endCount = 0;
        ubyte paddedPos = 0;
        foreach_reverse(char piece; data)
        {
            paddedPos++;
            ubyte current = table[piece];
            if (current || piece == 'A')
            {
                endCount++;
                if (current == BASE64_PAD)
                    padCount++;
            }
            if (endCount == 4)
                break;
        }

        if (padCount > 2)
            throw new Exception("Improperly terminated base64 string. Base64 pad character (=) found where there shouldn't be one.");
        if (padCount == 0)
            paddedPos = 0;

        auto nonPadded = data[0..($ - paddedPos)];
        foreach(piece; nonPadded)
        {
            ubyte next = table[piece];
            if (next || piece == 'A')
                *quadPtr++ = next;
            if (quadPtr is endPtr)
            {
                rtnPt[0] = cast(ubyte) ((base64Quad[0] << 2) | (base64Quad[1] >> 4));
                rtnPt[1] = cast(ubyte) ((base64Quad[1] << 4) | (base64Quad[2] >> 2));
                rtnPt[2] = cast(ubyte) ((base64Quad[2] << 6) | base64Quad[3]);
                encodedLength += 3;
                quadPtr = base64Quad.ptr;
                rtnPt += 3;
            }
        }

        // this will try and decode whatever is left, even if it isn't terminated properly (ie: missing last one or two =)
        if (paddedPos)
        {
            auto padded = data[($ - paddedPos) .. $];
            foreach(char piece; padded)
            {
                ubyte next = table[piece];
                if (next || piece == 'A')
                    *quadPtr++ = next;
                if (quadPtr is endPtr)
                {
                    *rtnPt++ = cast(ubyte) (((base64Quad[0] << 2) | (base64Quad[1]) >> 4));
                    if (base64Quad[2] != BASE64_PAD)
                    {
                        *rtnPt++ = cast(ubyte) (((base64Quad[1] << 4) | (base64Quad[2] >> 2)));
                        encodedLength += 2;
                        break;
                    }
                    else
                    {
                        encodedLength++;
                        break;
                    }
                }
            }
        }

        rtn = buff[0..encodedLength];
    }

    return rtn;
}


unittest
{
    istring str = "Hello, how are you today?";
    Const!(ubyte)[] payload = cast(Const!(ubyte)[]) str;

    // encodeChunktest
    {
        mstring encoded = new char[allocateEncodeSize(payload)];
        int bytesEncoded = 0;
        int numBytesLeft = encodeChunk(payload, encoded, bytesEncoded);
        cstring result = encoded[0..bytesEncoded] ~ encode(payload[numBytesLeft..$], encoded[bytesEncoded..$]);
        test!("==")(result, "SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==");
    }

    // encodeTest
    {
        mstring encoded = new char[allocateEncodeSize(payload)];
        cstring result = encode(payload, encoded);
        test!("==")(result, "SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==");

        cstring result2 = encode(payload);
        test!("==")(result, "SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==");
    }

    // decodeTest
    {
        ubyte[1024] decoded;
        ubyte[] result = decode("SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==", decoded);
        test!("==")(result, payload);
        result = decode("SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==");
        test!("==")(result, payload);
    }
}

// Encode without padding
unittest
{
    istring str = "Hello, how are you today?";
    Const!(ubyte)[] payload = cast(Const!(ubyte)[]) str;
    cstring result = encode(payload, false);
    test!("==")(result, "SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw");
}


/*******************************************************************************

    Helper function, called only at CTFE, to validate that the encode table
    passed to `encode` is valid

    Params:
      s = Input string to `encode` to check for base64 compliance

    Returns:
      An error message if there is an error, `null` otherwise

*******************************************************************************/

private istring validateEncodeTable (istring s)
{
    if (s.length != 65)
        return "Base64 expects a 65-chars string for encoding, not: " ~ s;

    bool[char.max + 1] v;
    foreach (char c; s)
    {
        if (v[c])
            return "Base64 expects 65 unique chars, but '" ~  s
                ~ "' contains duplicated entry: " ~ c;
        v[c] = true;
    }
    return null;
}

unittest
{
    test!("is")(validateEncodeTable(defaultEncodeTable), istring.init);
    test!("is")(validateEncodeTable(urlSafeEncodeTable), istring.init);
    istring too_long = defaultEncodeTable ~ 'A';
    test!("!is")(validateEncodeTable(too_long), istring.init);
    mstring _dupes = defaultEncodeTable.dup;
    _dupes[1] = 'A';
    istring dupes = assumeUnique(_dupes);
    assert(dupes[0] == dupes[1]);
    test!("!is")(validateEncodeTable(dupes), istring.init);
}


/*******************************************************************************

    Helper function, called only at CTFE, to validate that the decode table
    passed to `decode` is valid

    Params:
      table = Input encode table to `decode` to check for base64 compliance

    Returns:
      An error message if there is an error, `null` otherwise

*******************************************************************************/

private istring validateDecodeTable (T) (in T table)
{
    static if (!is(T : ubyte[char.max + 1]))
    {
        return "Expected an decode table of type `ubyte[char.max+1]`, got: "
            ~ T.stringof;
    }
    else
    {
        // DMD BUG: Using foreach here iterates over the same index twice...
        for (size_t i; i < table.length; ++i)
        {
            char decodedChar = cast(char) i;
            ubyte encodedValue = table[i];

            if (encodedValue > BASE64_PAD)
                return "Decode table cannot contain values > 64";
            // Unused entries have values 0, so that's the only one we cannot
            // validate
            if (encodedValue == 0)
                continue;
        }
        return null;
    }
}

unittest
{
    test!("is")(validateDecodeTable(defaultDecodeTable), istring.init);
    test!("is")(validateDecodeTable(urlSafeDecodeTable), istring.init);

    ubyte[] notATable = new ubyte[char.max + 1];
    test!("!is")(validateDecodeTable(notATable), istring.init);

    ubyte[char.max + 1] table = defaultDecodeTable;
    assert(validateDecodeTable(table) is null);
    table['*'] = BASE64_PAD;
    assert(table['='] == table['*']);
    test!("is")(validateDecodeTable(table), istring.init);
}


// base64url tests
unittest
{
    istring str = "Why so serious?";
    Const!(ubyte)[] payload = cast(Const!(ubyte)[]) str;

    // encodeChunktest
    {
        mstring encoded = new char[allocateEncodeSize(payload)];
        int bytesEncoded = 0;
        int numBytesLeft = encodeChunk!(urlSafeEncodeTable)(payload, encoded, bytesEncoded);
        cstring result = encoded[0..bytesEncoded] ~ encode!(urlSafeEncodeTable)(payload[numBytesLeft..$], encoded[bytesEncoded..$]);
        test!("==")(result, "V2h5IHNvIHNlcmlvdXM_");
    }

    // encodeTest
    {
        mstring encoded = new char[allocateEncodeSize(payload)];
        cstring result = encode!(urlSafeEncodeTable)(payload, encoded);
        test!("==")(result, "V2h5IHNvIHNlcmlvdXM_");

        cstring result2 = encode!(urlSafeEncodeTable)(payload);
        test!("==")(result, "V2h5IHNvIHNlcmlvdXM_");
    }

    // decodeTest
    {
        ubyte[1024] decoded;
        ubyte[] result = decode!(urlSafeDecodeTable)("V2h5IHNvIHNlcmlvdXM_", decoded);
        test!("==")(result, payload);
        result = decode!(urlSafeDecodeTable)("V2h5IHNvIHNlcmlvdXM_");
        test!("==")(result, payload);
    }
}
