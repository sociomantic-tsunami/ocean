/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: May 2005: Initial release

        Authors: Kris

*******************************************************************************/

module ocean.io.device.Device;

import ocean.transition;

import ocean.sys.Common;

public  import ocean.io.device.Conduit;

/*******************************************************************************

        Implements a means of reading and writing a file device. Conduits
        are the primary means of accessing external data, and this one is
        used as a superclass for the console, for files, sockets etc.

*******************************************************************************/

class Device : Conduit, ISelectable
{
        import core.stdc.errno;
        import core.sys.posix.sys.types: off_t;

        /// expose superclass definition also
        public alias Conduit.error error;

        /***********************************************************************

                Throw an IOException noting the last error.

        ***********************************************************************/

        final void error ()
        {
                error (this.toString ~ " :: " ~ SysError.lastMsg);
        }

        /***********************************************************************

                Return the name of this device.

        ***********************************************************************/

        override istring toString ()
        {
                return "<device>";
        }

        /***********************************************************************

                Return a preferred size for buffering conduit I/O.

        ***********************************************************************/

        override size_t bufferSize ()
        {
                return 1024 * 16;
        }

        /***********************************************************************

            Sets the device in the non-blocking mode.

            Throws:
                IOException if setting the device mode fails

        ***********************************************************************/

        public void setNonBlock ()
        {
            auto existing_flags = fcntl(this.fileHandle(), F_GETFL, 0);

            if (existing_flags == -1)
            {
                this.error(errno, "fcntl");
            }

            if (fcntl(this.fileHandle(), F_SETFL, existing_flags | O_NONBLOCK) < 0)
            {
                this.error(errno, "fcntl");
            }
        }

        /***********************************************************************

                 Unix-specific code.

        ***********************************************************************/

        version (Posix)
        {
                protected int handle = -1;

                /***************************************************************

                        Allow adjustment of standard IO handles.

                ***************************************************************/

                public void reopen (Handle handle)
                {
                        this.handle = handle;
                }

                /***************************************************************

                        Return the underlying OS handle of this Conduit.

                ***************************************************************/

                final Handle fileHandle ()
                {
                        return cast(Handle) handle;
                }

                /***************************************************************

                        Release the underlying file.

                ***************************************************************/

                override void detach ()
                {
                        if (handle >= 0)
                           {
                           //if (scheduler)
                               // TODO Not supported on Posix
                               // scheduler.close (handle, toString);
                           posix.close (handle);
                           }
                        handle = -1;
                }

                /***************************************************************

                        Read a chunk of bytes from the file into the provided
                        array. Returns the number of bytes read, or Eof where
                        there is no further data.

                ***************************************************************/

                override size_t read (void[] dst)
                {
                        ssize_t read;

                        do
                        {
                            read = posix.read (handle, dst.ptr, dst.length);
                        }
                        while (read == -1 && errno == EINTR);

                        if (read is -1)
                            error(errno, "read");
                        else
                           if (read is 0 && dst.length > 0)
                               return Eof;
                        return read;
                }

                /***************************************************************

                        Write a chunk of bytes to the file from the provided
                        array. Returns the number of bytes written, or Eof if
                        the output is no longer available.

                ***************************************************************/

                override size_t write (Const!(void)[] src)
                {
                        ssize_t written;

                        do
                        {
                            written = posix.write (handle, src.ptr, src.length);
                        }
                        while (written == -1 && errno == EINTR);

                        if (written is -1)
                            error(errno, "write");
                        return written;
                }

                /***************************************************************

                        Read a chunk of bytes from the file from the given
                        offset, into the provided array. Returns the number of
                        bytes read, or Eof where there is no further data.

                        Params:
                            dst = destination buffer to fill
                            offset = offset to start reading from

                        Returns:
                            number of bytes read or Eof if there's no further
                            data

                        Throws:
                            File.IOException on failure

                ***************************************************************/

                public size_t pread (void[] dst, off_t offset)
                {
                        ssize_t read;

                        do
                        {
                            read = posix.pread (handle, dst.ptr, dst.length,
                                offset);
                        }
                        while (read == -1 && errno == EINTR);

                        if (read is -1)
                            error(errno, "pread");
                        else
                           if (read is 0 && dst.length > 0)
                               return Eof;
                        return read;
                }

                /***************************************************************

                        Write a chunk of bytes to the file starting from the
                        given offset, from the provided array. Returns the
                        number of bytes written

                        Params:
                            src = source buffer to write data from
                            offset = offset to start writing from

                        Returns:
                            number of bytes written

                        Throws:
                            File.IOException on failure

                ***************************************************************/

                public size_t pwrite (Const!(void)[] src, off_t offset)
                {
                        ssize_t written;

                        do
                        {
                            written = posix.pwrite (handle, src.ptr, src.length,
                                    offset);
                        }
                        while (written == -1 && errno == EINTR);

                        if (written is -1)
                            error(errno, "pwrite");
                        return written;
                }
        }
}
