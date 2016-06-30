/*****************************************************************************

    LZO library binding (lzo1x.h functions)

    Please consult the original header documentation for details.

    You need to have the library installed and link with -llzo2.

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

 *****************************************************************************/

module ocean.io.compress.lzo.c.lzo1x;


public import ocean.io.compress.lzo.c.lzoconf;


extern (C)
{

    /// See original documentation for details.
    LzoStatus lzo1x_1_compress ( in ubyte* src, size_t src_len,
                                 ubyte* dst, size_t * dst_len,
                                 void* wrkmem );

    /// See original documentation for details.
    LzoStatus lzo1x_decompress ( in ubyte* src, size_t src_len,
                           ubyte* dst, size_t* dst_len,
                           void* wrkmem = null /* NOT USED */ );

    /// See original documentation for details.
    LzoStatus lzo1x_decompress_safe ( in ubyte* src, size_t src_len,
                                ubyte* dst, size_t* dst_len,
                                void* wrkmem = null /* NOT USED */ );

}
