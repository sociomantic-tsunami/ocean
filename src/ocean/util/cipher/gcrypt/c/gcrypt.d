/*******************************************************************************

    D bindings to the libgcrypt library.

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

module ocean.util.cipher.gcrypt.c.gcrypt;

import ocean.transition;

public import ocean.util.cipher.gcrypt.c.general;

extern (C):

/// See original's library documentation for details.
gcry_error_t gcry_cipher_open (gcry_cipher_hd_t* hd, gcry_cipher_algos algo,
    gcry_cipher_modes mode, uint flags);

/// See original's library documentation for details.
void gcry_cipher_close (gcry_cipher_hd_t h);

/// See original's library documentation for details.
gcry_error_t gcry_cipher_setkey (gcry_cipher_hd_t h, Const!(void)* k, size_t l);

/// See original's library documentation for details.
gcry_error_t gcry_cipher_setiv (gcry_cipher_hd_t h, Const!(void)* k, size_t l);


/// See original's library documentation for details.
gcry_error_t gcry_cipher_encrypt (gcry_cipher_hd_t h, Const!(void)* out_,
    size_t outsize, Const!(void)* in_, size_t inlen);

/// See original's library documentation for details.
gcry_error_t gcry_cipher_decrypt (gcry_cipher_hd_t h, Const!(void)* out_,
    size_t outsize, Const!(void)* in_, size_t inlen);


/// See original's library documentation for details.
size_t gcry_cipher_get_algo_blklen (int algo);

/// See original's library documentation for details.
size_t gcry_cipher_get_algo_keylen (int algo);

/// See original's library documentation for details.
struct gcry_cipher_handle;
alias gcry_cipher_handle* gcry_cipher_hd_t;


/// See original's library documentation for details.
enum gcry_cipher_algos
{
    GCRY_CIPHER_NONE        = 0,
    GCRY_CIPHER_IDEA        = 1,
    GCRY_CIPHER_3DES        = 2,
    GCRY_CIPHER_CAST5       = 3,
    GCRY_CIPHER_BLOWFISH    = 4,
    GCRY_CIPHER_SAFER_SK128 = 5,
    GCRY_CIPHER_DES_SK      = 6,
    GCRY_CIPHER_AES         = 7,
    GCRY_CIPHER_AES192      = 8,
    GCRY_CIPHER_AES256      = 9,
    GCRY_CIPHER_TWOFISH     = 10,

    GCRY_CIPHER_ARCFOUR     = 301,
    GCRY_CIPHER_DES         = 302,
    GCRY_CIPHER_TWOFISH128  = 303,
    GCRY_CIPHER_SERPENT128  = 304,
    GCRY_CIPHER_SERPENT192  = 305,
    GCRY_CIPHER_SERPENT256  = 306,
    GCRY_CIPHER_RFC2268_40  = 307,
    GCRY_CIPHER_RFC2268_128 = 308,
    GCRY_CIPHER_SEED        = 309,
    GCRY_CIPHER_CAMELLIA128 = 310,
    GCRY_CIPHER_CAMELLIA192 = 311,
    GCRY_CIPHER_CAMELLIA256 = 312,
    GCRY_CIPHER_SALSA20     = 313,
    GCRY_CIPHER_SALSA20R12  = 314,
    GCRY_CIPHER_GOST28147   = 315,
    GCRY_CIPHER_CHACHA20    = 316
}

/// See original's library documentation for details.
enum gcry_cipher_modes
{
    GCRY_CIPHER_MODE_NONE     = 0,   /* Not yet specified. */
    GCRY_CIPHER_MODE_ECB      = 1,   /* Electronic codebook. */
    GCRY_CIPHER_MODE_CFB      = 2,   /* Cipher feedback. */
    GCRY_CIPHER_MODE_CBC      = 3,   /* Cipher block chaining. */
    GCRY_CIPHER_MODE_STREAM   = 4,   /* Used with stream ciphers. */
    GCRY_CIPHER_MODE_OFB      = 5,   /* Outer feedback. */
    GCRY_CIPHER_MODE_CTR      = 6,   /* Counter. */
    GCRY_CIPHER_MODE_AESWRAP  = 7,   /* AES-WRAP algorithm.  */
    GCRY_CIPHER_MODE_CCM      = 8,   /* Counter with CBC-MAC.  */
    GCRY_CIPHER_MODE_GCM      = 9,   /* Galois Counter Mode. */
    GCRY_CIPHER_MODE_POLY1305 = 10,  /* Poly1305 based AEAD mode. */
    GCRY_CIPHER_MODE_OCB      = 11   /* OCB3 mode.  */
}


