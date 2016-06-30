/*******************************************************************************

    Direct I/O output and input streams

    This module provides an OutputStream (BufferedDirectWriteFile) and
    a InputStream (BufferedDirectReadFile) to do direct I/O using Linux's
    O_DIRECT flag.

    This kind of I/O is specially (and probably only) useful when you need to
    dump a huge amount of data to disk as some kind of backup, i.e., data that
    you'll probably won't ever read again (or at least in the short term). In
    those cases, going through the page cache is not only probably slower
    (because you are doing an extra memory copy), but it can
    potentially freeze the whole system, if the sysctl vm.dirty_ratio is passed,
    in that, programs will use their own time to write the page cache to disk.
    If the data you need to write is small or you are going access it in the
    short term and you are not experiencing freezes, you probably DON'T want to
    use this module.

    Even when these kind of objects should probably derive from File (i.e. be
    a device, and be selectable), given this type of I/O is very particular, and
    a lot of details need to be taken into account, they are just implementing
    the stream interfaces, and separately (for example, direct I/O is supposed
    to be always blocking, unless you do async I/O too, because the data is
    being copied directly from your buffer to the disk, is not going through the
    page cache, which makes non-blocking I/O possible). Even some of the stream
    interface methods are not implemented (seek(), flush(), copy() and load()).
    This might change in the future, if needed.

    Direct I/O also must write complete sectors. This means buffers passed to
    write(2) must be aligned to the block size too. This is why this class uses
    internal buffering instead of using the original memory. This is just to
    make user's lives easier, so they don't have to worry about alignment (if
    you can, try to keep your buffers aligned though, there are optimizations to
    avoid copies in those cases). When instantiating the classes, it is safe to
    pass as buffer memory you just allocated through the GC, since the GC
    returns memory that's always aligned to the page size (4096) when allocating
    chunks larger than a page.

    Users must notice, though, that whole sectors will be written (512 bytes
    each), so if they write, for example 100 bytes, the file will be still 512
    bytes long and the final 412 bytes will contain garbage. truncate(2) or
    ftruncate(2) might be used to truncate the file to its real size if desired.

    See_Also:
        http://web.archive.org/web/20160317032821/http://www.westnet.com/~gsmith/content/linux-pdflush.htm
        https://www.kernel.org/doc/Documentation/sysctl/vm.txt

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.device.DirectIO;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.io.model.IConduit;

import ocean.io.device.File;

import ocean.core.Exception_tango: IOException;

import ocean.stdc.posix.fcntl : O_DIRECT; // Linux only



/*******************************************************************************

    Mixin template for classes that need to have buffers that are aligned to
    a certain block size and don't support some operations.

*******************************************************************************/

private template AlignedBufferedStream ( )
{

    /***************************************************************************

        Block size.

        Almost every HDD out there has a block size of 512. But we should be
        careful about this...

    ***************************************************************************/

    public enum { BLOCK_SIZE = 512 }

    /***************************************************************************

        Internal buffer (the size needs to be multiple of the block size).

    ***************************************************************************/

    protected ubyte[] buffer;

    /***************************************************************************

        Internal pointer to the next byte of the buffer that is free.

    ***************************************************************************/

    protected size_t free_index;

    /***************************************************************************

        Construct the buffer using an existing buffer.

        This method checks the buffer is properly aligned and the length is
        a multiple of BLOCK_SIZE too.

        Params:
            buffer = buffer to re-use for this aligned buffer.

    ***************************************************************************/

    protected void setBuffer ( ubyte[] buffer )
    {
        this.buffer = buffer;
        // Throw an error if the buffer is not aligned to BLOCK_SIZE
        if ( !this.isAligned(buffer.ptr) )
            throw new IOException("Buffer is not aligned to BLOCK_SIZE, maybe "
                    "you should start using posix_memalign(3)");
        // Throw an error if the buffer length is not a multiple of the
        // BLOCK_SIZE
        if ((buffer.length % BLOCK_SIZE) != 0)
            throw new IOException("Buffer length is not multiple of the "
                    "BLOCK_SIZE");
        this.free_index = 0;
    }

    /***************************************************************************

        Construct the buffer with a specified size.

        This method checks the buffer is properly aligned and the lenght is
        a multiple of BLOCK_SIZE too.

        Params:
            buffer_blocks = Buffer size in blocks

    ***************************************************************************/

    protected void createBuffer ( size_t buffer_blocks )
    {
        // O_DIRECT needs to work with aligned memory (to the block size,
        // which 99.9% of the time is 512), but the current GC implementation
        // always align memory for a particular block size (and 512 is a current
        // GC block size), so if the buffer is 512 or bigger, we are just fine.
        //
        // If we can't rely on this eventually, we can use posix_memalign(3)
        // instead to allocate the memory.
        this.setBuffer(new ubyte[buffer_blocks * BLOCK_SIZE]);
    }

    /***************************************************************************

        Return true if the pointer is aligned to the block size.

    ***************************************************************************/

    final public bool isAligned ( Const!(void)* ptr )
    {
        return (cast(size_t) ptr & (this.BLOCK_SIZE - 1)) == 0;
    }

    /***************************************************************************

        Throws an IOException because is not implemented.

    ***************************************************************************/

    public override long seek (long offset, Anchor anchor = Anchor.Begin)
    {
        throw new IOException("seek() not supported by " ~
                this.classinfo.name);
    }

    /***************************************************************************

        Throws an IOException because is not implemented.

    ***************************************************************************/

    public override IOStream flush ()
    {
        throw new IOException("flush() not supported by " ~
                this.classinfo.name);
    }

    /***************************************************************************

        Throws IOException because is not implemented.

        Only present in OutputStream, so we can't use the override keyword.

    ***************************************************************************/

    public OutputStream copy (InputStream src, size_t max = -1)
    {
        throw new IOException("copy() not supported by " ~
                this.classinfo.name);
    }

}


/*******************************************************************************

    Buffered file to do direct I/O writes.

    Please read the module documentation for details.

*******************************************************************************/

public class BufferedDirectWriteFile: OutputStream
{

    /***************************************************************************

        File to do direct IO writes.

        Actually there is no way to open files with File specifying custom
        flags that is not sub-classing. Bummer!

    ***************************************************************************/

    static protected class DirectWriteFile : File
    {
        /***********************************************************************

            Opens a direct-write file at the specified path.

            Params:
                path = path at which to open file
                style = file open mode
 
            Throws:
                IOException on error opening the file

        ***********************************************************************/

        override public void open (cstring path, Style style = this.WriteCreate)
        {
            if (!super.open(path, style, O_DIRECT))
                this.error();
        }

        /***********************************************************************

            Returns:
                the file's path

        ***********************************************************************/

        public cstring path ( )
        {
            return this.toString();
        }
    }

    /***************************************************************************

        Direct I/O file device to write to.

    ***************************************************************************/

    private DirectWriteFile file;

    /***************************************************************************

        Constructs a new BufferedDirectWriteFile.

        If a path is specified, the file is open too. A good buffer size depends
        mostly on the speed of the disk (memory and CPU). If the buffer is too
        big, you will notice that writing seems to happen in long bursts, with
        periods of a lot of buffer copying, and long wait periods writing to
        disk. If the buffer is too small, the throughput will be too small,
        resulting in bigger total write time.

        32MiB have shown to be a decent value for a low end magnetic hard
        drive, according to a few tests.

        Params:
            path = Path of the file to write to.
            buffer = Buffer to use for writing, the length must be multiple of
                     the BLOCK_SIZE and the memory must be aligned to the
                     BLOCK_SIZE

    ***************************************************************************/

    public this (cstring path, ubyte[] buffer)
    {
        this.setBuffer(buffer);
        this.file = this.newFile();
        if (path.length > 0)
            this.open(path);
    }

    /***************************************************************************

        Instantiates the file object to be used to write to. This method may be
        overridden by derived classes, allowing different types of file to be
        used with this class.

        Returns:
            file object to write to

    ***************************************************************************/

    protected DirectWriteFile newFile ( )
    {
        return new DirectWriteFile;
    }

    /***************************************************************************

        Constructs a new BufferedDirectWriteFile allocating a new buffer.

        See documentation for this(cstring, ubyte[]) for details.

        Params:
            path = Path of the file to write to.
            buffer_blocks = Buffer size in blocks (default 32MiB)

    ***************************************************************************/

    public this (cstring path = null, size_t buffer_blocks = 32 * 2 * 1024)
    {
        // O_DIRECT needs to work with aligned memory (to the block size,
        // which 99.9% of the time is 512), but the current GC implementation
        // always align memory for a particular block size (and 512 is a current
        // GC block size), so if the buffer is 512 or bigger, we are just fine.
        //
        // If we can't rely on this eventually, we can use posix_memalign(3)
        // instead to allocate the memory.
        this(path, new ubyte[buffer_blocks * BLOCK_SIZE]);
    }

    /***************************************************************************

        Mixin for common functionality.

    ***************************************************************************/

    mixin AlignedBufferedStream;

    /***************************************************************************

        Open a BufferedDirectWriteFile file.

        Params:
            path = Path of the file to write to.

    ***************************************************************************/

    public void open (cstring path)
    {
        assert (this.file.fileHandle == -1);
        this.file.open(path);
        this.free_index = 0;
    }

    /***************************************************************************

        Returns:
            what File.toString() returns for the underlying File instance

    ***************************************************************************/

    public cstring path ( )
    {
        return this.file.path();
    }

    /***************************************************************************

        Return the host conduit.

    ***************************************************************************/

    public IConduit conduit ()
    {
        return this.file;
    }

    /***************************************************************************

        Close the underlying file, but calling flushWithPadding() and sync()
        first.

    ***************************************************************************/

    public void close ()
    {
        if (this.file.fileHandle == -1)
            return;
        this.flushWithPadding();
        this.sync();
        this.file.close();
    }

    /***************************************************************************

        Write to stream from a source array. The provided src content will be
        written to the stream.

        Returns the number of bytes written from src, which may be less than the
        quantity provided. Eof is returned when an end-of-flow condition arises.

    ***************************************************************************/

    public size_t write (Const!(void)[] src)
    {
        assert (this.file.fileHandle != -1);

        size_t total = src.length;

        if (src.length == 0)
            return 0;

        // Optimization: avoid extra copy if src is already aligned to the
        // block size
        if (this.free_index == 0)
        {
            while (src.length >= this.buffer.length)
            {
                if (this.isAligned(src.ptr))
                {
                    this.file.write(src[0 .. this.buffer.length]);
                    src = src[this.buffer.length .. $];
                }
            }
        }

        while (this.free_index + src.length > this.buffer.length)
        {
            auto hole = this.buffer.length - this.free_index;
            this.buffer[this.free_index .. $] = cast(ubyte[]) src[0 .. hole];
            this.free_index = this.buffer.length;
            this.flushWithPadding();
            src = src[hole .. $];
        }

        this.buffer[this.free_index .. this.free_index + src.length] =
                cast(ubyte[]) src[0 .. $];
        this.free_index = this.free_index + src.length;

        return total;
    }

    /***************************************************************************

        Return the upstream sink.

    ***************************************************************************/

    public OutputStream output ()
    {
        return file;
    }

    /**************************************************************************

        Write the current buffer rounding to the block size (and setting the
        padding bytes to padding_byte).

        Params:
            padding_byte = Byte to use to fill the padding.

        Returns:
            Number of bytes that have been flushed.

    **************************************************************************/

    public size_t flushWithPadding ( ubyte padding_byte = 0 )
    {
        assert (this.file.fileHandle != -1);

        if (this.free_index == 0)
            return 0;

        if ((this.free_index % this.BLOCK_SIZE) != 0)
        {
            auto hole = BLOCK_SIZE - this.free_index % BLOCK_SIZE;
            this.buffer[this.free_index .. this.free_index+hole] = padding_byte;
            this.free_index += hole;
        }

        size_t written = 0;
        while (written < this.free_index)
        {
            written =+ this.file.write(buffer[written .. this.free_index]);
        }

        this.free_index = 0;

        return written;
    }

    /**************************************************************************

        Instructs the OS to flush it's internal buffers to the disk device.

    **************************************************************************/

    public void sync ( )
    {
        assert (this.file.fileHandle != -1);
        this.file.sync();
    }

}


/*******************************************************************************

    Buffered file to do direct IO reads.

    Please read the module documentation for details.

*******************************************************************************/

public class BufferedDirectReadFile: InputStream
{

    /***************************************************************************

        File to do direct IO reads.

        Actually there is no way to open files with File specifying custom
        flags that is not sub-classing. Bummer!

    ***************************************************************************/

    static private class DirectReadFile : File
    {
        override public void open (cstring path, Style style = this.ReadExisting)
        {
            if (!super.open(path, style, O_DIRECT))
                this.error();
        }
    }

    /***************************************************************************

        Direct I/O file device to read from.

    ***************************************************************************/

    private DirectReadFile file;

    /***************************************************************************

        Internal pointer to data we already read but is still pending, waiting
        for a reader.

    ***************************************************************************/

    protected size_t pending_index;

    /***************************************************************************

        Constructs a new BufferedDirectReadFile.

        See notes in BufferedDirectWriteFile about the default buffer size.

        Params:
            path = Path of the file to read from.
            buffer = Buffer to use for reading, the length must be multiple of
                     the BLOCK_SIZE and the memory must be aligned to the
                     BLOCK_SIZE

    ***************************************************************************/

    public this (cstring path, ubyte[] buffer)
    {
        this.setBuffer(buffer);
        this.pending_index = 0;
        this.file = this.newFile();
        if (path.length > 0)
            this.file.open(path);
    }

    /***************************************************************************

        Instantiates the file object to be used to read from. This method may be
        overridden by derived classes, allowing different types of file to be
        used with this class.

        Returns:
            file object to read from

    ***************************************************************************/

    protected DirectReadFile newFile ( )
    {
        return new DirectReadFile;
    }

    /***************************************************************************

        Constructs a new BufferedDirectReadFile allocating a new buffer.

        See documentation for this(cstring, ubyte[]) for details.

        Params:
            path = Path of the file to read from.
            buffer_blocks = Buffer size in blocks (default 32MiB)

    ***************************************************************************/

    public this (cstring path = null, size_t buffer_blocks = 32 * 2 * 1024)
    {
        this(path, new ubyte[buffer_blocks * BLOCK_SIZE]);
    }

    /***************************************************************************

        Mixin for common functionality.

    ***************************************************************************/

    mixin AlignedBufferedStream;

    /***************************************************************************

        Open a BufferedDirectReadFile file.

        Params:
            path = Path of the file to read from.

    ***************************************************************************/

    public void open (cstring path)
    {
        assert (this.file.fileHandle == -1);
        this.file.open(path);
        this.free_index = 0;
        this.pending_index = 0;
    }

    /***************************************************************************

        Return the host conduit.

    ***************************************************************************/

    public IConduit conduit ()
    {
        return this.file;
    }

    /***************************************************************************

        Close the underlying file, but calling sync() first.

    ***************************************************************************/

    public void close ()
    {
        if (this.file.fileHandle == -1)
            return;
        this.sync();
        this.file.close();
    }

    /***************************************************************************

        Read from stream to a destination array. The content read from the
        stream will be stored in the provided dst.

        Returns the number of bytes written to dst, which may be less than
        dst.length. Eof is returned when an end-of-flow condition arises.

    ***************************************************************************/

    public size_t read (void[] dst)
    {
        assert (this.file.fileHandle != -1);

        if (dst.length == 0)
            return 0;

        size_t bytes_read = 0;

        // Read from pending data (that was read in a previous read())
        auto pending_len = this.free_index - this.pending_index;
        if (pending_len > 0)
        {
            if (dst.length <= pending_len)
            {
                pending_len = dst.length;
            }

            bytes_read += pending_len;
            dst[0 .. pending_len] = this.buffer[this.pending_index ..
                                                this.pending_index + pending_len];
            this.pending_index += pending_len;
            dst = dst[pending_len .. $];
        }

        // Reset if we don't have pending data to make next read more efficient
        if (this.pending_index == this.free_index)
        {
            this.free_index = 0;
            this.pending_index = 0;
        }

        // There is no pending data at this point, we work only with the
        // free_index. Also, we know free_index and pending_index got reset to 0

        // Optimization: avoid extra copy if dst is already aligned to the
        // block size
        if (this.free_index == 0 && this.isAligned(dst.ptr))
        {
            while (dst.length >= this.buffer.length)
            {
                auto r = this.file.read(dst[0 .. this.buffer.length]);

                if (r == this.file.Eof)
                {
                    return bytes_read ? bytes_read : r;
                }

                bytes_read += r;
                dst = dst[r .. $];
            }
        }

        // Read whole buffer chunks as long as needed
        while (dst.length > 0)
        {
            auto r = this.file.read(buffer);

            if (r == this.file.Eof)
            {
                return bytes_read ? bytes_read : r;
            }

            // Pass to the upper-level as if we just had read dst.length if we
            // read more (and set the internal pending data state properly)
            if (r >= dst.length)
            {
                this.pending_index = dst.length;
                this.free_index = r;
                r = dst.length;
            }

            bytes_read += r;
            dst[0 .. r] = buffer[0 .. r];
            dst = dst[r .. $];
        }

        return bytes_read;
    }

    /***************************************************************************

        Throws IOException because is not implemented.

    ***************************************************************************/

    void[] load (size_t max = -1)
    {
        throw new IOException("load() not supported by " ~
                this.classinfo.name);
    }

    /***************************************************************************

        Return the upstream sink.

    ***************************************************************************/

    public InputStream input ()
    {
        return file;
    }

    /**************************************************************************

        Instructs the OS to flush it's internal buffers to the disk device.

    **************************************************************************/

    public void sync ( )
    {
        assert (this.file.fileHandle != -1);
        this.file.sync();
    }

}

