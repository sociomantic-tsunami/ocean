/******************************************************************************

    CRC-32 generator, uses LZO's built-in CRC-32 calculator

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.io.compress.lzo.LzoCrc;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.io.compress.lzo.c.lzoconf: lzo_crc32, lzo_crc32_init;

import ocean.core.TypeConvert;

/******************************************************************************

    LzoCrc structure; contains only static methods

 ******************************************************************************/

struct LzoCrc
{
    static:

    /**************************************************************************

        Calculates a 32-bit CRC value from data.

        Params:
            crc32_in = initial 32-bit CRC value (for iteration)
            data     = data to calculate 32-bit CRC value of

        Returns:
            resulting 32-bit CRC value

    **************************************************************************/

    uint crc32 ( uint crc32_in, void[] data )
    {
        return lzo_crc32(crc32_in, cast (ubyte*) data.ptr,
            castFrom!(size_t).to!(int)(data.length));
    }

    /**************************************************************************

    Calculates a 32-bit CRC value from data.

    Params:
        data = data to calculate 32-bit CRC value of

    Returns:
        resulting 32-bit CRC value

    **************************************************************************/

    uint crc32 ( void[] data )
    {
        return crc32(lzo_crc32_init(), data);
    }
}
