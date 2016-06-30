/*******************************************************************************

    Class encapsulating an lzo chunk compressor and a memory buffer to store
    de/compression results.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.compress.lzo.LzoChunkCompressor;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.io.compress.Lzo;

import ocean.io.compress.lzo.LzoChunk;

import ocean.io.compress.lzo.LzoHeader;




/*******************************************************************************

    Lzo chunk compressor

*******************************************************************************/

class LzoChunkCompressor
{
    /***************************************************************************

        Constants defining whether de/compression headers expect the chunk
        length to be stored inline (ie as part of the chunk array).

    ***************************************************************************/

    private const bool DecompressLenghtInline = false;
    private const bool CompressLenghtInline = true;


    /***************************************************************************

        Chunk decompressor.

    ***************************************************************************/

    public class Decompressor
    {
        /***********************************************************************

            Aliases for the lzo header & chunk.

        ***********************************************************************/

        public alias LzoHeader!(DecompressLenghtInline) Header;
        public alias LzoChunk!(DecompressLenghtInline) Chunk;


        /***********************************************************************

            Lzo chunk instance, used to do the decompression.

        ***********************************************************************/

        private Chunk chunk;


        /***********************************************************************

            Constructor.

        ***********************************************************************/

        public this ( )
        {
            this.chunk = new Chunk(this.outer.lzo);
        }


        /***********************************************************************

            Decompresses provided data.

            Params:
                source = data to decompress

            Returns:
                decompressed data (a slice into the outer class' results buffer)

        ***********************************************************************/

        public char[] decompress ( char[] source )
        {
            this.chunk.uncompress(cast(void[])source, this.outer.result);
            return this.outer.result;
        }


        /***********************************************************************

            Tells whether the provided data is an lzo start chunk.

            Params:
                array = data to check

            Returns:
                true if data is an lzo start chunk

        ***********************************************************************/

        public bool isStartChunk ( char[] array )
        {
            Header header;

            if ( array.length < header.read_length )
            {
                return false;
            }
            else
            {
                return header.tryReadStart(array[0..header.read_length]);
            }
        }
    }


    /***************************************************************************

        Chunk compressor.

    ***************************************************************************/

    public class Compressor
    {
        /***********************************************************************

            Aliases for the lzo header & chunk.

        ***********************************************************************/

        public alias LzoHeader!(CompressLenghtInline) Header;
        public alias LzoChunk!(CompressLenghtInline) Chunk;


        /***********************************************************************

            Lzo chunk instance, used to do the compression.

        ***********************************************************************/

        private Chunk chunk;


        /***********************************************************************

            Constructor.

        ***********************************************************************/

        public this ( )
        {
            this.chunk = new Chunk(this.outer.lzo);
        }


        /***********************************************************************

            Compresses provided data.

            Params:
                source = data to compress

            Returns:
                compressed data (a slice into the outer class' results buffer)

        ***********************************************************************/

        public char[] compress ( char[] source )
        {
            this.chunk.compress(cast(void[])source, this.outer.result);
            return this.outer.result;
        }


        /***********************************************************************

            Tells whether the provided data is an lzo start chunk.

            Params:
                array = data to check

            Returns:
                true if data is an lzo start chunk

        ***********************************************************************/

        public bool isStartChunk ( char[] array )
        {
            Header header;

            if ( array.length < header.read_length )
            {
                return false;
            }
            else
            {
                return header.tryReadStart(array[0..header.read_length]);
            }
        }
    }


    /***************************************************************************

        Chunk de/compressor instances.

    ***************************************************************************/

    public Decompressor decompressor;
    public Compressor compressor;


    /***************************************************************************

        Internal lzo object.

    ***************************************************************************/

    public Lzo lzo;


    /***************************************************************************

        Internal de/compression results buffer.

    ***************************************************************************/

    private char[] result;


    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        this.lzo = new Lzo;

        this.compressor = new Compressor;
        this.decompressor = new Decompressor;
    }


    /***************************************************************************

        Destructor.

    ***************************************************************************/

    ~this ( )
    {
        this.result.length = 0;
    }
}
