/*******************************************************************************

    D bindings to general libgcrypt functions.

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

module ocean.util.cipher.gcrypt.c.general;

public import ocean.util.cipher.gcrypt.c.libversion;

import ocean.transition;

extern (C):

/// See original's library documentation for details.
alias uint gcry_error_t;

/// See original's library documentation for details.
enum gcry_ctl_cmds
{
    GCRYCTL_CFB_SYNC = 3,
    GCRYCTL_RESET    = 4,
    GCRYCTL_FINALIZE = 5,
    GCRYCTL_GET_KEYLEN = 6,
    GCRYCTL_GET_BLKLEN = 7,
    GCRYCTL_TEST_ALGO = 8,
    GCRYCTL_IS_SECURE = 9,
    GCRYCTL_GET_ASNOID = 10,
    GCRYCTL_ENABLE_ALGO = 11,
    GCRYCTL_DISABLE_ALGO = 12,
    GCRYCTL_DUMP_RANDOM_STATS = 13,
    GCRYCTL_DUMP_SECMEM_STATS = 14,
    GCRYCTL_GET_ALGO_NPKEY    = 15,
    GCRYCTL_GET_ALGO_NSKEY    = 16,
    GCRYCTL_GET_ALGO_NSIGN    = 17,
    GCRYCTL_GET_ALGO_NENCR    = 18,
    GCRYCTL_SET_VERBOSITY     = 19,
    GCRYCTL_SET_DEBUG_FLAGS   = 20,
    GCRYCTL_CLEAR_DEBUG_FLAGS = 21,
    GCRYCTL_USE_SECURE_RNDPOOL= 22,
    GCRYCTL_DUMP_MEMORY_STATS = 23,
    GCRYCTL_INIT_SECMEM       = 24,
    GCRYCTL_TERM_SECMEM       = 25,
    GCRYCTL_DISABLE_SECMEM_WARN = 27,
    GCRYCTL_SUSPEND_SECMEM_WARN = 28,
    GCRYCTL_RESUME_SECMEM_WARN  = 29,
    GCRYCTL_DROP_PRIVS          = 30,
    GCRYCTL_ENABLE_M_GUARD      = 31,
    GCRYCTL_START_DUMP          = 32,
    GCRYCTL_STOP_DUMP           = 33,
    GCRYCTL_GET_ALGO_USAGE      = 34,
    GCRYCTL_IS_ALGO_ENABLED     = 35,
    GCRYCTL_DISABLE_INTERNAL_LOCKING = 36,
    GCRYCTL_DISABLE_SECMEM      = 37,
    GCRYCTL_INITIALIZATION_FINISHED = 38,
    GCRYCTL_INITIALIZATION_FINISHED_P = 39,
    GCRYCTL_ANY_INITIALIZATION_P = 40,
    GCRYCTL_SET_CBC_CTS = 41,
    GCRYCTL_SET_CBC_MAC = 42,
    GCRYCTL_ENABLE_QUICK_RANDOM = 44,
    GCRYCTL_SET_RANDOM_SEED_FILE = 45,
    GCRYCTL_UPDATE_RANDOM_SEED_FILE = 46,
    GCRYCTL_SET_THREAD_CBS = 47,
    GCRYCTL_FAST_POLL = 48,
    GCRYCTL_SET_RANDOM_DAEMON_SOCKET = 49,
    GCRYCTL_USE_RANDOM_DAEMON = 50,
    GCRYCTL_FAKED_RANDOM_P = 51,
    GCRYCTL_SET_RNDEGD_SOCKET = 52,
    GCRYCTL_PRINT_CONFIG = 53,
    GCRYCTL_OPERATIONAL_P = 54,
    GCRYCTL_FIPS_MODE_P = 55,
    GCRYCTL_FORCE_FIPS_MODE = 56,
    GCRYCTL_SELFTEST = 57,
    GCRYCTL_DISABLE_HWF = 63,
    GCRYCTL_SET_ENFORCED_FIPS_FLAG = 64,
    GCRYCTL_SET_PREFERRED_RNG_TYPE = 65,
    GCRYCTL_GET_CURRENT_RNG_TYPE = 66,
    GCRYCTL_DISABLE_LOCKED_SECMEM = 67,
    GCRYCTL_DISABLE_PRIV_DROP = 68,
    GCRYCTL_SET_CCM_LENGTHS = 69,
    GCRYCTL_CLOSE_RANDOM_DEVICE = 70,
    GCRYCTL_INACTIVATE_FIPS_FLAG = 71,
    GCRYCTL_REACTIVATE_FIPS_FLAG = 72,
    GCRYCTL_SET_SBOX = 73,
    GCRYCTL_DRBG_REINIT = 74,
    GCRYCTL_SET_TAGLEN = 75
}

/// See original's library documentation for details.
gcry_error_t gcry_control ( gcry_ctl_cmds CMD, ...);

// The function gcry_strerror returns a pointer to a statically allocated string
// containing a description of the error code contained in the error value err.
// This string can be used to output a diagnostic message to the user.
Const!(char)* gcry_strerror (gcry_error_t err);

// The function gcry_strsource returns a pointer to a statically allocated
// string containing a description of the error source contained in the error
// value err. This string can be used to output a diagnostic message to the user.
Const!(char)* gcry_strsource (gcry_error_t err);
