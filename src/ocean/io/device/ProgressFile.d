/*******************************************************************************

    File device, derived from ocean.io.device.File and providing a callback
    which is invoked whenever data is transmitted (read or written). The
    callback notifies the user how many bytes were transmitted, as well as the
    total number of bytes transmitted since the file was opened.

    Usage example:

    ---

        import ocean.io.device.ProgressFile;
        import ocean.io.Stdout_tango;

        // Delegate called when data is read/written
        void progress ( size_t bytes, ulong total_bytes )
        {
            Stdout.formatln("{} bytes written, {} in total", bytes, total_bytes);
        }

        auto file = new ProgressFile("test.tmp", &progress, ProgressFile.WriteCreate);

        file.write("hello");

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.device.ProgressFile;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.io.device.File;



class ProgressFile : File
{
    /***************************************************************************

        Delegate to report progress of file transmission.

    ***************************************************************************/

    public alias void delegate ( size_t bytes, ulong total_bytes ) ProgressDg;

    private ProgressDg progress_dg;


    /***************************************************************************

        Internal count of total bytes transmitted. Reset to 0 when open() is
        called.

    ***************************************************************************/

    private ulong total_bytes;


    /***************************************************************************

        Aliases for the various file access styles, to avoid needing to import
        File as well.

    ***************************************************************************/

    public alias File.ReadExisting ReadExisting;
    public alias File.ReadShared ReadShared;
    public alias File.WriteExisting WriteExisting;
    public alias File.WriteCreate WriteCreate;
    public alias File.WriteAppending WriteAppending;
    public alias File.ReadWriteExisting ReadWriteExisting;
    public alias File.ReadWriteCreate ReadWriteCreate;
    public alias File.ReadWriteOpen ReadWriteOpen;


    /***************************************************************************

        Create a File without opening a path.

        Note that File is unbuffered by default - wrap an instance
        within ocean.io.stream.Buffered for buffered I/O.

        Params:
            progress_dg = delegate to notify of progress

    ***************************************************************************/

    public this ( ProgressDg progress_dg )
    in
    {
        assert(progress_dg !is null, typeof(this).stringof ~ ": progress delegate is null, what's the point?");
    }
    body
    {
        this.progress_dg = progress_dg;
    }


    /***************************************************************************

        Create a File with the provided path and style.

        Note that File is unbuffered by default - wrap an instance
        within ocean.io.stream.Buffered for buffered I/O.

        Params:
            progress_dg = delegate to notify of progress
            path = file path
            style = access style of file

    ***************************************************************************/

    public this ( ProgressDg progress_dg, char[] path, Style style = ReadExisting )
    in
    {
        assert(progress_dg !is null, typeof(this).stringof ~ ": progress delegate is null, what's the point?");
    }
    body
    {
        this(progress_dg);
        this.open(path, style);
    }


    /***************************************************************************

        Create a File with the provided path and style. Resets the internal
        bytes counter.

        Params:
            path = file path
            style = access style of file

    ***************************************************************************/

    override public void open ( cstring path, Style style = ReadExisting )
    {
        this.total_bytes = 0;
        super.open(path, style);
    }


    /***************************************************************************

        Reads bytes from the file, notifies the process delegate how many bytes
        were received.

        Params:
            dst = buffer to read into

    ***************************************************************************/

    override public size_t read ( void[] dst )
    {
        auto bytes = super.read(dst);

        this.total_bytes += bytes;

        this.progress_dg(bytes, this.total_bytes);

        return bytes;
    }


    /***************************************************************************

        Writes bytes to the file, notifies the process delegate how many bytes
        were written.

        Params:
            src = data to write

    ***************************************************************************/

    override public size_t write ( Const!(void)[] src )
    {
        auto bytes = super.write(src);

        this.total_bytes += bytes;

        this.progress_dg(bytes, this.total_bytes);

        return bytes;
    }
}

