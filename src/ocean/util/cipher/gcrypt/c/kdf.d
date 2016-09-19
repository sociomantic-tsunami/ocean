/*******************************************************************************

    Bindings to key derivation functions.

    Requires linking with libgcrypt:
            -L-lgcrypt

    Copyright: Copyright (c) 2016 sociomantic labs. All rights reserved

*******************************************************************************/

module ocean.util.cipher.gcrypt.c.kdf;

import ocean.transition;

public import ocean.util.cipher.gcrypt.c.gpgerror;

extern (C):

/* Algorithm IDs for the KDFs.  */
enum gcry_kdf_algos
{
    GCRY_KDF_NONE = 0,
    GCRY_KDF_SIMPLE_S2K = 16,
    GCRY_KDF_SALTED_S2K = 17,
    GCRY_KDF_ITERSALTED_S2K = 19,
    GCRY_KDF_PBKDF1 = 33,
    GCRY_KDF_PBKDF2 = 34
}

/* Derive a key from a passphrase.  */
gpg_error_t gcry_kdf_derive (Const!(void)* passphrase, size_t passphraselen,
                             int algo, int subalgo, Const!(void)* salt,
                             size_t saltlen, ulong iterations,
                             size_t keysize, void* keybuffer);
