/*******************************************************************************

    Simple zlib / gzip stream decompressor.

    Decompresses a stream of data which is received in one or more chunks. The
    decompressed data is passed to a provided delegate.

    Needs linking with -lz.

    Usage example:

    ---

        import ocean.io.compress.ZlibStream;

        auto decompress = new ZlibStreamDecompressor;

        ubyte[] decompressed_data;

        decompress.start(ZlibStreamDecompressor.Encoding.Zlib);

        // Hypothetical function which receives chunks of compressed data.
        receiveData(
            ( ubyte[] compressed_chunk )
            {
                decompress.decodeChunk(compressed_chunk,
                    ( ubyte[] decompressed_chunk )
                    {
                        decompressed_data ~= decompressed_chunk;
                    });
            });

    ---

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

module ocean.io.compress.ZlibStream;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.compress.c.zlib;

import ocean.io.stream.Zlib : ZlibException, ZlibInput;

import ocean.core.TypeConvert;


/*******************************************************************************

    Simple zlib stream decompressor.

*******************************************************************************/

class ZlibStreamDecompressor
{
    /***************************************************************************

        Alias for encoding enum, to avoid public import.

        The enum has the following values:
            Guess (guesses data encoding type, but cannot guess unencoded)
            Zlib
            Gzip
            None

    ***************************************************************************/

    public alias ZlibInput.Encoding Encoding;


    /***************************************************************************

        zlib stream object. C-allocated.

    ***************************************************************************/

    private z_stream stream;


    /***************************************************************************

        Flag telling whether the z_stream has been initialised.

    ***************************************************************************/

    private bool stream_valid;


    /***************************************************************************

        Destructor. Makes sure the C-allocated stream is destroyed.

    ***************************************************************************/

    ~this ( )
    {
        this.killStream();
    }


    /***************************************************************************

        Starts decompression of a stream.

        Params:
            encoding = encoding type of data in stream

    ***************************************************************************/

    public void start ( Encoding encoding = Encoding.Guess )
    {
        this.killStream();

        // Setup correct window bits for specified encoding.
        // (See zlib.h for a description of how window bits work.)
        const WINDOWBITS_DEFAULT = 15;
        int windowBits = WINDOWBITS_DEFAULT;

        switch ( encoding )
        {
            case Encoding.Zlib:
                // no-op
                break;

            case Encoding.Gzip:
                windowBits += 16;
                break;

            case Encoding.Guess:
                windowBits += 32;
                break;

            case Encoding.None:
                windowBits *= -1;
                break;

            default:
                assert (false);
        }

        // Initialise stream settings
        this.stream.zalloc = null;
        this.stream.zfree = null;
        this.stream.opaque = null;
        this.stream.avail_in = 0;
        this.stream.next_in = null;

        // Allocate inflate state
        auto ret = inflateInit2(&this.stream, windowBits);
        if ( ret != Z_OK )
        {
            throw new ZlibException(ret); // TODO: reusable exception instance
        }

        this.stream_valid = true;
    }


    /***************************************************************************

        Decodes a chunk of data from the stream and passes the resulting
        decompressed data chunks to the provided output delegate. A single input
        chunk may invoke the output delegate several times.

        Params:
            compressed_chunk = chunk of compressed data from stream
            output_dg = delegate to receive decompressed data chunks

        Returns:
            true if the chunk was the end of the stream

    ***************************************************************************/

    public bool decodeChunk ( ubyte[] compressed_chunk, void delegate ( ubyte[] decompressed_chunk ) output_dg )
    in
    {
        assert(this.stream_valid, typeof(this).stringof ~ ".decodeChunk: stream not started");
    }
    body
    {
        ubyte[1024] buffer; // stack buffer for decoding

        // Set stream input chunk.
        this.stream.avail_in = castFrom!(size_t).to!(uint)(compressed_chunk.length);
        this.stream.next_in = compressed_chunk.ptr;

        int ret;
        do
        {
            // Set stream output chunk.
            this.stream.avail_out = buffer.length;
            this.stream.next_out = buffer.ptr;

            // Decompress.
            ret = inflate(&this.stream, Z_NO_FLUSH);
            switch ( ret )
            {
                // Handle errors.
                case Z_NEED_DICT:
                    // Whilst not technically an error, this should never happen
                    // for general-use code, so treat it as an error.
                case Z_DATA_ERROR:
                case Z_MEM_ERROR:
                case Z_STREAM_ERROR:
                    this.killStream();
                    throw new ZlibException(ret); // TODO: reusable exception instance

                // Pass decompressed data chunk to output delegate.
                default:
                    auto filled_len = buffer.length - this.stream.avail_out;
                    output_dg(buffer[0 .. filled_len]);
            }
        }
        while (ret != Z_STREAM_END && this.stream.avail_in > 0 );

        // Kill stream object if the end was reached.
        if ( ret == Z_STREAM_END )
        {
            this.killStream();
        }

        return ret == Z_STREAM_END;
    }


    /***************************************************************************

        Deallocates the C-allocated stream object.

    ***************************************************************************/

    private void killStream ( )
    {
        if ( this.stream_valid )
        {
            inflateEnd(&stream);
            stream_valid = false;
        }
    }
}

