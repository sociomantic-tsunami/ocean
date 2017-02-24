/******************************************************************************

    LZO1X-1 (Mini LZO) compressor/uncompressor

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.io.compress.Lzo;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.io.compress.lzo.c.lzo1x: lzo1x_1_compress,
                                      lzo1x_decompress, lzo1x_decompress_safe,
                                      lzo1x_max_compressed_length, lzo_init,
                                      Lzo1x1WorkmemSize, LzoStatus;

import ocean.io.compress.lzo.LzoCrc;

import ocean.io.compress.CompressException;

import ocean.core.Enforce: enforce;

import ocean.transition;

/******************************************************************************

    Lzo class

 ******************************************************************************/

class Lzo
{
    alias LzoCrc.crc32 crc32;

    /**************************************************************************

        Working memory buffer for lzo1x_1_compress()

     **************************************************************************/

    private void[] workmem;

    /**************************************************************************

        Static constructor

        Throws:
            CompressException if the library pouts

     **************************************************************************/

    static this ( )
    {
        enforce!(CompressException)(!lzo_init(), "Lzo kaputt");
    }

    /**************************************************************************

        Constructor

     **************************************************************************/

    public this ( )
    {
        this.workmem = new ubyte[Lzo1x1WorkmemSize];
    }

    /**************************************************************************

        Compresses src data. dst must have a length of at least
        maxCompressedLength(src.length).

        Params:
            src = data to compress
            dst = compressed data destination buffer

        Returns:
            length of compressed data in dst

        Throws:
            CompressionException on error

     **************************************************************************/

    size_t compress ( in void[] src, void[] dst )
    in
    {
        assert (dst.length >= this.maxCompressedLength(src.length), typeof (this).stringof ~ ".compress: dst buffer too short");
    }
    body
    {
        size_t len;

        this.checkStatus(lzo1x_1_compress(cast (Const!(ubyte)*) src.ptr, src.length, cast (ubyte*) dst.ptr, &len, this.workmem.ptr));

        return len;
    }

    /**************************************************************************

        Uncompresses src data. dst must have at least the length of the
        uncompressed data, which must be memorized at compression time.

        Note: dst overflow checking is NOT done!

        Params:
            src = data to uncompress
            dst = uncompressed data destination buffer

        Returns:
            length of uncompressed data in dst

        Throws:
            CompressionException on error

     **************************************************************************/

    size_t uncompress ( in void[] src, void[] dst )
    {
        size_t len;

        this.checkStatus(lzo1x_decompress(cast (Const!(ubyte)*) src.ptr, src.length, cast (ubyte*) dst.ptr, &len));

        return len;
    }

    /**************************************************************************

        Uncompresses src data, checking for dst not to overflow.

        Params:
            src = data to uncompress
            dst = uncompressed data destination buffer

        Returns:
            length of uncompressed data in dst

        Throws:
            CompressionException on error

     **************************************************************************/

    size_t decompressSafe ( in void[] src, void[] dst )
    {
        size_t len;

        this.checkStatus(lzo1x_decompress_safe(cast (Const!(ubyte)*) src.ptr, src.length, cast (ubyte*) dst.ptr, &len));

        return len;
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

    static size_t maxCompressedLength ( size_t uncompressed_length )
    {
        return lzo1x_max_compressed_length(uncompressed_length);
    }

    /**************************************************************************

        Checks if status indicates an error.

        Params:
            status = LZO library function return status

        Throws:
            resulting 32-bit CRC value

     **************************************************************************/

    static void checkStatus ( LzoStatus status )
    {
        switch (status)
        {
            case LzoStatus.Error:
                throw new CompressException(typeof (this).stringof ~ ": Error");

            case LzoStatus.OutOfMemory:
                throw new CompressException(typeof (this).stringof ~ ": Out Of Memory");

            case LzoStatus.NotCompressible:
                throw new CompressException(typeof (this).stringof ~ ": Not Compressible");

            case LzoStatus.InputOverrun:
                throw new CompressException(typeof (this).stringof ~ ": Input Overrun");

            case LzoStatus.OutputOverrun:
                throw new CompressException(typeof (this).stringof ~ ": Output Overrun");

            case LzoStatus.LookBehindOverrun:
                throw new CompressException(typeof (this).stringof ~ ": Look Behind Overrun");

            case LzoStatus.EofNotFound:
                throw new CompressException(typeof (this).stringof ~ ": Eof Not Found");

            case LzoStatus.InputNotConsumed:
                throw new CompressException(typeof (this).stringof ~ ": Input Not Consumed");

            case LzoStatus.NotYetImplemented:
                throw new CompressException(typeof (this).stringof ~ ": Not Yet Implemented");

            default:
                return;
        }
    }

    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Destructor

        ***********************************************************************/

        override void dispose ( )
        {
            delete this.workmem;
        }
    }
}

/******************************************************************************

    Unit test

    Add -debug=GcDisabled to the compiler command line to disable the garbage
    collector.

    Note: The unit test requires a file named "lzotest.dat" in the current
    working directory at runtime. This file provides the data to be compressed
    for testing and performance measurement.

 ******************************************************************************/

version (UnitTest):

// Uncomment the next line to see UnitTest output
// version = UnitTestVerbose;

import ocean.io.device.File;
import ocean.time.StopWatch;

debug (GcDisabled) import ocean.core.Memory;

import ocean.text.util.MetricPrefix;

import core.stdc.signal: signal, SIGINT;

/******************************************************************************

    Rounds x to the nearest integer value

    Params:
        x = value to round

    Returns:
        nearest integer value of x

 ******************************************************************************/

extern (C) int lrintf ( float x );

/******************************************************************************

    Terminator structure

 ******************************************************************************/

struct Terminator
{
    static:

    /**************************************************************************

        Termination flag

     **************************************************************************/

    bool terminated = false;

    /**************************************************************************

        Signal handler; raises the termination flag

     **************************************************************************/

    version (D_Version2)
    {
        mixin(`
        extern (C) void terminate ( int code ) nothrow @nogc
        {
            Terminator.terminated = true;
        }
        `);
    }
    else
    {
        extern (C) void terminate ( int code )
        {
            Terminator.terminated = true;
        }
    }
}

version (UnitTestVerbose) import ocean.io.Stdout;

unittest
{
    debug (GcDisabled)
    {
        version (UnitTestVerbose) Stdout.formatln("LZO unittest: garbage collector disabled");
        GC.disable();
    }

    StopWatch swatch;

    MetricPrefix pre_comp_sz, pre_uncomp_sz,
                 pre_comp_tm, pre_uncomp_tm, pre_crc_tm;

    version (UnitTestVerbose) Stdout.formatln("LZO unittest: loading test data from file \"lzotest.dat\"");

    // FLAKEY: Avoid IO in unittests and specially fixed file names
    File file;

    try file = new File("lzotest.dat");
    catch (Exception e)
    return;

    scope data         = new void[file.length];
    scope uncompressed = new void[file.length];
    scope compressed   = new void[Lzo.maxCompressedLength(data.length)];
    scope lzo          = new Lzo;

    file.read(data);

    file.close();

    version (UnitTestVerbose) Stdout.formatln("LZO unittest: loaded {} bytes of test data, compressing...", data.length);

    swatch.start();

    compressed.length = lzo.compress(data, compressed);

    ulong compr_us = swatch.microsec;

    size_t uncompr_len = lzo.uncompress(compressed, uncompressed);

    ulong uncomp_us = swatch.microsec;

    uint crc32_data = lzo.crc32(data);

    ulong crc_us = swatch.microsec;

    assert (uncompr_len == data.length,            "uncompressed data length mismatch");
    assert (uncompressed == data,                  "uncompressed data mismatch");
    assert (lzo.crc32(uncompressed) == crc32_data, "uncompressed data CRC-32 mismatch");

    crc_us    -= uncomp_us;
    uncomp_us -= compr_us;

    pre_comp_sz.bin(compressed.length);
    pre_uncomp_sz.bin(uncompressed.length);

    pre_comp_tm.dec(compr_us, -2);
    pre_uncomp_tm.dec(uncomp_us, -2);
    pre_crc_tm.dec(crc_us, -2);

    version (UnitTestVerbose)
        Stdout.formatln("LZO unittest results:\n\t"
                 ~ "uncompressed length: {} {}B\t({} bytes)\n\t"
                 ~ "compressed length:   {} {}B\t({} bytes)\n\t"
                 ~ "compression ratio:   {}%\n\t"
                 ~ "compression time:    {} {}s\t({} µs)\n\t"
                 ~ "uncompression time:  {} {}s\t({} µs)\n\t"
                 ~ "CRC-32 time:         {} {}s\t({} µs)\n\t"
                 ~ "CRC-32 (uncompr'd):  0x{:X8}\n"
                 ~ "\n"
                 ~ "LZO unittest: Looping for memory leak detection; "
                 ~ "watch memory usage and press Ctrl+C to quit",
                   pre_uncomp_sz.scaled, pre_uncomp_sz.prefix, uncompressed.length,
                   pre_comp_sz.scaled, pre_comp_sz.prefix, compressed.length,
                   lrintf((compressed.length * 100.f) / uncompressed.length),
                   pre_comp_tm.scaled, pre_comp_tm.prefix, compr_us,
                   pre_uncomp_tm.scaled, pre_uncomp_tm.prefix, uncomp_us,
                   pre_crc_tm.scaled, pre_crc_tm.prefix, crc_us,
                   crc32_data);

    auto prev_sigint_handler = signal(SIGINT, &Terminator.terminate);

    scope (exit) signal(SIGINT, prev_sigint_handler);

    while (!Terminator.terminated)
    {
        compressed.length = Lzo.maxCompressedLength(data.length);

        compressed.length =  lzo.compress(data, compressed);

        lzo.uncompress(compressed, uncompressed);
    }
}
