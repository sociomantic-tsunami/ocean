/*******************************************************************************

    PBKDF2 key derivation wrapper.

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

module ocean.util.cipher.gcrypt.PBKDF2;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.cipher.gcrypt.core.KeyDerivationCore;

/*******************************************************************************

    PBKDF2 with SHA256 hashing wrapper class

    For a usage example, see the unittests below.

*******************************************************************************/

public alias KeyDerivationCore!(KDF.GCRY_KDF_PBKDF2, Hasher.GCRY_MD_SHA256) PBKDF2;

version ( UnitTest )
{
    import ocean.transition;
    import ocean.core.Test;
    import ocean.text.convert.Hex;
}

/// PBKDF2 usage example
unittest
{
    // Set up the passphrase and salt
    auto passphrase = cast(Immut!(ubyte)[])"passphrase";
    auto salt = cast(Immut!(ubyte)[])"salt";

    // Create the key derivation instance
    auto pbkdf2 = new PBKDF2(passphrase, salt);

    // The number of hashing iterations
    const ITERATIONS = 256;

    // The buffer to write the key to, set to the expected key length
    ubyte[] key_buf;
    key_buf.length = 32;

    // Derive the key
    auto key = pbkdf2.derive(ITERATIONS, key_buf);

    // The expected key is created so the output of pbkdf2 can be verified
    const EXPECTED_KEY = "1a0e45a1b7dd26f47b3549c56dca01df2fa27fa50ef799d9165db53b202fa267";
    ubyte[] expected_key;
    hexToBin(EXPECTED_KEY, expected_key);

    test!("==")(key, expected_key);
}
