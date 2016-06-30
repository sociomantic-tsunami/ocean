/*******************************************************************************

    Wrapper to libgcrypt message digest and HMAC utility classes.

    Be aware that not all versions of libcgrypt support all hash algorithms; the
    `MessageDigest` constructor will throw if the specified algorithm is not
    supported by the run-time version of libgcrypt. However, if the constructor
    does not throw, it is safe to assume it will never throw for the same set of
    parameters (except for the fatal situation that libgcrypt failed allocating
    memory).

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

class MessageDigest
{
    import ocean.util.cipher.gcrypt.c.md;
    import ocean.util.cipher.gcrypt.core.Gcrypt: GcryptException;

    import ocean.transition;

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

    public this ( gcry_md_algos algorithm, gcry_md_flags flags = cast(gcry_md_flags)0 )
    out
    {
        assert(this.md !is null);
    }
    body
    {
        // `gcry_md_open` sets `this.md = null` on failure.
        throwIfGcryptError(gcry_md_open(&this.md, algorithm, flags));
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

    public ubyte[] hash ( Const!(void)[][] input_data ... )
    {
        gcry_md_reset(this.md);
        return this.hash_(input_data);
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

    protected ubyte[] hash_ ( Const!(void)[][] input_data )
    {
        foreach (chunk; input_data)
        {
            gcry_md_write(this.md, chunk.ptr, chunk.length);
        }

        return gcry_md_read_slice(this.md);
    }

    /***************************************************************************

        Throws `new GcryptException` if `error` is not 0.

        Params:
            error = non-zero error code or 0

        Throws:
            GcryptException if `error` is not 0.

    ***************************************************************************/

    protected static void throwIfGcryptError ( gcry_error_t error,
                                               istring file = __FILE__,
                                               int line = __LINE__ )
    {
        if (error)
        {
            (new GcryptException).throwIfGcryptError(error, file, line);
        }
    }
}

/******************************************************************************/

class HMAC: MessageDigest
{
    /***************************************************************************

        Constructor.

        Params:
            algorithm = the hash algorithm to use
            flags     = flags to `gcry_md_open()`; `flags.GCRY_MD_FLAG_HMAC` is
                        added automatically

        Throws:
            `GcryptException` on error, including the case that the run-time
            libgcrypt doesn't support `algorithm` for HMAC calculation.

    ***************************************************************************/

    public this ( gcry_md_algos algorithm, gcry_md_flags flags = cast(gcry_md_flags)0 )
    {
        super(algorithm, flags | flags.GCRY_MD_FLAG_HMAC);
    }

    /***************************************************************************

        Calculates the HMAC from the authentication key and the input data.

        Discards the result of a previous hash calculation, invalidating and
        overwriting a previously returned result.

        An error can be caused only by the parameters passed to the constructor.
        If this method does not throw, it is safe to assume it will never throw
        for the same set of constructor parameters.

        `key_and_input_data[0]` is expected to be the authentication key. If
        `key_and_input_data.length == 0` then an empty key and no data are used.

        The length of the returned hash is the return value of
        `gcry_md_get_algo_dlen(algorithm)` for the algorithm passed to the
        constructor of this class.

        Params:
            hmac_and_input_data = the first element is the HMAC key, the
                following the data to hash, which will be concatenated

        Returns:
            the resuting HMAC.

        Throws:
            `GcryptException` on error.

    ***************************************************************************/

    override public ubyte[] hash ( Const!(void)[][] key_and_input_data ... )
    {
        gcry_md_reset(this.md);

        if (key_and_input_data.length)
        {
            throwIfGcryptError(gcry_md_setkey(this.md,
                key_and_input_data[0].ptr, key_and_input_data[0].length
            ));
            return this.hash_(key_and_input_data[1 .. $]);
        }
        else
        {
            throwIfGcryptError(gcry_md_setkey(this.md, null, 0));
            return this.hash_(null);
        }
    }
}
