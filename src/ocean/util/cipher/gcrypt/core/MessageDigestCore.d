/*******************************************************************************

    The core of the libgcrypt message digest classes.

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

*******************************************************************************/

module ocean.util.cipher.gcrypt.core.MessageDigestCore;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

/******************************************************************************/

abstract class MessageDigestCore
{
    import ocean.util.cipher.gcrypt.c.md;
    import ocean.util.cipher.gcrypt.core.Gcrypt: GcryptException;

    /***************************************************************************

        libgcrypt message digest context object.

    ***************************************************************************/

    protected gcry_md_hd_t md;

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

    protected this ( gcry_md_algos algorithm, gcry_md_flags flags = cast(gcry_md_flags)0,
                     istring file = __FILE__, int line = __LINE__ )
    out
    {
        assert(this.md !is null);
    }
    body
    {
        // `gcry_md_open` sets `this.md = null` on failure.
        GcryptException.throwNewIfGcryptError(
            gcry_md_open(&this.md, algorithm, flags), file, line
        );
    }

    /***************************************************************************

        Destructor; closes the object opened by the constructor.

    ***************************************************************************/

    ~this ( )
    {
        // `gcry_md_close` ignores `null` so it is safe to call it after
        // `gcry_md_open()` failed and made the constructor throw.
        gcry_md_close(this.md);
        this.md = null;
    }

    /***************************************************************************

        Calculates the hash a.k.a. message digest from the input data.

        The length of the returned hash is the return value of
        `gcry_md_get_algo_dlen(algorithm)` for the algorithm passed to the
        constructor of this class.

        Params:
            input_data = data to hash; the elements will be concatenated

        Returns:
            the resuting hash.

    ***************************************************************************/

    protected ubyte[] calculate_ ( Const!(ubyte)[][] input_data )
    {
        foreach (chunk; input_data)
        {
            gcry_md_write(this.md, chunk.ptr, chunk.length);
        }

        return gcry_md_read_slice(this.md);
    }

    /***************************************************************************

        Calculates the hash a.k.a. message digest from the input data.

        The length of the returned hash is the return value of
        `gcry_md_get_algo_dlen(algorithm)` for the algorithm passed to the
        constructor of this class.

        Params:
            input_data = data to hash; the elements will be concatenated

        Returns:
            the resuting hash.

    ***************************************************************************/

    deprecated("use calculate_ instead")
    protected ubyte[] hash_ ( Const!(void)[][] input_data )
    {
        foreach (chunk; input_data)
        {
            gcry_md_write(this.md, chunk.ptr, chunk.length);
        }

        return gcry_md_read_slice(this.md);
    }
}
