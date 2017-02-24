/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version:
            Mar 2004: Initial release$(BR)
            Dec 2006: Outback release$(BR)
            Nov 2008: relocated and simplified

        Authors:
            Kris,
            John Reimer,
            Anders F Bjorklund (Darwin patches),
            Chris Sauls (Win95 file support)

*******************************************************************************/

module ocean.io.device.File;

import ocean.transition;

import ocean.sys.Common;

import ocean.io.device.Device;

import ocean.stdc.stringz;
import core.stdc.string;
import ocean.stdc.errno;

/*******************************************************************************

        platform-specific functions

*******************************************************************************/

import ocean.stdc.posix.unistd;


/*******************************************************************************

        Implements a means of reading and writing a generic file. Conduits
        are the primary means of accessing external data, and File
        extends the basic pattern by providing file-specific methods to
        set the file size, seek to a specific file position and so on.

        Serial input and output is straightforward. In this example we
        copy a file directly to the console:
        ---
        // open a file for reading
        auto from = new File ("test.txt");

        // stream directly to console
        Stdout.copy (from);
        ---

        And here we copy one file to another:
        ---
        // open file for reading
        auto from = new File ("test.txt");

        // open another for writing
        auto to = new File ("copy.txt", File.WriteCreate);

        // copy file and close
        to.copy.close;
        from.close;
        ---

        You can use InputStream.load() to load a file directly into memory:
        ---
        auto file = new File ("test.txt");
        auto content = file.load;
        file.close;
        ---

        Or use a convenience static function within File:
        ---
        auto content = File.get ("test.txt");
        ---

        A more explicit version with a similar result would be:
        ---
        // open file for reading
        auto file = new File ("test.txt");

        // create an array to house the entire file
        auto content = new char [file.length];

        // read the file content. Return value is the number of bytes read
        auto bytes = file.read (content);
        file.close;
        ---

        Conversely, one may write directly to a File like so:
        ---
        // open file for writing
        auto to = new File ("text.txt", File.WriteCreate);

        // write an array of content to it
        auto bytes = to.write (content);
        ---

        There are equivalent static functions, File.set() and
        File.append(), which set or append file content respectively.

        File can happily handle random I/O. Here we use seek() to
        relocate the file pointer:
        ---
        // open a file for reading and writing
        auto file = new File ("random.bin", File.ReadWriteCreate);

        // write some data
        file.write ("testing");

        // rewind to file start
        file.seek (0);

        // read data back again
        char[10] tmp;
        auto bytes = file.read (tmp);

        file.close;
        ---

        Note that File is unbuffered by default - wrap an instance within
        ocean.io.stream.Buffered for buffered I/O.

        Compile with -version=Win32SansUnicode to enable Win95 &amp; Win32s file
        support.

*******************************************************************************/

class File : Device, Device.Seek, Device.Truncate
{
        import TangoException = ocean.core.Exception_tango;

        public alias Device.read  read;
        public alias Device.write write;

        /***********************************************************************

            Exception class thrown on errors.

        ***********************************************************************/

        public static class IOException: TangoException.IOException
        {
            import ocean.core.Exception: ReusableExceptionImplementation;

            mixin ReusableExceptionImplementation!() ReusableImpl;

            /*******************************************************************

                Sets the exception instance.

                Params:
                    file_path = path of the file
                    error_num = error code (defaults to .errno)
                    func_name = name of the method that failed
                    msg = message description of the error (uses stderr if empty)
                    file = file where exception is thrown
                    line = line where exception is thrown

            *******************************************************************/


            public typeof(this) set ( cstring file_path,
                    int error_num, istring func_name = "",
                    istring msg = "",
                    istring file = __FILE__, long line = __LINE__)
            {
                this.error_num = error_num;
                this.func_name = func_name;

                this.ReusableImpl.set(this.func_name, file, line);

                if (this.func_name.length)
                    this.ReusableImpl.append(": ");

                if (msg.length == 0)
                {
                    char[256] buf;
                    auto errmsg = fromStringz(strerror_r(this.error_num, buf.ptr,
                                buf.length));

                    this.ReusableImpl.append(errmsg);
                }
                else
                {
                    this.ReusableImpl.append(msg);
                }

                this.ReusableImpl.append(" on ").append(file_path);

                return this;
            }
        }

        /***********************************************************************

                Fits into 32 bits ...

        ***********************************************************************/

        align(1) struct Style
        {
                align(1):
                Access          access;                 /// Access rights.
                Open            open;                   /// How to open.
                Share           share;                  /// How to share.
                Cache           cache;                  /// How to cache.
        }

        /***********************************************************************

        ***********************************************************************/

        enum Access : ubyte     {
                                Read      = 0x01,       /// Is readable.
                                Write     = 0x02,       /// Is writable.
                                ReadWrite = 0x03,       /// Both.
                                }

        /***********************************************************************

        ***********************************************************************/

        enum Open : ubyte       {
                                Exists=0,               /// Must exist.
                                Create,                 /// Create or truncate.
                                Sedate,                 /// Create if necessary.
                                Append,                 /// Create if necessary.
                                New,                    /// Can't exist.
                                };

        /***********************************************************************

        ***********************************************************************/

        enum Share : ubyte      {
                                None=0,                 /// No sharing.
                                Read,                   /// Shared reading.
                                ReadWrite,              /// Open for anything.
                                };

        /***********************************************************************

        ***********************************************************************/

        enum Cache : ubyte      {
                                None      = 0x00,       /// Don't optimize.
                                Random    = 0x01,       /// Optimize for random.
                                Stream    = 0x02,       /// Optimize for stream.
                                WriteThru = 0x04,       /// Backing-cache flag.
                                };

        /***********************************************************************

            Read an existing file.

        ***********************************************************************/

        const Style ReadExisting = {Access.Read, Open.Exists};

        /***********************************************************************

            Read an existing file.

        ***********************************************************************/

        const Style ReadShared = {Access.Read, Open.Exists, Share.Read};

        /***********************************************************************

            Write on an existing file. Do not create.

        ***********************************************************************/

        const Style WriteExisting = {Access.Write, Open.Exists};

        /***********************************************************************

                Write on a clean file. Create if necessary.

        ***********************************************************************/

        const Style WriteCreate = {Access.Write, Open.Create};

        /***********************************************************************

                Read from the beginning, append at the end of the file.

        ***********************************************************************/

        const Style ReadWriteAppending = {Access.ReadWrite, Open.Append};

        /***********************************************************************

                Write at the end of the file.

        ***********************************************************************/

        const Style WriteAppending = {Access.Write, Open.Append};

        /***********************************************************************

                Read and write an existing file.

        ***********************************************************************/

        const Style ReadWriteExisting = {Access.ReadWrite, Open.Exists};

        /***********************************************************************

                Read &amp; write on a clean file. Create if necessary.

        ***********************************************************************/

        const Style ReadWriteCreate = {Access.ReadWrite, Open.Create};

        /***********************************************************************

                Read and Write. Use existing file if present.

        ***********************************************************************/

        const Style ReadWriteOpen = {Access.ReadWrite, Open.Sedate};


        // the file we're working with
        private cstring  path_;

        // the style we're opened with
        private Style   style_;

        /***********************************************************************

            Reusable exception instance

        ***********************************************************************/

        private IOException exception;

        /***********************************************************************

                Create a File for use with open().

                Note that File is unbuffered by default - wrap an instance
                within ocean.io.stream.Buffered for buffered I/O.

                Params:
                    exception = reusable exception instance to use, or null
                    to create a fresh one.

        ***********************************************************************/

        this (IOException exception = null)
        {
            this.exception = exception;
        }

        /***********************************************************************

                Create a File with the provided path and style.

                Note that File is unbuffered by default - wrap an instance
                within ocean.io.stream.Buffered for buffered I/O.

                Params:
                    exception = reusable exception instance to use, or null
                    to create a fresh one.

        ***********************************************************************/

        this (cstring path, Style style = ReadExisting,
                IOException exception = null)
        {
                this(exception);
                open (path, style);
        }

        /***********************************************************************

                Return the Style used for this file.

        ***********************************************************************/

        Style style ()
        {
                return style_;
        }

        /***********************************************************************

                Return the path used by this file.

        ***********************************************************************/

        override istring toString ()
        {
                return idup(path_);
        }

        /***********************************************************************

                Convenience function to return the content of a file.

        ***********************************************************************/

        static void[] get (cstring path)
        {
            void[] dst;
            return get(path, dst);
        }

        /***********************************************************************

                Convenience function to return the content of a file.

                This overload takes a slice to a reusable buffer which is
                expanded as needed.
                Content size is determined via the file-system, per
                File.length, although that may be misleading for some
                *nix systems. An alternative is to use File.load which
                loads content until an Eof is encountered.


        ***********************************************************************/
        static void[] get (cstring path, ref void[] dst)
        {
                scope file = new File (path);

                // allocate enough space for the entire file
                auto len = cast(size_t) file.length;
                if (dst.length < len){
                    if (dst is null){ // avoid setting the noscan attribute, one should maybe change the return type
                        dst=new ubyte[](len);
                    } else {
                        dst.length = len;
                        enableStomping(dst);
                    }
                }

                //read the content
                len = file.read (dst);
                if (len is file.Eof)
                    file.error ("File.read :: unexpected eof");

                return dst [0 .. len];
        }

        /***********************************************************************

                Convenience function to set file content and length to
                reflect the given array.

        ***********************************************************************/

        static void set (cstring path, void[] content)
        {
                scope file = new File (path, ReadWriteCreate);
                file.write (content);
        }

        /***********************************************************************

                Convenience function to append content to a file.

        ***********************************************************************/

        static void append (cstring path, void[] content)
        {
                scope file = new File (path, WriteAppending);
                file.write (content);
        }


        /***********************************************************************

            Low level open for sub-classes that need to apply specific attributes.

            Return:
                False in case of failure.

        ***********************************************************************/

        protected bool open (cstring path, Style style,
                             int addflags, int access = 0x1B6 /* octal 0666 */)
        {
            alias int[] Flags;

            const Flags Access =
                [
                    0,                      // invalid
                    O_RDONLY,
                    O_WRONLY,
                    O_RDWR,
                    ];

            const Flags Create =
                [
                    0,                      // open existing
                    O_CREAT | O_TRUNC,      // truncate always
                    O_CREAT,                // create if needed
                    O_APPEND | O_CREAT,     // append
                    O_CREAT | O_EXCL,       // can't exist
                    ];

            const short[] Locks =
                [
                    F_WRLCK,                // no sharing
                    F_RDLCK,                // shared read
                    ];

            // remember our settings
            assert(path);
            path_ = path;
            style_ = style;

            // zero terminate and convert to utf16
            char[512] zero = void;
            auto name = toStringz (path, zero);
            auto mode = Access[style.access] | Create[style.open];

            handle = posix.open (name, mode | addflags, access);
            if (handle is -1)
                return false;

            return true;
        }

        /***********************************************************************

            Open a file with the provided style.

            Note that files default to no-sharing. That is, they are locked
            exclusively to the host process unless otherwise stipulated.
            We do this in order to expose the same default behaviour as Win32.

            $(B No file locking for borked POSIX.)

        ***********************************************************************/

        void open (cstring path, Style style = ReadExisting)
        {
            if (! open (path, style, 0))
                error(.errno, "open");
        }

        /***********************************************************************

            Set the file size to be that of the current seek position.
            The file must be writable for this to succeed.

        ***********************************************************************/

        void truncate ()
        {
            truncate (position);
        }

        /***********************************************************************

            Set the file size to be the specified length.
            The file must be writable for this to succeed.

        ***********************************************************************/

        override void truncate (long size)
        {
            // set filesize to be current seek-position
            if (posix.ftruncate (handle, cast(off_t) size) is -1)
                error(.errno, "ftruncate");
        }

        /***********************************************************************

            Set the file seek position to the specified offset
            from the given anchor.

        ***********************************************************************/

        override long seek (long offset, Anchor anchor = Anchor.Begin)
        {
            long result = posix.lseek (handle, cast(off_t) offset, anchor);
            if (result is -1)
                error(.errno, "seek");
            return result;
        }

        /***********************************************************************

            Return the current file position.

        ***********************************************************************/

        long position ()
        {
            return seek (0, Anchor.Current);
        }

        /***********************************************************************

            Return the total length of this file.

        ***********************************************************************/

        long length ()
        {
            stat_t stats = void;
            if (posix.fstat (handle, &stats))
                error(.errno, "fstat");
            return cast(long) stats.st_size;
        }

        /***********************************************************************

            Instructs the OS to flush it's internal buffers to the disk device.

            NOTE: due to OS and hardware design, data flushed
            cannot be guaranteed to be actually on disk-platters.
            Actual durability of data depends on write-caches,
            barriers, presence of battery-backup, filesystem and
            OS-support.

        ***********************************************************************/

        void sync ()
        {
            if (fsync (handle))
                error(.errno, "fsync");
        }

        /*******************************************************************

            Throw a potentially reusable IOException, with the provided
            message, function name and error code.

            Params:
                error_num = error code
                func_name = name of the method that failed
                msg = message description of the error (uses stderr if empty)
                file = file where exception is thrown
                line = line where exception is thrown

        *******************************************************************/

        public override void error ( int error_code, istring func_name,
                istring msg = "", istring file = __FILE__, long line = __LINE__ )
        {
            if (this.exception is null)
            {
                this.exception = new IOException;
            }

            throw this.exception.set(this.path_, error_code, func_name, msg, file, line);
        }

        /***********************************************************************

                Throw an IOException, with the provided message.

        ***********************************************************************/

        public alias Conduit.error error;

        /***********************************************************************

                Throw an IOException noting the last error.

        ***********************************************************************/

        public alias Device.error error;
}

debug (File)
{
        import ocean.io.Stdout_tango;

        void main()
        {
                char[10] ff;

                auto file = new File("file.d");
                auto content = cast(cstring) file.load (file);
                assert (content.length is file.length);
                assert (file.read(ff) is file.Eof);
                assert (file.position is content.length);
                file.seek (0);
                assert (file.position is 0);
                assert (file.read(ff) is 10);
                assert (file.position is 10);
                assert (file.seek(0, file.Anchor.Current) is 10);
                assert (file.seek(0, file.Anchor.Current) is 10);
        }
}
