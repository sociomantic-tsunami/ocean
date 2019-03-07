/*******************************************************************************

    Miscellaneous cryptographic padding functions

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.cipher.misc.Padding;


import ocean.transition;
import ocean.core.Verify;

version ( UnitTest )
{
    import ocean.core.Test;
}

/*******************************************************************************

    PKCS#7 padding.

    Pads the given byte buffer to the given length. The value of the padding
    byte is the same as the number of bytes added to the buffer, example:

    A 3-byte buffer with the contents [0xAB, 0xCD, 0xEF] is padded to length 8.
    The buffer will now contain [0xAB, 0xCD, 0xEF, 0x05, 0x05, 0x05, 0x05, 0x05]

    PKCS#7 padding is only defined for cases where the number of bytes to be
    padded is less than 256.

    Params:
        buffer = A reference to the buffer to pad
        pad_len = The length to pad the buffer to

    Returns:
        The padded buffer

*******************************************************************************/

ubyte[] padPKCS7 ( ref ubyte[] buffer, size_t pad_len )
{
    verify(pad_len >= buffer.length);
    verify(pad_len - buffer.length <= ubyte.max);

    enableStomping(buffer);

    ubyte pad_byte = cast(ubyte)(pad_len - buffer.length);

    size_t start = buffer.length;
    buffer.length = pad_len;
    buffer[start .. $] = pad_byte;

    return buffer;
}

unittest
{
    ubyte[] buf0;
    test!("==")(padPKCS7(buf0, 0), cast(ubyte[])null);
    test!("==")(padPKCS7(buf0, 1), cast(ubyte[])[1]);

    auto buf = cast(ubyte[])"YELLOW SUBMARINE".dup;
    auto padded = padPKCS7(buf, 20);
    auto expected = cast(ubyte[])"YELLOW SUBMARINE".dup ~ cast(ubyte[])[4, 4, 4, 4];
    test!("==")(padded, expected);
}

/*******************************************************************************

    PKCS#5 padding.

    Similar to PKCS#7 padding, except PKCS#5 padding is only defined for ciphers
    that use a block size of 8 bytes. Hence, the given buffer will be padded to
    a length of 8 bytes.

    Params:
        buffer = A reference to the buffer to pad

    Returns:
        The padded buffer

*******************************************************************************/

ubyte[] padPKCS5 ( ref ubyte[] buffer )
{
    verify(buffer.length <= 8);

    static immutable PKCS5_BLOCK_SIZE = 8;
    return padPKCS7(buffer, PKCS5_BLOCK_SIZE);
}

unittest
{
    ubyte[] buf0;
    test!("==")(padPKCS5(buf0), cast(ubyte[])[8, 8, 8, 8, 8, 8, 8, 8]);

    auto buf = cast(ubyte[])[0xAB, 0xCD, 0xEF];
    auto padded = padPKCS5(buf);
    auto expected = cast(ubyte[])[0xAB, 0xCD, 0xEF, 5, 5, 5, 5, 5];
    test!("==")(padded, expected);
}
