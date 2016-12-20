/*****************************************************************************

    LZO library binding (lzoconf.h functions)

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

 ******************************************************************************/

module ocean.io.compress.lzo.c.lzoconf;


extern (C)
{
    /**************************************************************************

        Status codes

     **************************************************************************/

    enum LzoStatus : int
    {
        OK                =  0, // LZO_E_OK
        Error             = -1, // LZO_E_ERROR
        OutOfMemory       = -2, // LZO_E_OUT_OF_MEMORY      [not used right now]
        NotCompressible   = -3, // LZO_E_NOT_COMPRESSIBLE   [not used right now]
        InputOverrun      = -4, // LZO_E_INPUT_OVERRUN
        OutputOverrun     = -5, // LZO_E_OUTPUT_OVERRUN
        LookBehindOverrun = -6, // LZO_E_LOOKBEHIND_OVERRUN
        EofNotFound       = -7, // LZO_E_EOF_NOT_FOUND
        InputNotConsumed  = -8, // LZO_E_INPUT_NOT_CONSUMED
        NotYetImplemented = -9 // LZO_E_NOT_YET_IMPLEMENTED [not used right now]
    }

    /**************************************************************************

        Working memory size

     **************************************************************************/

    const size_t Lzo1x1WorkmemSize = 16 * 1024 * (ubyte*).sizeof;

    /**************************************************************************

        Function type definitions

     **************************************************************************/

    alias int function ( ubyte* src, size_t src_len,
                         ubyte* dst, size_t* dst_len, void* wrkmem ) lzo_compress_t;

    alias int function ( ubyte* src, size_t src_len,
                         ubyte* dst, size_t* dst_len, void* wrkmem ) lzo_decompress_t;

    alias int function ( ubyte* src, size_t src_len,
                         ubyte* dst, size_t* dst_len, void* wrkmem ) lzo_optimize_t;

    alias int function ( ubyte* src, size_t src_len,
                         ubyte* dst, size_t* dst_len,
                         void* wrkmem, char* dict, size_t dict_len ) lzo_compress_dict_t;

    alias void* function ( lzo_callback_t* self, size_t items, size_t size ) lzo_alloc_func_t;

    alias void function ( lzo_callback_t* self, void* ptr ) lzo_free_func_t;

    alias void function ( lzo_callback_t*, size_t, size_t, int ) lzo_progress_func_t;

    /**************************************************************************

        lzo_callback_t structure

     **************************************************************************/

    struct lzo_callback_t
    {
        lzo_alloc_func_t    nalloc;
        lzo_free_func_t     nfree;
        lzo_progress_func_t nprogress;

        void* user1;
        size_t  user2;
        size_t user3;
    };

    /**************************************************************************

        Calculates an Adler-32 value from data in _buf.

        Params:
            _adler = initial Adler-32 value
            _buf   = data buffer
            _len   = data length

        Returns:
            resulting Adler-32 value

     **************************************************************************/

    uint lzo_adler32 ( uint _adler, ubyte* _buf, uint _len );

    /**************************************************************************

        Returns the library version number.

        Returns:
            library version number

     **************************************************************************/

    uint lzo_version ( );

    /**************************************************************************

        Initializes the library and informs it about the size of a variety of
        data types.

        Note that both "int" and "long" C datatypes correspond to "int" in D;
        D's "long" corresponds to C99's "long long".

        Params:
            ver               = supposed library version number
            sizeof_short      = short.sizeof
            sizeof_int        = int.sizeof
            sizeof_long       = int.sizeof
            sizeof_uint32     = uint.sizeof
            sizeof_uint       = uint.sizeof,
            sizeof_dict_t     = (ubyte*).sizeof
            sizeof_charp      = (char*).sizeof
            sizeof_voidp      = (void*).sizeof
            sizeof_callback_t = lzo_callback_t.sizeof

        Returns:
            LzoStatus.OK if the library feels that it is in a healty condition
            or something else if it is not well disposed today.

     **************************************************************************/

    private LzoStatus __lzo_init_v2( uint ver,
                                     int  sizeof_short,
                                     int  sizeof_int,
                                     int  sizeof_long,
                                     int  sizeof_uint32,
                                     int  sizeof_uint,
                                     int  sizeof_dict_t,    // ubyte*
                                     int  sizeof_charp,
                                     int  sizeof_voidp,
                                     int  sizeof_callback_t );

    /**************************************************************************

        Calculates a 32-bit CRC value from data in _buf.

        Params:
            _c   = initial 32-bit CRC value
            _buf = data buffer
            _len   = data length

        Returns:
            resulting 32-bit CRC value

    **************************************************************************/

    uint lzo_crc32   ( uint _c, in ubyte* _buf, uint _len );

    /**************************************************************************

        Returns the table of 32-bit CRC values of all byte values. The table has
        a length of 256.

        Returns:
            table of 32-bit CRC values of all byte values

    **************************************************************************/

    uint* lzo_get_crc32_table ( );
}

/******************************************************************************

    Calculates the maximum compressed length of data which has a length of
    uncompressed_length.

    Note: Surprisingly, this is more than uncompressed_length but that's the
          worst case for completely uncompressable data.

    Parameters:
        uncompressed_length = length of data to compressed

    Returns:
        maximum compressed length of data

 ******************************************************************************/

size_t lzo1x_max_compressed_length ( size_t uncompressed_length )
{
    return uncompressed_length + (uncompressed_length >> 4) + 0x40 + 3;
}

/******************************************************************************

    Returns the initial Adler-32 value to use with lzo_adler32().

    Returns:
        initial Adler-32 value

 ******************************************************************************/

uint lzo_adler32_init ( )
{
    return lzo_adler32(0, null, 0);
}

/**************************************************************************

    Initializes the library and informs it about the size of a variety of
    data types.

    Returns:
        LzoStatus.OK if the library feels that it is in a healty condition or
        something else if it is not well disposed today.

 **************************************************************************/

int lzo_init ( )
{
    return __lzo_init_v2(lzo_version(),
                         short.sizeof, int.sizeof, size_t.sizeof, uint.sizeof,size_t.sizeof,
                         (ubyte*).sizeof, (char*).sizeof, (void*).sizeof, lzo_callback_t.sizeof);
}

/******************************************************************************

    Returns the initial 32-bit CRC value to use with lzo_crc32().

    Returns:
        initial 32-bit CRC value

******************************************************************************/

uint lzo_crc32_init ( )
{
    return lzo_crc32(0, null, 0);
}

