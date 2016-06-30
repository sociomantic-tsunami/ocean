/*******************************************************************************

    D bindings to libgcrypt cryptograhic hash functions.

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

module ocean.util.cipher.gcrypt.c.md;

public import ocean.util.cipher.gcrypt.c.general;

import ocean.transition;

extern (C):

/// See original's library documentation for details.
enum gcry_md_algos
{
    GCRY_MD_NONE    = 0,
    GCRY_MD_MD5     = 1,
    GCRY_MD_SHA1    = 2,
    GCRY_MD_RMD160  = 3,
    GCRY_MD_MD2     = 5,
    GCRY_MD_TIGER   = 6,
    GCRY_MD_HAVAL   = 7,
    GCRY_MD_SHA256  = 8,
    GCRY_MD_SHA384  = 9,
    GCRY_MD_SHA512  = 10,
    GCRY_MD_SHA224  = 11,
    GCRY_MD_MD4     = 301,
    GCRY_MD_CRC32         = 302,
    GCRY_MD_CRC32_RFC1510 = 303,
    GCRY_MD_CRC24_RFC2440 = 304,
    GCRY_MD_WHIRLPOOL = 305,
    GCRY_MD_TIGER1  = 306,
    GCRY_MD_TIGER2  = 307
}

/// See original's library documentation for details.
enum gcry_md_flags
{
    GCRY_MD_FLAG_SECURE = 1,
    GCRY_MD_FLAG_HMAC   = 2
}

/// See original's library documentation for details.
struct gcry_md_handle;
/// See original's library documentation for details.
alias gcry_md_handle* gcry_md_hd_t;

/// See original's library documentation for details.
gcry_error_t gcry_md_open (gcry_md_hd_t* h, gcry_md_algos algo, gcry_md_flags flags);

/// See original's library documentation for details.
void gcry_md_close (gcry_md_hd_t hd);

/// See original's library documentation for details.
gcry_error_t gcry_md_enable (gcry_md_hd_t hd, gcry_md_algos algo);

/// See original's library documentation for details.
gcry_error_t gcry_md_copy (gcry_md_hd_t* bhd, gcry_md_hd_t ahd);

/// See original's library documentation for details.
void gcry_md_reset (gcry_md_hd_t hd);

/// See original's library documentation for details.
gcry_error_t gcry_md_ctl (gcry_md_hd_t hd, int cmd,
                          void* buffer, size_t buflen);

/// See original's library documentation for details.
void gcry_md_write (gcry_md_hd_t hd, Const!(void)* buffer, size_t length);

/// See original's library documentation for details.
ubyte* gcry_md_read (gcry_md_hd_t hd, gcry_md_algos algo = gcry_md_algos.init);

extern (D) ubyte[] gcry_md_read_slice (gcry_md_hd_t hd, gcry_md_algos algo = gcry_md_algos.init)
{
    if (ubyte* data = gcry_md_read(hd, algo))
    {
        return data[0 .. gcry_md_get_algo_dlen(algo? algo : gcry_md_get_algo(hd))];
    }
    else
    {
        return null;
    }
}

/// See original's library documentation for details.
void gcry_md_hash_buffer (gcry_md_algos algo, void* digest,
                          Const!(void)* buffer, size_t length);

/// See original's library documentation for details.
gcry_md_algos gcry_md_get_algo (gcry_md_hd_t hd);

/// See original's library documentation for details.
uint gcry_md_get_algo_dlen (gcry_md_algos algo);

/// See original's library documentation for details.
int gcry_md_is_enabled (gcry_md_hd_t a, gcry_md_algos algo);

/// See original's library documentation for details.
int gcry_md_is_secure (gcry_md_hd_t a);

/// See original's library documentation for details.
gcry_error_t gcry_md_info (gcry_md_hd_t h, gcry_ctl_cmds what, void* buffer,
                          size_t* nbytes);

/// See original's library documentation for details.
gcry_error_t gcry_md_algo_info (gcry_md_algos algo, gcry_ctl_cmds what, void* buffer,
                               size_t* nbytes);

/// See original's library documentation for details.
Const!(char)* gcry_md_algo_name (gcry_md_algos algo);

/// See original's library documentation for details.
int gcry_md_map_name (Const!(char)* name);

/// See original's library documentation for details.
gcry_error_t gcry_md_setkey (gcry_md_hd_t hd, Const!(void)* key, size_t keylen);

/// See original's library documentation for details.
void gcry_md_debug (gcry_md_hd_t hd, Const!(char)* suffix);


/// See original's library documentation for details.
extern (D) gcry_error_t gcry_md_test_algo(gcry_md_algos a)
{
    return gcry_md_algo_info(a, gcry_ctl_cmds.GCRYCTL_TEST_ALGO, null, null);
}

/// See original's library documentation for details.
extern (D) gcry_error_t gcry_md_get_asnoid(gcry_md_algos a, ref ubyte[] b)
{
    size_t len = b.length;

    if (auto error = gcry_md_algo_info(a, gcry_ctl_cmds.GCRYCTL_GET_ASNOID, b.ptr, &len))
    {
        return error;
    }
    else
    {
        b = b[0 .. len];
        return 0;
    }
}

/// See original's library documentation for details.
gcry_error_t gcry_md_list (int* list, int* list_length);
