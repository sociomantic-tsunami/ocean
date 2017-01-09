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

        decompress.end();

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

        The status of the zlib stream object

    ***************************************************************************/

    private int stream_status;


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
        this.stream_status = inflateInit2(&this.stream, windowBits);

        if ( this.stream_status != Z_OK )
        {
            // TODO: reusable exception instance
            throw new ZlibException(this.stream_status);
        }

        this.stream_valid = true;
    }


    /***************************************************************************

        Ends decompression of a stream. Releases the C-allocated resources.

        Returns:
            true if decompression completed normally, false if the stream
            was incomplete

    ***************************************************************************/

    public bool end ( )
    {
        this.killStream();

        return this.stream_status == Z_STREAM_END;
    }


    /***************************************************************************

        Decodes a chunk of data from the stream and passes the resulting
        decompressed data chunks to the provided output delegate. A single input
        chunk may invoke the output delegate several times.

        Params:
            compressed_chunk = chunk of compressed data from stream
            output_dg = delegate to receive decompressed data chunks

    ***************************************************************************/

    public void decodeChunk ( ubyte[] compressed_chunk,
        void delegate ( ubyte[] decompressed_chunk ) output_dg )
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

        do
        {
            if ( this.stream_status == Z_STREAM_END )
            {
                // Z_STREAM_END is not the same as EOF.
                // Inside a concatenated gzip file, it may be followed by
                // additional compressed data.

                inflateReset(&this.stream);
            }
            do
            {
                // Set stream output chunk.
                this.stream.avail_out = buffer.length;
                this.stream.next_out = buffer.ptr;

                // Decompress.
                this.stream_status = inflate(&this.stream, Z_NO_FLUSH);

                // Z_BUF_ERROR is not an error, it indicates that no progress
                // can be made until more input data is provided. It exists
                // to distinguish a special case: when the previous call to
                // inflate() consumed all the input, but coincidentally
                // happened to completely fill the output buffer, the next
                // call to inflate() will return Z_BUF_ERROR because no more
                // data is available.

                if ( this.stream_status != Z_OK
                    && this.stream_status != Z_STREAM_END
                    && this.stream_status != Z_BUF_ERROR )
                {
                    // Handle errors.

                    this.killStream();

                     // TODO: reusable exception instance
                    throw new ZlibException(this.stream_status);
                }

                // Pass decompressed data chunk to output delegate.

                auto filled_len =  buffer.length - this.stream.avail_out;

                if ( filled_len > 0 )
                {
                    output_dg(buffer[0 .. filled_len]);
                }
            }
            while ( this.stream.avail_out == 0 );
        }
        while ( this.stream.avail_in > 0 );
    }


    /***************************************************************************

        Deallocates the C-allocated stream object.

    ***************************************************************************/

    private void killStream ( )
    {
        if ( this.stream_valid )
        {
            inflateEnd(&stream);
            this.stream_valid = false;
        }
    }
}

