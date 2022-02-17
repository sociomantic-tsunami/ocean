/*******************************************************************************

    Zlib decoder which supports pkzip and gzip archives, and can be stored in a
    pool.

    In general it is not possible to stream pkzip archives. This is because the
    format supports some quirky features which were important in the days of
    floppy diskettes.

    This class supports an important case where streaming is
    possible: an archive which consists of a single file stored at
    the start of the archive, using DEFLATE compression.

    Needs linking with -lz.

    Usage example:

    ---

        import ocean.io.compress.ZipStream;

        auto unzipper = new ZipStreamDecompressor;

        unzipper.reset();

        try
        {
            unzipper.start();
        }
        catch (Exception e)
        {
            // Error!
        }

        // `downloader` is a hypothetical source which provides chunks of
        // compressed data, eg downloaded from a socket
        // Before processing, it may be wise to check that the first bytes in
        // the file are equal to GZipFileSignature (for gzip files) or
        // ocean.util.compress.c.Zip.ZipLocalFileHeaderSignature (for pkzip); an
        // exception will be thrown if this is not true.

        foreach (compressed_chunk; downloader)
        {
            try
            {
                uncompressed = unzipper.decompress(compressed_chunk);
^
                Stdout.format("{}", uncompressed);
            }
            catch (Exception e)
            {
                // Error!
            }
        }

        if (!unzipper.end())
        {
            // Error!
        }
    ---


    copyright:  Copyright (c) 2016 dunnhumby Germany GmbH. All rights reserved

*******************************************************************************/

module ocean.io.compress.ZipStream;


import ocean.core.Array : startsWith;
import ocean.core.Exception;
import ocean.io.compress.ZlibStream;
import ocean.meta.types.Qualifiers;
import ocean.util.compress.c.Zip;
import ocean.util.container.AppendBuffer;
import ocean.util.digest.Crc32;


/*******************************************************************************

    The file signature (magic number) used to identify a GZIP file

*******************************************************************************/

public static string GZipFileSignature = "\x1F\x8b";



/*******************************************************************************

    Zlib decoder which supports both gzip and pkzip compressed streams.

    Pkzip files are supported only if they contain a single file which is
    located at the start of the archive, and which contain a complete local file
    header record (that is, the length and CRC of that file are specified at the
    start of the archive).

*******************************************************************************/

public class ZipStreamDecompressor : ZlibStreamDecompressor
{
    /***************************************************************************

        Object pool index, allows instances of this type to be stored in a
        pool.

    ***************************************************************************/

    public size_t object_pool_index;


    /***************************************************************************

        Feed decompression buffer.

    ***************************************************************************/

    private AppendBuffer!(ubyte) uncompressed;


    /***************************************************************************

        CRC instance for validating Pkzip files

    ***************************************************************************/

    private Crc32 crc;


    /***************************************************************************

        Header of the current compressed file, if this is a PKZIP archive

    ***************************************************************************/

    private ZipLocalFileHeaderRecord zip_header;


    /***************************************************************************

        State of the decompression. The file may be a GZip file, or a PKZIP
        archive.

    ***************************************************************************/

    private enum DecompressState
    {
        NotStarted,    /// Decompression has not yet begun
        GzipStarted,   /// Gzip decompression is in progress
        PkzipHeader,   /// A Pkzip local file header is being read
        PkzipExtra,    /// A Pkzip extra field is being skipped
        PkZipBody,     /// Pkzip compressed data is being read
        PkZipTrailer   /// Data after the compressed file is being skipped
    };

    private DecompressState state;


    /***************************************************************************

        Counter which drops to zero when the current PKZIP section has finished

    ***************************************************************************/

    private int pkzip_byte_counter;


    /***************************************************************************

        Reusable exception thrown when a zip file cannot be decompressed

    ***************************************************************************/

    public static class DecompressionException : Exception
    {

        /***********************************************************************

            Provides standard reusable exception API

        ***********************************************************************/

        mixin ReusableExceptionImplementation!();

    }


    /***************************************************************************

        Reusable exception instance

    ***************************************************************************/


    private DecompressionException exception;


    /***************************************************************************

        Constructor

    ***************************************************************************/

    public this ()
    {
        this.uncompressed = new AppendBuffer!(ubyte);
        this.crc = new Crc32;
        this.exception = new DecompressionException;
    }


    /***************************************************************************

        Begin processing of a compressed file

    ***************************************************************************/

    public void reset ( )
    {
        this.state = DecompressState.NotStarted;
    }


    /***************************************************************************

        Release the resources used for decompression, and perform a consistency
        check

        Returns:
            true if the file was well-formed, false if it was inconsistent

    ***************************************************************************/

    public bool endDecompression ( )
    {
        // If decompression was started, end it.

        if ( this.state == DecompressState.GzipStarted ||
            this.state == DecompressState.PkZipBody )
        {
            return this.end();
        }

        // If it was a PKZIP file and we reached the end,
        // it is OK

        if ( this.state == DecompressState.PkZipTrailer )
        {
            return true;
        }

        // Any other situation is an error

        return false;
    }


    /***************************************************************************

        Decompress a chunk of input data

        Params:
            data = received data chunk

        Returns:
            the uncompressed data

        Throws:
            if a decompression error occurs

    ***************************************************************************/

    public ubyte [] decompress ( const(ubyte) [] data )
    {
        if ( this.state == DecompressState.NotStarted )
        {
            // Use the first bytes to identify which format it is

            if ( startsWith(cast(cstring)data, GZipFileSignature) )
            {
                // GZip file

                this.state = DecompressState.GzipStarted;

                this.start();
            }
            else if ( startsWith(cast(cstring)data,
                ZipLocalFileHeaderSignature) )
            {
                // PKZip file

                this.state = DecompressState.PkzipHeader;
                this.uncompressed.clear();
                data = data[ZipLocalFileHeaderSignature.length..$];
            }
            else
            {
                this.exception.set("Unsupported file format");
                throw this.exception;
            }
        }

        if ( this.state == DecompressState.PkzipHeader )
        {
            // Append data to 'uncompressed' until we've obtained the header

            if ( this.uncompressed.length + data.length
                < this.zip_header.sizeof )
            {
                this.uncompressed.append(data);
                return null;
            }

            auto len = this.zip_header.sizeof - this.uncompressed.length;

            this.uncompressed.append(data[0..len]);
            this.zip_header = *cast(ZipLocalFileHeaderRecord *)
                            (this.uncompressed[]);

            // Check that the file format is one which we support

            if ( this.zip_header.isCrcMissing() )
            {
                this.exception.set("Zip file is not streamable - No CRC");
                throw this.exception;
            }

            if ( !this.zip_header.isDeflateCompressed() )
            {
                // This error most likely indicates data corruption, or a tiny
                // file. Deflate compression has been standard since 1993.
                // Tiny files are STORED instead of DEFLATED.
                this.exception.set("Zip file uses unsupported compression");
                throw this.exception;
            }

            data = data[ len..$ ];

            this.state = DecompressState.PkzipExtra;

            // Calculate the number of bytes which need to be skipped

            this.pkzip_byte_counter = this.zip_header.file_name_length +
                this.zip_header.extra_field_length;

        }

        if ( this.state == DecompressState.PkzipExtra )
        {
            // Skip the filename and the 'extra field'

            if ( this.pkzip_byte_counter >= data.length )
            {
                this.pkzip_byte_counter -= data.length;

                return null;
            }

            data = data[this.pkzip_byte_counter .. $];

            // Now, we start decompressing the actual zip stream
            // It does not have any header encoding

            this.start(Encoding.None);

            // Reset the CRC. This is a workaround for a terrible Tango design
            // (the CRC is reset when you read the digest -- which means that
            // if the digest wasn't read, the next CRC will be incorrect)

            this.crc.crc32Digest();

            // Determine how many bytes of compressed data to wait for

            this.pkzip_byte_counter = this.zip_header.compressed_size;

            this.state = DecompressState.PkZipBody;
        }

        // Now, obtain the compressed data

        auto compressed_data = data;

        if ( this.state == DecompressState.PkZipBody )
        {
            if ( data.length >= this.pkzip_byte_counter )
            {
                compressed_data = data[0 .. this.pkzip_byte_counter];
            }

            this.pkzip_byte_counter -= compressed_data.length;

            data = data[compressed_data.length .. $];
        }

        if ( this.state == DecompressState.PkZipTrailer )
        {
            // Don't need anything more from the file.
            // Just skip everything.

            return null;
        }

        this.uncompressed.clear();

        // The cast is necessary only because ZLibStreamDecompressor isn't
        // const-correct.
        this.decodeChunk(cast(ubyte[])compressed_data,
            ( ubyte[] uncompressed_chunk )
            {
                this.uncompressed.append(uncompressed_chunk);
            }
        );

        if ( this.state == DecompressState.PkZipBody )
        {
            this.crc.update(this.uncompressed[]);

            // Check if we have finished reading the compressed data

            if ( this.pkzip_byte_counter == 0 )
            {
                this.state = DecompressState.PkZipTrailer;

                // Check if it was genuinely the end of a compressed stream

                if ( !this.end() )
                {
                    this.exception.set("Zip file is incomplete");
                    throw this.exception;
                }

                // Now that the compressed data has finished, check if
                // the checksum was correct.
                // Note that the CRC is reset when you read the digest.

                auto calculated_crc = this.crc.crc32Digest();

                if ( calculated_crc != this.zip_header.crc_32 )
                {
                    this.exception.set("Zip file checksum failed.");
                    throw this.exception;
                }

            }
        }
        return this.uncompressed[];
    }
}


unittest
{
    import ocean.core.Test;

    // A tiny PKZIP file using DEFLATE compression

    immutable rawZip =
        "\x50\x4b\x03\x04\x14\x00\x00\x00\x08\x00\xa2\x6e\x2d\x50\x2f\xbd" ~
        "\x37\x12\x08\x00\x00\x00\x10\x00\x00\x00\x08\x00\x1c\x00\x74\x65" ~
        "\x73\x74\x2e\x74\x78\x74\x55\x54\x09\x00\x03\x30\x68\x1c\x5e\x30" ~
        "\x68\x1c\x5e\x75\x78\x0b\x00\x01\x04\xe8\x03\x00\x00\x04\xe8\x03" ~
        "\x00\x00\x4b\x4c\x4c\x4a\x44\x42\x5c\x00\x50\x4b\x01\x02\x1e\x03" ~
        "\x14\x00\x00\x00\x08\x00\xa2\x6e\x2d\x50\x2f\xbd\x37\x12\x08\x00" ~
        "\x00\x00\x10\x00\x00\x00\x08\x00\x18\x00\x00\x00\x00\x00\x01\x00" ~
        "\x00\x00\xb4\x81\x00\x00\x00\x00\x74\x65\x73\x74\x2e\x74\x78\x74" ~
        "\x55\x54\x05\x00\x03\x30\x68\x1c\x5e\x75\x78\x0b\x00\x01\x04\xe8" ~
        "\x03\x00\x00\x04\xe8\x03\x00\x00\x50\x4b\x05\x06\x00\x00\x00\x00" ~
        "\x01\x00\x01\x00\x4e\x00\x00\x00\x4a\x00\x00\x00\x00\x00";

    auto unzipper = new ZipStreamDecompressor;
    unzipper.reset();
    unzipper.start();
    auto decom = unzipper.decompress(cast(const(ubyte)[]) rawZip);
    test!("==")(decom, "aabaabaabaabaab\n");
    test(unzipper.endDecompression());

    // Now process the same file, in chunks.

    unzipper.reset();
    unzipper.start();
    decom = unzipper.decompress(cast(const(ubyte)[]) rawZip[0..10]);
    test(decom.length == 0);
    decom = unzipper.decompress(cast(const(ubyte)[]) rawZip[10..60]);
    test(decom.length == 0);
    decom = unzipper.decompress(cast(const(ubyte)[]) rawZip[60..70]);
    test!("==")(decom, "aab");
    decom = unzipper.decompress(cast(const(ubyte)[]) rawZip[70..72]);
    test!("==")(decom, "aabaabaabaab");
    decom = unzipper.decompress(cast(const(ubyte)[]) rawZip[72..$]);
    test!("==")(decom, "\n");
    test(unzipper.endDecompression());
}
