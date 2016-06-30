/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: March 2004

        Authors: Kris

*******************************************************************************/

module ocean.io.device.FileMap;

import ocean.transition;

import ocean.sys.Common;

import ocean.io.device.File,
               ocean.io.device.Array;

/*******************************************************************************

        External declarations.

*******************************************************************************/

version (Posix)
         import ocean.stdc.posix.sys.mman;


/*******************************************************************************

*******************************************************************************/

class FileMap : Array
{
        private MappedFile file;

        /***********************************************************************

                Construct a FileMap upon the given path.

                You should use resize() to setup the available
                working space.

        ***********************************************************************/

        this (cstring path, File.Style style = File.ReadWriteOpen)
        {
                file = new MappedFile (path, style);
                super (file.map);
        }

        /***********************************************************************

                Resize the file and return the remapped content. Usage of
                map() is not required following this call.

        ***********************************************************************/

        final ubyte[] resize (long size)
        {
                auto ret = file.resize (size);
                super.assign (ret);
                return ret;
        }

        /***********************************************************************

                Release external resources.

        ***********************************************************************/

        override void close ()
        {
                super.close;
                if (file)
                    file.close;
                file = null;
        }
}


/*******************************************************************************

*******************************************************************************/

class MappedFile
{
        private File host;

        /***********************************************************************

                Construct a FileMap upon the given path.

                You should use resize() to setup the available
                working space.

        ***********************************************************************/

        this (cstring path, File.Style style = File.ReadWriteOpen)
        {
                host = new File (path, style);
        }

        /***********************************************************************

        ***********************************************************************/

        final long length ()
        {
                return host.length;
        }

        /***********************************************************************

        ***********************************************************************/

        final istring path ()
        {
                return host.toString;
        }

        /***********************************************************************

                Resize the file and return the remapped content. Usage of
                map() is not required following this call.

        ***********************************************************************/

        final ubyte[] resize (long size)
        {
                host.truncate (size);
                return map;
        }

        /***********************************************************************

        ***********************************************************************/

        version (Posix)
        {
                // Linux code: not yet tested on other POSIX systems.
                private void*   base;           // array pointer
                private size_t  size;           // length of file

                /***************************************************************

                        Return a slice representing file content as a
                        memory-mapped array. Use this to remap content
                        each time the file size is changed.

                ***************************************************************/

                final ubyte[] map ()
                {
                        // be wary of redundant references
                        if (base)
                            reset;

                        // can only do 32bit mapping on 32bit platform
                        size = cast (size_t) host.length;

                        // Make sure the mapping attributes are consistant with
                        // the File attributes.
                        int flags = MAP_SHARED;
                        int protection = PROT_READ;
                        auto access = host.style.access;
                        if (access & host.Access.Write)
                            protection |= PROT_WRITE;

                        base = mmap (null, size, protection, flags, host.fileHandle, 0);
                        if (base is MAP_FAILED)
                           {
                           base = null;
                           host.error;
                           }

                        return (cast(ubyte*) base) [0 .. size];
                }

                /***************************************************************

                        Release this mapped buffer without flushing.

                ***************************************************************/

                final void close ()
                {
                        reset;
                        if (host)
                            host.close;
                        host = null;
                }

                /***************************************************************

                ***************************************************************/

                private void reset ()
                {
                        // NOTE: When a process ends, all mmaps belonging to that process
                        //       are automatically unmapped by system (Linux).
                        //       On the other hand, this is NOT the case when the related
                        //       file descriptor is closed.  This function unmaps explicitly.
                        if (base)
                            if (munmap (base, size))
                                host.error;

                        base = null;
                }

                /***************************************************************

                        Flush dirty content out to the drive.

                ***************************************************************/

                final MappedFile flush ()
                {
                        // MS_ASYNC: delayed flush; equivalent to "add-to-queue"
                        // MS_SYNC: function flushes file immediately; no return until flush complete
                        // MS_INVALIDATE: invalidate all mappings of the same file (shared)

                        if (msync (base, size, MS_SYNC | MS_INVALIDATE))
                            host.error;
                        return this;
                }
        }
}

///
unittest
{
    void example ( )
    {
        auto file = new MappedFile ("foo.map");
        auto heap = file.resize (1_000_000);
        file.close();

        auto file1 = new MappedFile ("foo1.map");
        auto heap1 = file1.resize (1_000_000);
        file1.close();
    }
}
