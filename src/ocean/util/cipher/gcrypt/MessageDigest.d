/*******************************************************************************

    Wrapper to libgcrypt message digest and HMAC utility classes.

    Be aware that not all versions of libcgrypt support all hash algorithms; the
    constructor will throw if the specified algorithm is not supported by the
    run-time version of libgcrypt. However, if the constructor does not throw,
    it is safe to assume it will never throw for the same set of parameters
    (except for the fatal situation that libgcrypt failed allocating memory).

    Requires linking with libgcrypt:
            -L-lgcrypt

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

        Bear in mind this module provides bindings to an external library that
        has its own license, which might be more restrictive. Please check the
        external library license to see which conditions apply for linking.

*******************************************************************************/

module ocean.util.cipher.gcrypt.MessageDigest;

import ocean.util.cipher.gcrypt.core.MessageDigestCore;
import ocean.transition;
import ocean.util.cipher.gcrypt.c.md;

/*******************************************************************************

    Message digest/hash generator.

*******************************************************************************/

public class MessageDigest: MessageDigestCore
{
    /***************************************************************************

        Constructor.

        Params:
            algorithm = the hash algorithm to use
            flags     = flags to `gcry_md_open()`

        Throws:
            `GcryptException` on error. There are two possible error causes:
              - The parameters are invalid or not supported by the libcrypt
                of the run-time enviromnent.
              - libgcrypt failed allocating memory.

    ***************************************************************************/

    public this ( gcry_md_algos algorithm, gcry_md_flags flags = cast(gcry_md_flags)0,
                     istring file = __FILE__, int line = __LINE__ )
    {
        super(algorithm, flags, file, line);
    }

    /***************************************************************************

        Calculates the hash a.k.a. message digest from the input data.

        Discards the result of a previous hash calculation, invalidating and
        overwriting a previously returned result.

        The length of the returned hash is the return value of
        `gcry_md_get_algo_dlen(algorithm)` for the algorithm passed to the
        constructor of this class.

        Params:
            input_data = data to hash; the elements will be concatenated

        Returns:
            the resuting hash.

    ***************************************************************************/

    public ubyte[] calculate ( Const!(ubyte)[][] input_data ... )
    {
        gcry_md_reset(this.md);
        return this.calculate_(input_data);
    }
}

/******************************************************************************/

version ( UnitTest )
{
    import ocean.core.Test;
}

unittest
{
    // http://csrc.nist.gov/groups/ST/toolkit/documents/Examples/SHA224.pdf
    static Immut!(ubyte)[] sha224_hash = [
        0x75, 0x38, 0x8B, 0x16, 0x51, 0x27, 0x76,
        0xCC, 0x5D, 0xBA, 0x5D, 0xA1, 0xFD, 0x89,
        0x01, 0x50, 0xB0, 0xC6, 0x45, 0x5C, 0xB4,
        0xF5, 0x8B, 0x19, 0x52, 0x52, 0x25, 0x25
    ];

    scope md = new MessageDigest(gcry_md_algos.GCRY_MD_SHA224);

    test!("==")(
        md.calculate(
            cast(Immut!(ubyte)[])"abcdbcdec",
            cast(Immut!(ubyte)[])"defdefgefghfghig",
            cast(Immut!(ubyte)[])"hi",
            cast(Immut!(ubyte)[])"jhijkijkljklmklmnlmnomno",
            cast(Immut!(ubyte)[])"pnopq"
        ),
        sha224_hash
    );

    test!("==")(
        md.calculate([
            cast(Immut!(ubyte)[])"abcdbcdec",
            cast(Immut!(ubyte)[])"defdefgefghfghig",
            cast(Immut!(ubyte)[])"hi",
            cast(Immut!(ubyte)[])"jhijkijkljklmklmnlmnomno",
            cast(Immut!(ubyte)[])"pnopq"
        ]),
        sha224_hash
    );
}
