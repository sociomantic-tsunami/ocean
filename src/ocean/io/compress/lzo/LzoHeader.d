/******************************************************************************

    Generates and reads headers of chunks of compressed data, containing the
    data length, compression type and checksum

    There are two header versions:
        1. the regular LzoHeader,
        2. the Null header which has the same meaning as a Stop header.

    LzoHeader data layout if size_t has a width of 32-bit:
        void[16] header

            header[0  ..  4] - length of chunk[4 .. $] (or compressed data
                               length + header length - 4)
            header[4 ..   8] - 32-bit CRC value of following header elements and
                               compressed data (chunk[8 .. $]), calculated using
                               lzo_crc32()
            header[8  .. 12] - chunk/compression type code (signed integer)
            header[12 .. 16] - length of uncompressed data (may be 0)


    Null header data layout if size_t has a width of 32-bit:
        void[4] null_header

            header[0  ..  4] - all bytes set to value 0

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.io.compress.lzo.LzoHeader;

import ocean.io.compress.lzo.LzoCrc;

import ocean.io.compress.CompressException;

import ocean.core.Enforce: enforce;

version (UnitTestVerbose) import ocean.io.Stdout : Stderr;

/******************************************************************************

    LzoHeader structure

 ******************************************************************************/

align (1) struct LzoHeader ( bool LengthInline = true )
{
    /**************************************************************************

        Length of the chunk excluding this length value

        The default value is that of a payload-less chunk (start/stop chunk).

        "length" constant is defined below

     **************************************************************************/

    size_t chunk_length = length - size_t.sizeof;

    /**************************************************************************

        CRC32 of following header elements and compressed data

     **************************************************************************/

    private uint crc32_;

    /**************************************************************************

        Chunk type (Type enumerator is defined below)

     **************************************************************************/

    Type type = Type.None;

    /**************************************************************************

        Length of uncompressed data

     **************************************************************************/

    size_t uncompressed_length = 0;

    /**************************************************************************

        Error message source constant

     **************************************************************************/

    const ErrMsgSource = typeof (*this).stringof;

    /**************************************************************************

        Header type enumerator

     **************************************************************************/

    enum Type : int
    {
        Stop  = 0,

        None,
        LZO1X,

        Start = -1,

    }

    /**************************************************************************

        Total data length of the members of this structure. With "align (1)"
        as structure definition attribute "length" equals the "sizeof" value
        since the member data are then packed without padding.
        Because this structure represents the LZO chunk header data
        elements, "length" must equal "sizeof" in order to generate the
        correct LZO chunk header by serializing an instance of this
        structure. Hence "length == sizeof" is checked at ccompile-time
        in write().

        TODO: read_length

     **************************************************************************/

        public static size_t length ( )
        {
            return LzoHeader.sizeof;
        }

        //static assert (length == typeof (this).sizeof);

        static if ( LengthInline )
        {
            const read_length = length;
        }
        else
        {
            const read_length = length - size_t.sizeof;
        }

        /**************************************************************************

            Writes the header to chunk[0 .. this.read_length].

            Params:
                chunk = chunk without header

            Returns:
                chunk (passed through)

            Throws:
                CompressException if chunk is shorter than this.read_length

         **************************************************************************/

        void[] write ( void[] chunk )
        {
            static assert ((*this).sizeof == SizeofTuple!(typeof (this.tupleof)),
                           this.ErrMsgSource ~ ": Bad data alignment");

            enforce!(CompressException)(chunk.length >= this.read_length,
                                         this.ErrMsgSource ~ ": Chunk too short to write header");

            this.chunk_length = chunk.length - this.chunk_length.sizeof;

            this.crc32_ = this.crc32(this.strip(chunk));

            *(cast (typeof (this)) chunk.ptr) = *this;

            return chunk;
        }

        /**************************************************************************

            Sets this instance to create a header for a chunk containing
            uncompressed data. Compression method is set to None.

            Params:
                payload = data to create header for

            Returns:
                this instance

            Throws:
                CompressException if chunk is shorter than this.read_length

         **************************************************************************/

        typeof (this) uncompressed ( void[] payload )
        {
            this.type = this.type.None;

            this.uncompressed_length = payload.length;

            this.chunk_length += payload.length;

            this.crc32_ = this.crc32(payload);

            return this;
        }

        /**************************************************************************

            Sets this instance to create a Start header. Since a Start chunk has no
            payload, the returned data are a full Start chunk.

            Params:
                total_uncompressed_length = total uncompressed length of data
                                            contained in the following chunks

            Returns:
                this instance

         **************************************************************************/

        typeof (this) start ( size_t total_uncompressed_length )
        {
            *this = typeof (*this).init;

            this.type = this.type.Start;

            this.uncompressed_length = total_uncompressed_length;

            this.crc32_ = this.crc32();

            return this;
        }

        /**************************************************************************

            Sets this instance to create a Stop header. Since a Stop chunk has no
            payload, the returned data are a full Start chunk.

            Returns:
                this instance

         **************************************************************************/

        typeof (this) stop ( )
        {
            *this = typeof (*this).init;

            this.type = this.type.Stop;

            this.crc32_ = this.crc32();

            return this;
        }

        /**************************************************************************

            Reads chunk which is expected to be a Start chunk or a Null chunk.

            After chunk has been read, this.type is either set to Start, if the
            provided chunk was a start chunk, or to Stop for a Null chunk.
            this.uncompressed_size reflects the total uncompressed size of the data
            in the chunks that will follow.

            Params:
                chunk = input chunk

            Throws:
                CompressException if chunk is neither a Start chunk, as expected,
                nor a Null chunk

         **************************************************************************/

        typeof (this) readStart ( void[] chunk )
        {
            this.read(chunk);

            enforce!(CompressException)(this.type == Type.Start || this.type == Type.Stop,
                                         this.ErrMsgSource ~ ": Not a Start header as expected");

            return this;
        }

        /**************************************************************************

            Checks whather chunk is valid or not. If it is valid this object's data
            members are initialised with the chunk header info.

            Params:
                chunk = input chunk

            Returns:
                true if the chunk is valid

         **************************************************************************/

        bool tryRead ( void[] chunk )
        {
            if ( chunk.length >= this.read_length )
            {
                if (this.isNullChunk(chunk))
                {
                    this.stop();
                    return true;
                }
                else
                {
                    this.setHeader(chunk);
                    auto payload = this.strip(chunk);
                    return this.crc32_ == this.crc32(payload);
                }
            }

            return false;
        }

        /**************************************************************************

            Checks whether chunk is a Stop / Null chunk. This data members are set
            from the chunk provided.

            Params:
                chunk = input chunk

             Returns:
                true if chunk is a Stop or Null chunk

         **************************************************************************/

        bool tryReadStop ( void[] chunk )
        {
            return tryReadType(chunk, Type.Stop, true);
        }

        /**************************************************************************

            Checks whether chunk is a Start / Null chunk. This data members are set
            from the chunk provided.

            Params:
                chunk = input chunk

             Returns:
                true if chunk is a Start or Null chunk

         **************************************************************************/

        bool tryReadStart ( void[] chunk )
        {
            return tryReadType(chunk, Type.Start, true);
        }

        /**************************************************************************

            Returns the header data of this instance.

            Returns:
                header data of this instance

         **************************************************************************/

        void[] data ( )
        {
            return (cast (void*) this)[0 .. this.read_length];
        }

        /**************************************************************************

            Returns the header data of tihs instance without the leading chunk
            length value.

            Returns:
                header data of tihs instance without the leading chunk length value

         **************************************************************************/

        void[] data_without_length ( )
        {
            return (cast (void*) this)[size_t.sizeof .. this.read_length];
        }

        /**************************************************************************

            Reads the header from chunk and sets the members of this instance to
            the values contained in the header.

            Params:
                chunk = chunk with header (or Null chunk)

            Returns:
                payload from chunk (with header data stripped)

            Throws:
                CompressException if chunk is shorter than this.read_length

         **************************************************************************/

        void[] read ( void[] chunk )
        {
            void[] payload = null;

            if (this.isNullChunk(chunk))
            {
                this.stop();
            }
            else
            {
                this.setHeader(chunk);

                payload = this.strip(chunk);

                enforce!(CompressException)(this.lengthValid(chunk),
                                         this.ErrMsgSource ~ ": Chunk length mismatch");

                enforce!(CompressException)(this.crc32_ == this.crc32(payload),
                                             this.ErrMsgSource ~ ": Chunk data corrupted (CRC32 mismatch)");
            }

            return payload;
        }

        /**************************************************************************

            Checks whether the chunk_length member is correct for the given chunk.

            Params:
                chunk = chunk to check (with header)

            Returns:
                true if the length of chunk corresponds to the chunk_length member

         **************************************************************************/

        size_t lengthValid ( void[] chunk )
        {
            static if ( LengthInline )
            {
                return chunk.length == this.chunk_length + this.chunk_length.sizeof;
            }
            else
            {
                return chunk.length == this.chunk_length;
            }
        }

        /**************************************************************************

             Sets the internal data members from the given chunk.

             Params:
                 chunk = data to read from

            Returns:
                this

         **************************************************************************/

        typeof(this) setHeader ( void[] chunk )
        {
            static if ( LengthInline )
            {
                *this = *cast (typeof (this)) chunk.ptr;
            }
            else
            {
                this.chunk_length = chunk.length;

                void* read_ptr = chunk.ptr;
                this.crc32_ = *(cast(typeof(this.crc32_)*) read_ptr);
                read_ptr += this.crc32_.sizeof;
                this.type = *(cast(typeof(this.type)*) read_ptr);
                read_ptr += this.type.sizeof;
                this.uncompressed_length = *(cast(typeof(this.uncompressed_length)*) read_ptr);
            }

            return this;
        }

        /**************************************************************************

            Calculates the CRC32 value of the header elements after crc32.

         **************************************************************************/

        uint crc32 ( void[] payload = null )
        {
            uint crc32 = LzoCrc.crc32((cast (void*) this)[this.crc32_.offsetof + this.crc32_.sizeof .. this.length]);

            if (payload)
            {
                crc32 = LzoCrc.crc32(crc32, payload);
            }

            return crc32;
        }

        /**************************************************************************

            Reads chunk which is expected to be of the specified type, or optionally
            a Null chunk; does not throw an exception if the chunk header is invalid
            or not of the specified types but returns false instead.

            After chunk has been read, this.type is either set to the specified
            type, if the provided chunk was of that type, or to Stop for a Null
            chunk.

            this.uncompressed_size reflects the total uncompressed size of the data
            in the chunks that will follow.

            Params:
                chunk = input chunk

             Returns:
                true if chunk is of the specified type, as expected, or a Null
                chunk, or false otherwise

         **************************************************************************/

        private bool tryReadType ( void[] chunk, Type check_type, bool allow_null )
        {
            bool validated = false;

            if (allow_null && this.isNullChunk(chunk))
            {
                this.stop();

                validated = true;
            }
            else if (chunk.length == this.read_length)
            {
                this.setHeader(chunk);

                if (this.type == check_type)
                {
                    static if ( LengthInline )
                    {
                        if (chunk.length == this.chunk_length + this.chunk_length.sizeof)
                        {
                            validated = this.crc32_ == this.crc32;
                        }
                    }
                    else
                    {
                        validated = this.crc32_ == this.crc32;
                    }
                }
            }

            return validated;
        }

        /**************************************************************************

            Strips the header from chunk

            Params:
                chunk = chunk with header (must not be a Null chunk)

            Returns:
                chunk payload, that is, the chunk data without header (slice)

            Throws:
                CompressException if chunk.length is shorter than LzoHeader
                data

         **************************************************************************/

        static void[] strip ( void[] chunk )
        {
            enforce!(CompressException)(chunk.length >= read_length,
                                         ErrMsgSource ~ ": Chunk too short to strip header");

            return chunk[read_length .. $];
        }

        /**************************************************************************

            Checks whether chunk is a Null chunk, that is, it has a Null header. A
            Null header is defined as
                                                                                 ---
                void[size_t.sizeof] null_header;
                null_header[] = 0;
                                                                                 ---

            Since no payload can be follow a Null header, a Null header is a
            complete chunk on itself, that is the Null chunk.

            Params:
                chunk = input chunk

            Returns:
                true if chunk is a Null chunk or false otherwise.

         **************************************************************************/

        static bool isNullChunk ( void[] chunk )
        {
            static if ( LengthInline )
            {
                return (chunk.length == size_t.sizeof)? !*cast (size_t*) chunk.ptr : false;
            }
            else
            {
                return chunk.length == 0;
            }
        }
}

    /******************************************************************************

        Calculates the sum of the sizes of the types of T

     ******************************************************************************/

template SizeofTuple ( T ... )
{
    static if (T.length > 1)
    {
        const SizeofTuple = T[0].sizeof + SizeofTuple!(T[1 .. $]);
    }
    else static if (T.length == 1)
    {
        const SizeofTuple = T[0].sizeof;
    }
    else
    {
        const size_t SizeofTuple = 0;
    }
}

/******************************************************************************

    Unit test

    Add -debug=GcDisabled to the compiler command line to disable the garbage
    collector.

 ******************************************************************************/


version (UnitTest):

import ocean.io.Stdout : Stderr;

import ocean.time.StopWatch;

import ocean.text.util.MetricPrefix;

debug (GcDisabled) import ocean.core.Memory;

import ocean.stdc.signal: signal, SIGINT;

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

unittest
{
    // Uncomment the next line to see UnitTest output
    // version = UnitTestVerbose;

    debug (GcDisabled)
    {
        pragma (msg, "LzoHeader unittest: garbage collector disabled");
        GC.disable();
    }

    StopWatch swatch;

    LzoHeader!() header;

    const N = 1000;

    ubyte[header.sizeof][N] start_header_data, stop_header_data;

    const C = 10;

    scope chunks4k  = new void[][](C, 4 * 1024);
    scope chunks64k = new void[][](C, 64 * 1024);
    scope chunks1M  = new void[][](C, 1024 * 1024);

    foreach (ref chunk; chunks4k)
    {
        (cast (char[]) chunk)[] = 'A';
    }

    foreach (ref chunk; chunks64k)
    {
        (cast (char[]) chunk)[] = 'B';
    }

    foreach (ref chunk; chunks1M)
    {
        (cast (char[]) chunk)[] = 'C';
    }

    swatch.start();

    for (uint i = 0; i < N; i++)
    {
        start_header_data[i][] = cast (ubyte[]) header.start(4 * 1024).data;
    }

    ulong us_start = swatch.microsec();

    for (uint i = 0; i < N; i++)
    {
        stop_header_data[i][] = cast (ubyte[]) header.stop().data;
    }

    ulong us_stop = swatch.microsec();

    for (uint i = 0; i < N; i++)
    {
        header.tryReadStart(start_header_data[i]);
    }

    ulong us_try_read_start = swatch.microsec();

    for (uint i = 0; i < N; i++)
    {
        header.readStart(start_header_data[i]);
    }

    ulong us_read_start = swatch.microsec();

    for (uint i = 0; i < C; i++)
    {
        header.write(chunks4k[i]);
    }

    ulong us_write4k = swatch.microsec();

    for (uint i = 0; i < C; i++)
    {
        header.write(chunks64k[i]);
    }

    ulong us_write64k = swatch.microsec();

    for (uint i = 0; i < C; i++)
    {
        header.write(chunks1M[i]);
    }

    ulong us_write1M = swatch.microsec();

    for (uint i = 0; i < C; i++)
    {
        header.read(chunks4k[i]);
    }

    ulong us_read4k = swatch.microsec();

    for (uint i = 0; i < C; i++)
    {
        header.read(chunks64k[i]);
    }

    ulong us_read64k = swatch.microsec();

    for (uint i = 0; i < C; i++)
    {
        header.read(chunks1M[i]);
    }

    ulong us_read1M = swatch.microsec();

    us_read1M         -= us_read64k;
    us_read64k        -= us_read4k;
    us_read4k         -= us_write1M;
    us_write1M        -= us_write64k;
    us_write64k       -= us_write4k;
    us_write4k        -= us_read_start;
    us_read_start     -= us_try_read_start;
    us_try_read_start -= us_stop;
    us_stop           -= us_start;

    version (UnitTestVerbose)  Stderr.formatln("LzoHeader unittest results:\n\t"
                   "start():        1000 headers generated within {} ms\n\t"
                   "stop():         1000 headers generated within {} ms\n\t"
                   "tryReadStart(): 1000 headers checked   within {} ms\n\t"
                   "readStart():    1000 headers checked   within {} ms\n\t"
                   "\n\t"
                   "write(): 10 chunks of  4 kB each written within {} ms\n\t"
                   "write(): 10 chunks of 64 kB each written within {} ms\n\t"
                   "write(): 10 chunks of  1 MB each written within {} ms\n\t"
                   "\n\t"
                   "read():  10 chunks of  4 kB each read    within {} ms\n\t"
                   "read():  10 chunks of 64 kB each read    within {} ms\n\t"
                   "read():  10 chunks of  1 MB each read    within {} ms\n"
                   "\n"
                   "LzoHeader unittest: Looping for memory leak detection; "
                   "watch memory usage and press Ctrl+C to quit",
                   us_start          / 1000.f,
                   us_stop           / 1000.f,
                   us_try_read_start / 1000.f,
                   us_read_start     / 1000.f,
                   us_write4k        / 1000.f,
                   us_write64k       / 1000.f,
                   us_write1M        / 1000.f,
                   us_read4k         / 1000.f,
                   us_read64k        / 1000.f,
                   us_read1M         / 1000.f);

    auto prev_sigint_handler = signal(SIGINT, &Terminator.terminate);

    scope (exit) signal(SIGINT, prev_sigint_handler);

    debug ( OceanPerformanceTest ) while (!Terminator.terminated)
    {
        for (uint i = 0; i < N; i++)
        {
            start_header_data[i][] = cast (ubyte[]) header.start(4 * 1024).data;
            stop_header_data[i][] = cast (ubyte[]) header.stop().data;

            header.tryReadStart(start_header_data[i]);
            header.readStart(start_header_data[i]);
        }

        for (uint i = 0; i < C; i++)
        {
            header.write(chunks4k[i]);
            header.write(chunks64k[i]);
            header.write(chunks1M[i]);

            header.read(chunks4k[i]);
            header.read(chunks64k[i]);
            header.read(chunks1M[i]);
        }
    }

    version (UnitTestVerbose) Stderr.formatln("\n\nCompressionHeader unittest finished\n");
}
