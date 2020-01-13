/*******************************************************************************

    Record definitions for the PKZIP archive file format

    copyright:  Copyright (c) 2016 dunnhumby Germany GmbH. All rights reserved


*******************************************************************************/

module ocean.util.compress.c.Zip;


import ocean.meta.types.Qualifiers : istring;


/*******************************************************************************

    Signatures of the records in a Zip archive. Each record is preceded by the
    corresponding signature, except for ZipLocalFileSizeSignature, which is
    permitted to be missing.

    All signatures begin with "PK", the initials of Phil Katz, who created the
    format.

*******************************************************************************/

static istring ZipCentralDirectoryFileHeaderSignature = "PK\x01\x02";

/** ditto **/

static istring ZipLocalFileHeaderSignature = "PK\x03\x04";

/** ditto **/

static istring ZipEndOfCentralDirectorySignature = "PK\x05\x06";

/** ditto **/

static istring ZipLocalFileSizeSignature = "PK\x07\x08";



/*******************************************************************************

    Struct which is stored at the start of each file in the archive

    This record will always be preceded by a ZipLocalFileHeaderSignature.
    This is an incomplete, redundant copy of the struct in the central
    directory.

*******************************************************************************/

public align(1) struct ZipLocalFileHeaderRecord
{
    align(1):
    ushort      extract_version;
    ushort      general_flags;
    ushort      compression_method;
    ushort      modification_file_time;
    ushort      modification_file_date;
    uint        crc_32;
    uint        compressed_size;
    uint        uncompressed_size;
    ushort      file_name_length;
    ushort      extra_field_length;

    /***********************************************************************

        Returns:
            true if the CRC and file sizes were not known when the object
            was written. In this case, the values are stored in a
            ZipLocalFileSizeRecord after the compressed data. There may or
            may not be a ZipLocalFileSizeSignature before the record.

    ***********************************************************************/

    public final bool isCrcMissing ( )
    {
        return (this.general_flags & 0x08 ) == 0x08;
    }


    /***************************************************************************

        Returns:
            true if and only if the file is compressed using the DEFLATE method

    ***************************************************************************/

    public final bool isDeflateCompressed ()
    {
        return this.compression_method == 8;
    }
}


/*******************************************************************************

    Struct which is stored at the end of a file if the CRC and length were not
    known when the file compression began.

    This struct may optionally be preceded by a ZipLocalFileSizeSignature.

*******************************************************************************/

public align(1) struct ZipLocalFileSizeRecord
{
    align(1):
    uint        crc_32;
    uint        compressed_size;
    uint        uncompressed_size;
}


/*******************************************************************************

    Struct which is stored at the end of the archive. It is followed by a
    comment of length up to 65535 bytes.

    This record will always be preceded by a
    ZipCentralDirectoryFileHeaderSignature.

*******************************************************************************/

public align(1) struct ZipCentralDirectoryFileHeaderRecord
{
    align(1):
    ubyte       zip_version;
    ubyte       file_attribute_type;
    ushort      extract_version;
    ushort      general_flags;
    ushort      compression_method;
    ushort      modification_file_time;
    ushort      modification_file_date;
    uint        crc_32;
    uint        compressed_size;
    uint        uncompressed_size;
    ushort      file_name_length;
    ushort      extra_field_length;
    ushort      file_comment_length;
    ushort      disk_number_start;
    ushort      internal_file_attributes;
    uint        external_file_attributes;
    int         relative_offset_of_local_header;
}


/*******************************************************************************

    Struct which is stored at the end of the archive. It is followed by a
    comment of length up to 65535 bytes.

    This record will always be preceded by a
    ZipEndOfCentralDirectorySignature

*******************************************************************************/

public align(1) struct EndOfCentralDirectoryRecord
{
    align(1):
    ushort      disk_number;
    ushort      disk_with_start_of_central_directory;
    ushort      central_directory_entries_on_this_disk;
    ushort      central_directory_entries_total;
    uint        size_of_central_directory;
    uint        offset_of_start_of_cd_from_starting_disk;
    ushort      file_comment_length;
}
