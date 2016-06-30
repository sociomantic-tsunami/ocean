/*******************************************************************************

    Utility functions for converting hash_t <-> hexadecimal strings.

    A few different types of data are handled:
        * Hex strings: strings of variable length containing valid hexadecimal
          digits (case insensitive), optionally prepended by the hex radix
          specifier ("0x")
        * Hash digests: hex strings of exactly hash_t.sizeof * 2 digits
        * hash_t

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.convert.Hash;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import Integer = ocean.text.convert.Integer;

import ocean.core.TypeConvert;

static import ocean.text.convert.Hex;

version (UnitTest)
{
    import ocean.core.Test;
}


/*******************************************************************************

    Constant defining the number of hexadecimal digits needed to represent a
    hash_t.

*******************************************************************************/

public const HashDigits = hash_t.sizeof * 2;


/*******************************************************************************

    Converts from a hex string to a hash_t.

    Params:
        str = string to convert
        hash = output value to receive hex value, only set if conversion
            succeeds
        allow_radix = if true, the radix specified "0x" is allowed at the start
            of str

    Returns:
        true if the conversion succeeded

*******************************************************************************/

public bool toHashT ( cstring str, out hash_t hash,
    bool allow_radix = false )
{
    return ocean.text.convert.Hex.handleRadix(str, allow_radix,
        ( cstring str )
        {
            return Integer.toUlong(str, hash, 16);
        });
}

unittest
{
    static if ( HashDigits == 16 )
    {
        hash_t hash;

        // empty string
        test!("==")(toHashT("", hash), false);

        // just radix
        test!("==")(toHashT("0x", hash, true), false);

        // non-hex
        test!("==")(toHashT("zzz", hash), false);

        // integer overflow
        test!("==")(toHashT("12345678123456789", hash), false);

        // simple hash
        toHashT("12345678", hash);
        test!("==")(hash, 0x12345678);

        // hash with radix, disallowed
        test!("==")(toHashT("0x12345678", hash), false);

        // hash with radix, allowed
        toHashT("0x12345678", hash, true);
        test!("==")(hash, 0x12345678);
    }
    else
    {
        pragma(msg, "Warning: ocean.text.convert.Hash.toHashT unittest not run in 32-bit");
    }
}


/*******************************************************************************

    Converts from a hash digest (exactly HashDigits digits) to a hash_t.

    Params:
        str = string to convert
        hash = output value to receive hex value, only set if conversion
            succeeds
        allow_radix = if true, the radix specified "0x" is allowed at the start
            of str

    Returns:
        true if the conversion succeeded

*******************************************************************************/

public bool hashDigestToHashT ( cstring str, out hash_t hash,
    bool allow_radix = false )
{
    return ocean.text.convert.Hex.handleRadix(str, allow_radix,
        ( cstring str )
        {
            if ( str.length != HashDigits )
            {
                return false;
            }

            return Integer.toUlong(str, hash, 16);
        });
}

unittest
{
    static if ( HashDigits == 16 )
    {
        hash_t hash;

        // empty string
        test!("==")(hashDigestToHashT("", hash), false);

        // just radix
        test!("==")(hashDigestToHashT("0x", hash, true), false);

        // non-hex
        test!("==")(hashDigestToHashT("zzz", hash), false);

        // too short
        test!("==")(hashDigestToHashT("123456781234567", hash), false);

        // too short, with radix
        test!("==")(hashDigestToHashT("0x" ~ "123456781234567", hash, true), false);

        // too long
        test!("==")(hashDigestToHashT("12345678123456789", hash), false);

        // too long, with radix
        test!("==")(hashDigestToHashT("0x12345678123456789", hash, true), false);

        // just right
        hashDigestToHashT("1234567812345678", hash);
        test!("==")(hash, 0x1234567812345678);

        // just right with radix, disallowed
        test!("==")(hashDigestToHashT("0x1234567812345678", hash), false);

        // just right with radix, allowed
        hashDigestToHashT("0x1234567812345678", hash, true);
        test!("==")(hash, 0x1234567812345678);
    }
    else
    {
        pragma(msg, "Warning: ocean.text.convert.Hash.hashDigestToHashT unittest not run in 32-bit");
    }
}


/*******************************************************************************

    Creates a hash digest string from a hash_t.

    Params:
        hash = hash_t value to render to string
        str = destination string; length will be set to HashDigits

    Returns:
        string containing the hash digest

*******************************************************************************/

public mstring toHashDigest ( hash_t hash, ref mstring str )
{
    str.length = HashDigits;
    foreach_reverse ( ref c; str )
    {
        c = "0123456789abcdef"[hash & 0xF];
        hash >>= 4;
    }
    return str;
}

unittest
{
    mstring str;

    static if ( HashDigits == 16 )
    {
        test!("==")(toHashDigest(hash_t.min, str), "0000000000000000");
        test!("==")(toHashDigest(hash_t.max, str), "ffffffffffffffff");
    }
    else
    {
        test!("==")(toHashDigest(hash_t.min, str), "00000000");
        test!("==")(toHashDigest(hash_t.max, str), "ffffffff");
    }
}


/*******************************************************************************

    Checks whether str is a hash digest.

    Params:
        str = string to check
        allow_radix = if true, the radix specified "0x" is allowed at the start
            of str

    Returns:
        true if str is a hash digest

*******************************************************************************/

public bool isHashDigest ( cstring str, bool allow_radix = false )
{
    return ocean.text.convert.Hex.handleRadix(str, allow_radix,
        ( cstring str )
        {
            if ( str.length != HashDigits )
            {
                return false;
            }

            return ocean.text.convert.Hex.isHex(str);
        });
}

unittest
{
    static if ( HashDigits == 16 )
    {
        // empty string
        test!("==")(isHashDigest(""), false);

        // radix only, allowed
        test!("==")(isHashDigest("0x", true), false);

        // radix only, disallowed
        test!("==")(isHashDigest("0x"), false);

        // too short
        test!("==")(isHashDigest("123456781234567"), false);

        // too short, with radix
        test!("==")(isHashDigest("0x" ~ "123456781234567", true), false);

        // too long
        test!("==")(isHashDigest("12345678123456789"), false);

        // too long, with radix
        test!("==")(isHashDigest("0x" ~ "12345678123456789", true), false);

        // just right
        test!("==")(isHashDigest("1234567812345678"), true);

        // just right, with radix
        test!("==")(isHashDigest("0x1234567812345678", true), true);
    }
    else
    {
        pragma(msg, "Warning: ocean.text.convert.Hash.isHashDigest unittest not run in 32-bit");
    }
}
