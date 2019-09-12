/*******************************************************************************

    D bindings to libgcrypt version definition and run-time test functions.

    Requires linking with libgcrypt:

        -L-lgcrypt

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

        Bear in mind this module provides bindings to an external library that
        has its own license, which might be more restrictive. Please check the
        external library license to see which conditions apply for linking.

*******************************************************************************/

module ocean.util.cipher.gcrypt.c.libversion;

// The minimum version supported by the bindings
public string gcrypt_version = "1.5.0";

/*******************************************************************************

    Module constructor that insures that the used libgcrypt version is at least
    the same as the bindings was written for.

*******************************************************************************/

shared static this ( )
{
    if ( !gcry_check_version(gcrypt_version.ptr) )
    {
        throw new Exception("Version of libgcrypt is less than "~gcrypt_version);
    }
}

/// See original's library documentation for details.
extern (C) const(char)* gcry_check_version (const(char)* req_version);
