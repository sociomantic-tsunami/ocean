/*******************************************************************************

    libgcrypt hash-based message authentication code generator utility class.

    Be aware that not all versions of libcgrypt support all hash algorithms; the
    constructor will throw if the specified algorithm is not supported by the
    run-time version of libgcrypt. However, if the constructor does not throw,
    it is safe to assume it will never throw for the same set of parameters
    (except for the fatal situation that libgcrypt failed allocating memory).

    Requires linking with libgcrypt:
            -L-lgcrypt

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.cipher.gcrypt.HMAC;

import ocean.util.cipher.gcrypt.core.MessageDigestCore;
import ocean.util.cipher.gcrypt.c.md;

/******************************************************************************/

public class HMAC: MessageDigestCore
{
    import ocean.util.cipher.gcrypt.core.Gcrypt: GcryptException;

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
                  string file = __FILE__, int line = __LINE__ )
    {
        super(algorithm, flags | flags.GCRY_MD_FLAG_HMAC, file, line);
    }

    /***************************************************************************

        Calculates the HMAC from the authentication key and the input data.

        Discards the result of a previous hash calculation, invalidating and
        overwriting a previously returned result.

        An error can be caused only by the parameters passed to the constructor.
        If this method does not throw, it is safe to assume it will never throw
        for the same set of constructor parameters.

        The length of the returned hash is the return value of
        `gcry_md_get_algo_dlen(algorithm)` for the algorithm passed to the
        constructor of this class.

        An empty `key` and/or empty `input_data` are tolerated.

        Params:
            key        = the HMAC key
            input_data = the data to hash, which will be concatenated

        Returns:
            the resuting HMAC.

        Throws:
            `GcryptException` on error.

    ***************************************************************************/

    public ubyte[] calculate (const(ubyte)[] key, const(ubyte)[][] input_data ... )
    {
        gcry_md_reset(this.md);

        if (key.length)
        {
            GcryptException.throwNewIfGcryptError(
                gcry_md_setkey(this.md, key.ptr, key.length)
            );
        }

        return this.calculate_(input_data);
    }
}

/******************************************************************************/

version (unittest)
{
    import ocean.core.Test;
}

unittest
{
    // https://tools.ietf.org/html/rfc4231#section-4.2
    static immutable(ubyte)[] sha224_hmac = [
        0x89, 0x6f, 0xb1, 0x12, 0x8a, 0xbb, 0xdf,
        0x19, 0x68, 0x32, 0x10, 0x7c, 0xd4, 0x9d,
        0xf3, 0x3f, 0x47, 0xb4, 0xb1, 0x16, 0x99,
        0x12, 0xba, 0x4f, 0x53, 0x68, 0x4b, 0x22
    ];

    immutable(ubyte)[20] key = 0x0b;
    scope hmacgen = new HMAC(gcry_md_algos.GCRY_MD_SHA224);
    test!("==")(
        hmacgen.calculate(
            key,
            cast(immutable(ubyte)[])"Hi",
            cast(immutable(ubyte)[])" ",
            cast(immutable(ubyte)[])"There"
        ),
        sha224_hmac
    );

    test!("==")(
        hmacgen.calculate(
            key,
            [
                cast(immutable(ubyte)[])"Hi",
                cast(immutable(ubyte)[])" ",
                cast(immutable(ubyte)[])"There"
            ]
        ),
        sha224_hmac
    );
}
