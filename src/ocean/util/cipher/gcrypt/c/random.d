/*******************************************************************************

    D bindings to libgcrypt random generating functions.

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

module ocean.util.cipher.gcrypt.c.random;

import ocean.util.cipher.gcrypt.c.general;

import ocean.transition;

extern (C):

/// See original's library documentation for details.
enum gcry_random_level
{
    GCRY_WEAK_RANDOM = 0,
    GCRY_STRONG_RANDOM = 1,
    GCRY_VERY_STRONG_RANDOM = 2
}


/// See original's library documentation for details.
void gcry_randomize (void* buffer, size_t length,
                     gcry_random_level level);

/// See original's library documentation for details.
gcry_error_t gcry_random_add_bytes (Const!(void)* buffer, size_t length,
                                    int quality = -1);

/// See original's library documentation for details.
gcry_error_t gcry_fast_random_poll ( )
{
    return gcry_control(gcry_ctl_cmds.GCRYCTL_FAST_POLL, null);
}


/// See original's library documentation for details.
void* gcry_random_bytes (size_t nbytes, gcry_random_level level);

/// See original's library documentation for details.
void* gcry_random_bytes_secure (size_t nbytes, gcry_random_level level);


/// See original's library documentation for details.
void gcry_create_nonce (void* buffer, size_t length);
