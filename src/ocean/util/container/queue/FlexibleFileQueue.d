/*******************************************************************************

    File-based queue implementation.

    The flexible file queue can be set to either open any existing files it
    finds, or always delete existing files when it is created using the
    open_existing parameter in the contructor.

    Note that the queue file is deleted in the following cases:
        1. Upon calling the clear() method.
        2. Upon calling pop() on an empty queue.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.queue.FlexibleFileQueue;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.util.container.queue.model.IByteQueue;

import ocean.util.container.queue.model.IQueueInfo;

import ocean.util.container.queue.FlexibleRingQueue;

import ocean.util.log.Log;

import ocean.io.stream.Buffered,
       ocean.io.device.File,
       Filesystem = ocean.io.Path;



/*******************************************************************************

    Static module logger

*******************************************************************************/

static private Logger log;
static this ( )
{
    log = Log.lookup("ocean.util.container.queue.FlexibleFileQueue");
}



public class FlexibleFileQueue : IByteQueue
{
    /***************************************************************************

        Header for queue items

    ***************************************************************************/

    private struct Header
    {
        size_t length;

        static Header* fromSlice ( void[] slice )
        {
            return cast(Header*) slice.ptr;
        }
    }

    /***************************************************************************

        Buffer used to support ubyte[] push ( size_t )

    ***************************************************************************/

    private ubyte[] slice_push_buffer;

    /***************************************************************************

        Path to write to

    ***************************************************************************/

    private mstring path;

    /***************************************************************************

        Extension of the index file (appended to `path`)

    ***************************************************************************/

    private const istring IndexExtension = ".index";

    /***************************************************************************

        Path to the index file to write to if we want to be able to reopen
        any saved data files

    ***************************************************************************/

    private mstring index_path;

    /***************************************************************************

        External file that is being written to

    ***************************************************************************/

    private File file_out;

    /***************************************************************************

        External file that is being read from

    ***************************************************************************/

    private File file_in;

    /***************************************************************************

        External index file that is being read from

    ***************************************************************************/

    private File file_index;

    /***************************************************************************

        Buffered output stream to write to the file

    ***************************************************************************/

    private BufferedOutput ext_out;

    /***************************************************************************

        Buffered input stream to write to the file

    ***************************************************************************/

    private BufferedInput ext_in;

    /***************************************************************************

        Unread bytes in the file

    ***************************************************************************/

    private size_t bytes_in_file;

    /***************************************************************************

        Unread items in the file

    ***************************************************************************/

    private size_t items_in_file;

    /***************************************************************************

        Size of the file read buffer. It is not possible to push items which are
        larger than this buffer size.

    ***************************************************************************/

    private size_t size;

    /***************************************************************************

        bool set if the files are currently open

    ***************************************************************************/

    private bool files_open;

    /***************************************************************************

        bool set if we want to reopen any saved data files if we restart the
        application.

    ***************************************************************************/

    private bool open_existing;

    /***************************************************************************

        buffer used to read in the index file

    ***************************************************************************/

    private void[] content;

    /***************************************************************************

        Constructor. Creates and opens the files and buffered inputs and
        outputs. Moves the file pointers to the correct position in the files
        and marks the files as open.

        Params:
            path  = path to the file that will be used to swap the queue
            size = size of file read buffer (== maximum item size)
            open_existing = do we reopen any existing file queues

    ***************************************************************************/

    public this ( cstring path, size_t size, bool open_existing = false )
    {
        this.path  = path.dup;
        this.index_path = path.dup ~ IndexExtension;
        this.size = size;
        this.open_existing = open_existing;

        if ( this.open_existing && this.exists(this.path) )
        {
            this.file_out = new File(this.path, File.WriteAppending);
            this.file_index = new File(this.index_path, File.ReadWriteExisting);
            this.readIndex();
        }
        else
        {
            this.file_out = new File(this.path, File.WriteCreate);
            if ( this.open_existing )
            {
                this.file_index = new File(this.index_path, File.ReadWriteCreate);
            }
        }

        this.file_in = new File(this.path, File.ReadExisting);

        this.ext_out = new BufferedOutput(this.file_out);
        this.ext_out.seek(this.file_out.length);
        this.ext_in = new BufferedInput(this.file_in, this.size+Header.sizeof);
        this.ext_in.seek(this.file_out.length - this.bytes_in_file);

        this.files_open = true;
    }


    /***************************************************************************

        Checks whether a file and the associated index file exist at the
        specified path.

        Note that this function allocates on every call! It is only intended to
        be called during application startup.

        Params:
            path = path to check (".index" is appended to check for the
                corresponding index file)

        Returns:
            true if the specified file and index file exist

    ***************************************************************************/

    public static bool exists ( cstring path )
    {
        return Filesystem.exists(path)
            && Filesystem.exists(path ~ IndexExtension);
    }


    /***************************************************************************

        Pushes an item into the queue.

        Params:
            item = data item to push

        Returns:
            true if the item was pushed successfully, false if it didn't fit

    ***************************************************************************/

    public bool push ( ubyte[] item )
    in
    {
        assert ( item.length <= this.size,
                 "Read buffer too small to process this item");
    }
    body
    {
        this.handleSliceBuffer();

        if ( item.length == 0 ) return false;

        return this.filePush(item);
    }


    /***************************************************************************

        Reserves space for an item of <size> bytes on the queue but doesn't
        fill the content. The caller is expected to fill in the content using
        the returned slice.

        Params:
            size = size of the space of the item that should be reserved

        Returns:
            slice to the reserved space if it was successfully reserved,
            else null

    ***************************************************************************/

    public ubyte[] push ( size_t size )
    {
        this.handleSliceBuffer();

        this.slice_push_buffer.length = size;

        return this.slice_push_buffer;
    }


    /***************************************************************************

        Reads an item from the queue.

        Params:
            eat = whether to remove the item from the queue

        Returns:
            item read from queue, may be null if queue is empty

    ***************************************************************************/

    private ubyte[] getItem ( bool eat = true )
    {
        this.handleSliceBuffer();

        if ( this.bytes_in_file == 0 && this.files_open )
        {
            this.closeExternal();
            return null;
        }

        if ( this.bytes_in_file > 0 ) try
        {
            try this.ext_out.flush();
            catch ( Exception e )
            {
                log.error("## ERROR: Can't flush file buffer: {}", getMsg(e));
                return null;
            }

            Header h;

            if ( this.ext_in.readable() <= Header.sizeof && this.fill() == 0 )
            {
                return null;
            }

            h = *Header.fromSlice(this.ext_in.slice(Header.sizeof, false));

            assert ( h.length <= this.size, "Unrealistic size" );

            if ( h.length + Header.sizeof > this.ext_in.readable() &&
                 this.fill() == 0 )
            {
                return null;
            }

            if ( eat )
            {
                this.items_in_file -= 1;
                this.bytes_in_file -= Header.sizeof + h.length;

                this.writeIndex();
            }

            return cast(ubyte[]) this.ext_in.slice(Header.sizeof + h.length,
                                                   eat)[Header.sizeof .. $];
        }
        catch ( Exception e )
        {
            log.error("## ERROR: Failsafe catch triggered by exception: {} ({}:{})",
                           getMsg(e), e.file, e.line);
        }

        return null;
    }


    /***************************************************************************

        Popps the next element

        Returns:
            item read from queue, may be null if queue is empty

    ***************************************************************************/

    public ubyte[] pop ( )
    {
        return this.getItem();
    }


    /***************************************************************************

        Returns the element that would be popped next, without poppin' it

    ***************************************************************************/

    public ubyte[] peek ( )
    {
        return this.getItem(false);
    }


    /***************************************************************************

        Fills the read buffer

        Returns:
            How many new bytes were read from the file

    ***************************************************************************/

    private size_t fill ( )
    {
        this.ext_in.compress();

        auto bytes    = this.ext_in.populate();
        auto readable = this.ext_in.readable;

        if ( (bytes == 0 || bytes == File.Eof) &&
             readable == 0 )
        {
            this.closeExternal();
            return 0;
        }

        return bytes;
    }


    /***************************************************************************

        Finds out whether the provided number of bytes will fit in the queue.

        Due to the file swap, we have unlimited space, so always return true.

        Params:
            bytes = size of item to check

        Returns:
            always true

    ***************************************************************************/

    public bool willFit ( size_t bytes )
    {
        return true;
    }


    /***************************************************************************

        Returns:
            total number of bytes used by queue (used space + free space)

    ***************************************************************************/

    public ulong total_space ( )
    {
        return 0;
    }


    /***************************************************************************

        Returns:
            number of bytes stored in queue

    ***************************************************************************/

    public ulong used_space ( )
    {
        return this.bytes_in_file + this.slice_push_buffer.length;
    }


    /***************************************************************************

        Returns:
            number of bytes free in queue

    ***************************************************************************/

    public size_t free_space ( )
    {
        return 0;
    }


    /***************************************************************************

        Returns:
            the number of items in the queue

    ***************************************************************************/

    public size_t length ( )
    {
        return this.items_in_file + (this.slice_push_buffer.length > 0 ? 1 : 0);
    }


    /***************************************************************************

        Tells whether the queue is empty.

        Returns:
            true if the queue is empty

    ***************************************************************************/

    public bool is_empty ( )
    {
        return this.items_in_file == 0 && this.slice_push_buffer.length == 0;
    }


    /***************************************************************************

        Deletes all items

    ***************************************************************************/

    public void clear ( )
    {
        this.items_in_file = this.bytes_in_file = 0;
        this.slice_push_buffer.length = 0;
        this.closeExternal();
    }



    /***************************************************************************

        Pushes the buffered slice from a previous slice-push operation

    ***************************************************************************/

    private void handleSliceBuffer ( )
    {
        if ( this.slice_push_buffer.length != 0 )
        {
            (!this.files_open) && this.openExternal();

            this.filePush(this.slice_push_buffer);
            this.slice_push_buffer.length = 0;
        }
    }


    /***************************************************************************

        Pushes item into file. If the file queue is set to re-open then flush
        the write buffer after each push so that the files and index do not get
        out of sync.

        Params:
            item = data to push

        Returns:
            true when write was successful, else false

    ***************************************************************************/

    private bool filePush ( in ubyte[] item )
    in
    {
        assert ( item.length <= this.size, "Pushed item will not fit read buffer");
        assert ( item.length > 0, "denied push of item of size zero");
    }
    body
    {
        try
        {
            (!this.files_open) && this.openExternal();

            Header h = Header(item.length);

            ubyte[] header = (cast(ubyte*)&h)[0 .. Header.sizeof];

            this.ext_out.write(header);
            this.ext_out.write(item);

            if ( this.open_existing )
            {
                this.ext_out.flush();
            }

            this.bytes_in_file += Header.sizeof + item.length;
            this.items_in_file += 1;

            this.writeIndex();

            return true;
        }
        catch ( Exception e )
        {
            log.error("## ERROR: Exception happened while writing to disk: {}", getMsg(e));
            return false;
        }
    }


    /***************************************************************************

        If the file queue is set to re-open, write the current index position
        in the file to the index file.

    ***************************************************************************/

    private void writeIndex ( )
    {
        if ( this.open_existing )
        {
            this.file_index.seek(0);
            this.file_index.write(cast(void[])(&this.bytes_in_file)
                [0..this.bytes_in_file.sizeof]);
            this.file_index.write(cast(void[])(&this.items_in_file)
                [0..this.items_in_file.sizeof]);
        }
    }


    /***************************************************************************

        If the file queue is set to re-open, read the saved index in to memory.
        Set the void array to the correct length to read the result, seek to
        the start of the index file, then cast the results from void[] arrays
        to size_t values.

    ***************************************************************************/

    private void readIndex ( )
    {
        if ( this.open_existing )
        {
            void[] content;
            content.length = this.bytes_in_file.sizeof +
                this.items_in_file.sizeof;

            this.file_index.seek(0);

            if ( this.file_index.read(content) == (this.bytes_in_file.sizeof +
                this.items_in_file.sizeof) )
            {
                this.bytes_in_file =
                    *cast(size_t*)content[0..this.bytes_in_file.sizeof].ptr;
                this.items_in_file =
                    *cast(size_t*)content[this.bytes_in_file.sizeof..$].ptr;
            }
        }
    }


    /***************************************************************************

        Opens the files and associated buffers. Only open the index file if
        this file queue is set to be able to reopen. Mark the files open.

    ***************************************************************************/

    private void openExternal ( )
    {
        this.file_out.open(this.path, File.WriteCreate);
        this.file_in.open(this.path, File.ReadExisting);

        if ( this.open_existing )
        {
            this.file_index.open(this.index_path, File.WriteCreate);
        }

        this.files_open = true;
    }


    /***************************************************************************

        Closes the files and clear the related buffers. Mark the files closed.

    ***************************************************************************/

    private void closeExternal ( )
    in
    {
        assert ( this.ext_in.readable() == 0,
                 "Still unread data in input buffer" );

        assert ( this.bytes_in_file - this.ext_in.readable() == 0 ,
                 "Still bytes in the file");

        assert ( this.items_in_file - this.ext_in.readable() == 0 ,
                 "Still items in the file");
    }
    body
    {
        this.ext_in.clear();
        this.ext_out.clear();
        this.file_out.close();
        this.file_in.close();

        Filesystem.remove(this.path);

        if ( this.open_existing )
        {
            this.file_index.close();
            Filesystem.remove(this.index_path);
        }

        this.files_open = false;
    }

}

/***************************************************************************

    Unit test

***************************************************************************/

version (UnitTest)
{
    import ocean.text.util.StringC;
    import ocean.io.Stdout;
    import ocean.stdc.posix.unistd;
    import ocean.stdc.posix.stdlib: mkdtemp;
}

unittest
{
    // TODO Remove I/O from this test
    auto test_dir = StringC.toDString(mkdtemp("Dunittest-XXXXXX\0".dup.ptr));
    if (test_dir.length == 0)
    {
        Stderr.formatln("{}:{}: Can't create temporary directory "
              ~ "for unittest, skipping...", __FILE__, __LINE__);
        return;
    }
    scope (exit) rmdir(test_dir.ptr);

    auto test_file = (test_dir ~ "/testfile\0")[0..$-1];
    scope (exit) unlink(test_file.ptr);

    auto test_file_index = (test_dir ~ "/testfile.index\0")[0..$-1];
    scope (exit) unlink(test_file_index.ptr);

    for ( int open_existing = 0; open_existing < 2; open_existing++ )
    {
        for (ubyte size; size < ubyte.max; size++)
        {
            auto queue = new FlexibleFileQueue(test_file, 4, cast(bool)open_existing);

            for ( ubyte i = 0; i < size; i++ )
            {
                auto item = [i, cast(ubyte) (ubyte.max-i), i, cast(ubyte) (i*i)];
                assert( queue.push( item ), "push failed" );
            }

            for ( ubyte i = 0; i < size; i++ )
            {
                auto pop = queue.pop;
                auto item = [i, ubyte.max-i, i, cast(ubyte) (i*i)];
                assert( pop == item, "pop failed "~pop.stringof );
            }

            queue.closeExternal();
        }
    }
}

