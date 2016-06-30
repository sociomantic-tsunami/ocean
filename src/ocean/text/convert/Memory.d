/*******************************************************************************

        Helper functions to format raw memory.

        Copyright:
            Copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
            Alternatively, this file may be distributed under the terms of the Tango
            3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.convert.Memory;



/******************************************************************************

    Imports

*******************************************************************************/

import ocean.text.convert.Format;



/******************************************************************************

        Print a range of raw memory as a hex dump.
        Characters in range 0x20..0x7E are printed, all others are
        shown as dots.

        ----
000000:  47 49 46 38  39 61 10 00  10 00 80 00  00 48 5D 8C  GIF89a.......H].
000010:  FF FF FF 21  F9 04 01 00  00 01 00 2C  00 00 00 00  ...!.......,....
000020:  10 00 10 00  00 02 11 8C  8F A9 CB ED  0F A3 84 C0  ................
000030:  D4 70 A7 DE  BC FB 8F 14  00 3B                     .p.......;
        ----

        Params:
            mem = buffer contaning the raw memory to format
            output = buffer where to put the formatted memory (if null, new
                     memory will be allocated)

        Return:
            string holding the formatted memory, will be the same buffer passed
            in as "output" if no re-allocation is necessary, otherwise new
            memory will be allocated.

******************************************************************************/

public char[] memoryToHexAscii ( void[] mem, char[] output = null )
{
    auto data = cast(ubyte[]) mem;

    for (size_t row = 0; row < data.length; row += 16)
    {
        // print relative offset
        Format.format(output, "{:X6}:  ", row);

        // print data bytes
        for (size_t idx = 0; idx < 16 ; idx++)
        {
            // print byte or stuffing spaces
            if (idx + row < data.length)
                Format.format(output, "{:X2} ", data[row + idx]);
            else
                Format.format(output, "{}", "   ");

            // after each 4 bytes group an extra space
            if ((idx & 0x03 ) == 3)
                Format.format(output, "{}", " ");
        }

        // ascii view
        // all char 0x20..0x7e are OK for printing,
        // other values are printed as a dot
        char[16] ascii = void;
        size_t idx;
        for (idx = 0; (idx<16) && (idx+row < data.length); idx++ )
        {
            ubyte c = data[row + idx];
            if (c < 0x20 || c > 0x7E)
                c = '.';
            ascii[idx] = c;
        }
        Format.format(output, "{}\n", ascii[0 .. idx]);
    }

    return output;
}

version (UnitTest)
{
    import ocean.core.Test;
}

unittest
{
    auto mem = cast(ubyte[]) "\x23\x00\xff";
    auto buf = memoryToHexAscii(mem);
    test!("==")(buf,
`000000:  23 00 FF                                            #..
`[]);

    buf.length = 0;
    buf = memoryToHexAscii(mem, buf);
    test!("==")(buf,
`000000:  23 00 FF                                            #..
`[]);

    buf.length = 0;
    mem ~= cast(ubyte[]) "hello world\x32\xf1";
    buf = memoryToHexAscii(mem, buf);
    test!("==")(buf,
`000000:  23 00 FF 68  65 6C 6C 6F  20 77 6F 72  6C 64 32 F1  #..hello world2.
`[]);

    buf.length = 0;
    mem ~= cast(ubyte[]) "bye bye world!\x10\x07\00\01";
    buf = memoryToHexAscii(mem, buf);
    test!("==")(buf,
`000000:  23 00 FF 68  65 6C 6C 6F  20 77 6F 72  6C 64 32 F1  #..hello world2.
000010:  62 79 65 20  62 79 65 20  77 6F 72 6C  64 21 10 07  bye bye world!..
000020:  00 01                                               ..
`[]);
}

