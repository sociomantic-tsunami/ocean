/*******************************************************************************

    The core of the libgcrypt key derivation classes.

    A key derivation function is a means of deriving a secret key from a secret
    value, for example a passphrase, using a salt and a pseudo-random function.

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

module ocean.util.cipher.gcrypt.core.KeyDerivationCore;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;
import ocean.util.cipher.gcrypt.c.kdf;
import ocean.util.cipher.gcrypt.c.md;

/*******************************************************************************

    Alias for the KDF algorithm

*******************************************************************************/

public alias gcry_kdf_algos KDF;

/*******************************************************************************

    Alias for the hashing function

*******************************************************************************/

public alias gcry_md_algos Hasher;

/*******************************************************************************

    Key derivation wrapper base class

    Params:
        algorithm = The KDF algorithm to use
        hasher = The pseudorandom hashing function to use

*******************************************************************************/

public class KeyDerivationCore ( KDF algorithm, Hasher hasher )
{
    import ocean.util.cipher.gcrypt.core.Gcrypt: GcryptException;

    /***************************************************************************

        The passphrase buffer

    ***************************************************************************/

    private Const!(ubyte)[] passphrase;

    /***************************************************************************

        The salt buffer

    ***************************************************************************/

    private Const!(ubyte)[] salt;

    /***************************************************************************

        Reusable exception

    ***************************************************************************/

    private GcryptException exception;

    /***************************************************************************

        Constructor

        Params:
            passphrase = The passphrase
            salt = The salt

    ***************************************************************************/

    public this ( in ubyte[] passphrase, in ubyte[] salt )
    {
        this.passphrase = passphrase;
        this.salt = salt;

        this.exception = new GcryptException();
    }

    /***************************************************************************

        Derive a key using the given number of iterations, store it in the
        given buffer. The length of the buffer must be the same as the expected
        length of the generated key.

        Params:
            iterations = The number of hashing iterations
            key_buf = The buffer to store the key in

        Returns:
            A slice to the key buffer

        Throws:
            GcryptException on internal Gcrypt error

    ***************************************************************************/

    public ubyte[] derive ( ulong iterations, ubyte[] key_buf )
    {
        auto error = gcry_kdf_derive(this.passphrase.ptr, this.passphrase.length,
            algorithm, hasher, this.salt.ptr, this.salt.length, iterations,
            key_buf.length, key_buf.ptr);

        this.exception.throwIfGcryptError(error);

        return key_buf;
    }
}
