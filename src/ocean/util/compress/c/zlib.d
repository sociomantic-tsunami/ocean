/*******************************************************************************

    D bindings to zlib compression library.

    Needs -lz when linking.

    Copyright:
        Copyright (c) 2004-2009 Tango contributors.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

        Bear in mind this module provides bindings to an external library that
        has its own license, which might be more restrictive. Please check the
        external library license to see which conditions apply for linking.

*******************************************************************************/

module ocean.util.compress.c.zlib;

import ocean.transition;

extern (C):

/// See original's library documentation for details.
static ZLIB_VERSION = "1.2.3".ptr;
/// See original's library documentation for details.
const uint  ZLIB_VERNUM  = 0x1230;


private
{
    import core.stdc.config : c_long, c_ulong;

    version( Posix )
    {
        import ocean.stdc.posix.sys.types : z_off_t = off_t;
    }
    else
    {
        alias c_long z_off_t;
    }

    alias ubyte     Byte;
    alias uint      uInt;
    alias c_ulong   uLong;

    alias Byte      Bytef;
    alias char      charf;
    alias int       intf;
    alias uInt      uIntf;
    alias uLong     uLongf;

    alias void*     voidpc; // TODO: normally const
    alias void*     voidpf;
    alias void*     voidp;

    alias voidpf function(voidpf opaque, uInt items, uInt size) alloc_func;
    alias void   function(voidpf opaque, voidpf address)        free_func;

    struct internal_state {}
}

struct z_stream
{
    Bytef*          next_in;
    uInt            avail_in;
    uLong           total_in;

    Bytef*          next_out;
    uInt            avail_out;
    uLong           total_out;

    char*           msg;
    internal_state* state;

    alloc_func      zalloc;
    free_func       zfree;
    voidpf          opaque;

    int             data_type;
    uLong           adler;
    uLong           reserved;
}

/// See original's library documentation for details.
alias z_stream* z_streamp;

/// See original's library documentation for details.
struct gz_header
{
    int     text;
    uLong   time;
    int     xflags;
    int     os;
    Bytef*  extra;
    uInt    extra_len;
    uInt    extra_max;
    Bytef*  name;
    uInt    name_max;
    Bytef*  comment;
    uInt    comm_max;
    int     hcrc;
    int     done;
}

/// See original's library documentation for details.
alias gz_header* gz_headerp;



/// See original's library documentation for details.
enum
{
    Z_NO_FLUSH      = 0,
    Z_PARTIAL_FLUSH = 1,
    Z_SYNC_FLUSH    = 2,
    Z_FULL_FLUSH    = 3,
    Z_FINISH        = 4,
    Z_BLOCK         = 5,
}

/// See original's library documentation for details.
enum
{
    Z_OK            = 0,
    Z_STREAM_END    = 1,
    Z_NEED_DICT     = 2,
    Z_ERRNO         = -1,
    Z_STREAM_ERROR  = -2,
    Z_DATA_ERROR    = -3,
    Z_MEM_ERROR     = -4,
    Z_BUF_ERROR     = -5,
    Z_VERSION_ERROR = -6,
}

/// See original's library documentation for details.
enum
{
    Z_NO_COMPRESSION      = 0,
    Z_BEST_SPEED          = 1,
    Z_BEST_COMPRESSION    = 9,
    Z_DEFAULT_COMPRESSION = -1,
}

/// See original's library documentation for details.
enum
{
    Z_FILTERED            = 1,
    Z_HUFFMAN_ONLY        = 2,
    Z_RLE                 = 3,
    Z_FIXED               = 4,
    Z_DEFAULT_STRATEGY    = 0,
}

/// See original's library documentation for details.
enum
{
    Z_BINARY   = 0,
    Z_TEXT     = 1,
    Z_ASCII    = Z_TEXT,
    Z_UNKNOWN  = 2,
}

/// See original's library documentation for details.
enum
{
    Z_DEFLATED = 8,
}

/// See original's library documentation for details.
const Z_NULL = null;

/// See original's library documentation for details.
alias zlibVersion zlib_version;


/// See original's library documentation for details.
char* zlibVersion();



/// See original's library documentation for details.
int deflate(z_streamp strm, int flush);


/// See original's library documentation for details.
int deflateEnd(z_streamp strm);




/// See original's library documentation for details.
int inflate(z_streamp strm, int flush);


/// See original's library documentation for details.
int inflateEnd(z_streamp strm);




/// See original's library documentation for details.
int deflateSetDictionary(z_streamp strm,
                         Bytef*    dictionary,
                         uInt      dictLength);

/// See original's library documentation for details.
int deflateCopy(z_streamp dest,
                z_streamp source);

/// See original's library documentation for details.
int deflateReset(z_streamp strm);

/// See original's library documentation for details.
int deflateParams(z_streamp strm,
                  int       level,
                  int       strategy);

/// See original's library documentation for details.
int deflateTune(z_streamp strm,
                int       good_length,
                int       max_lazy,
                int       nice_length,
                int       max_chain);

/// See original's library documentation for details.
uLong deflateBound(z_streamp strm,
                   uLong     sourceLen);

/// See original's library documentation for details.
int deflatePrime(z_streamp strm,
                 int       bits,
                 int       value);

/// See original's library documentation for details.
int deflateSetHeader(z_streamp  strm,
                     gz_headerp head);


/// See original's library documentation for details.
int inflateSetDictionary(z_streamp strm,
                         Bytef*    dictionary,
                         uInt      dictLength);

/// See original's library documentation for details.
int inflateSync(z_streamp strm);

/// See original's library documentation for details.
int inflateCopy(z_streamp dest,
                z_streamp source);

/// See original's library documentation for details.
int inflateReset(z_streamp strm);

/// See original's library documentation for details.
int inflatePrime(z_streamp strm,
                 int       bits,
                 int       value);

/// See original's library documentation for details.
int inflateGetHeader(z_streamp  strm,
                     gz_headerp head);


alias uint function(void*, ubyte**)      in_func;
alias int  function(void*, ubyte*, uint) out_func;

/// See original's library documentation for details.
int inflateBack(z_streamp strm,
                in_func   in_fn,
                void*     in_desc,
                out_func  out_fn,
                void*     out_desc);

/// See original's library documentation for details.
int inflateBackEnd(z_streamp strm);

/// See original's library documentation for details.
uLong zlibCompileFlags();




/// See original's library documentation for details.
int compress(Bytef*  dest,
             uLongf* destLen,
             Bytef*  source,
             uLong   sourceLen);

/// See original's library documentation for details.
int compress2(Bytef*  dest,
              uLongf* destLen,
              Bytef*  source,
              uLong   sourceLen,
              int     level);

/// See original's library documentation for details.
uLong compressBound(uLong sourceLen);

/// See original's library documentation for details.
int uncompress(Bytef*  dest,
               uLongf* destLen,
               Bytef*  source,
               uLong   sourceLen);


/// See original's library documentation for details.
mixin(Typedef!(voidp, "gzFile"));

/// See original's library documentation for details.
gzFile gzopen(char* path, char* mode);

/// See original's library documentation for details.
gzFile gzdopen(int fd, char* mode);

/// See original's library documentation for details.
int gzsetparams(gzFile file, int level, int strategy);

/// See original's library documentation for details.
int gzread(gzFile file, voidp buf, uint len);

/// See original's library documentation for details.
int gzwrite(gzFile file, voidpc buf, uint len);

/// See original's library documentation for details.
int gzprintf (gzFile file, char* format, ...);

/// See original's library documentation for details.
int gzputs(gzFile file, char* s);

/// See original's library documentation for details.
char* gzgets(gzFile file, char* buf, int len);

/// See original's library documentation for details.
int gzputc(gzFile file, int c);

/// See original's library documentation for details.
int gzgetc (gzFile file);

/// See original's library documentation for details.
int gzungetc(int c, gzFile file);

/// See original's library documentation for details.
int gzflush(gzFile file, int flush);

/// See original's library documentation for details.
z_off_t gzseek (gzFile file, z_off_t offset, int whence);

/// See original's library documentation for details.
int gzrewind(gzFile file);

/// See original's library documentation for details.
z_off_t gztell (gzFile file);

/// See original's library documentation for details.
int gzeof(gzFile file);

/// See original's library documentation for details.
int gzdirect(gzFile file);

/// See original's library documentation for details.
int gzclose(gzFile file);

/// See original's library documentation for details.
char* gzerror(gzFile file, int* errnum);

/// See original's library documentation for details.
void gzclearerr(gzFile file);

                        /* checksum functions */


/// See original's library documentation for details.
uLong adler32(uLong adler, Bytef* buf, uInt len);

/// See original's library documentation for details.
uLong adler32_combine(uLong adler1, uLong adler2, z_off_t len2);

/// See original's library documentation for details.
uLong crc32(uLong crc, Bytef* buf, uInt len);

/// See original's library documentation for details.
uLong crc32_combine(uLong crc1, uLong crc2, z_off_t len2);



                        /* various hacks, don't look :) */

/// See original's library documentation for details.
int deflateInit_(z_streamp  strm,
                 int        level,
                 Const!(char)* ver,
                 int        stream_size);
/// See original's library documentation for details.
int inflateInit_(z_streamp  strm,
                 Const!(char)* ver,
                 int        stream_size);
/// See original's library documentation for details.
int deflateInit2_(z_streamp strm,
                  int       level,
                  int       method,
                  int       windowBits,
                  int       memLevel,
                  int       strategy,
                  Const!(char)* ver,
                  int       stream_size);
/// See original's library documentation for details.
int inflateInit2_(z_streamp strm,
                  int       windowBits,
                  Const!(char)* ver,
                  int       stream_size);
/// See original's library documentation for details.
int inflateBackInit_(z_streamp strm,
                     int       windowBits,
                     ubyte*    window,
                     Const!(char)* ver,
                     int       stream_size);

extern (D) int deflateInit(z_streamp  strm,
                           int        level)
{
    return deflateInit_(strm,
                        level,
                        ZLIB_VERSION,
                        z_stream.sizeof);
}

extern (D) int inflateInit(z_streamp  strm)
{
    return inflateInit_(strm,
                        ZLIB_VERSION,
                        z_stream.sizeof);
}

extern (D) int deflateInit2(z_streamp strm,
                           int       level,
                           int       method,
                           int       windowBits,
                           int       memLevel,
                           int       strategy)
{
    return deflateInit2_(strm,
                         level,
                         method,
                         windowBits,
                         memLevel,
                         strategy,
                         ZLIB_VERSION,
                         z_stream.sizeof);
}

extern (D) int inflateInit2(z_streamp strm,
                            int       windowBits)
{
    return inflateInit2_(strm,
                         windowBits,
                         ZLIB_VERSION,
                         z_stream.sizeof);
}

extern (D) int inflateBackInit(z_streamp strm,
                               int       windowBits,
                               ubyte*    window)
{
    return inflateBackInit_(strm,
                            windowBits,
                            window,
                            ZLIB_VERSION,
                            z_stream.sizeof);
}

/// See original's library documentation for details.
char*   zError(int);
/// See original's library documentation for details.
int     inflateSyncPoint(z_streamp z);
/// See original's library documentation for details.
uLongf* get_crc_table();
