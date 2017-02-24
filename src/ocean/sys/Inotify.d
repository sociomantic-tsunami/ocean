/*******************************************************************************

    Linux File System event file descriptor.
    See http://man7.org/linux/man-pages/man7/inotify.7.html

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.Inotify;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.Traits;
import ocean.text.util.StringC;
import ocean.sys.ErrnoException;

import core.sys.linux.sys.inotify;
import core.sys.posix.fcntl;

import ocean.io.model.IConduit: ISelectable;

import ocean.stdc.posix.sys.types: ssize_t;
import ocean.stdc.posix.unistd: read, close;
import core.stdc.errno: EAGAIN, EWOULDBLOCK, errno;



/*******************************************************************************

    Inotify fd class

*******************************************************************************/

public class Inotify : ISelectable
{
    /***************************************************************************

        Exception class, thrown on errors with inotify functions

    ***************************************************************************/

    static public class InotifyException : ErrnoException { }


    /***************************************************************************

        Inotify exception instance.

    ***************************************************************************/

    private InotifyException e;


    /***************************************************************************

        Integer file descriptor provided by the operating system and used to
        manage the Inotify instance.

    ***************************************************************************/

    private int fd;


    /***************************************************************************

        Struct that enables the reading of events from iterator.

    ***************************************************************************/

    private static struct EventsIterator
    {
        /***********************************************************************

            The inotify instance which the events will be fetched

        ***********************************************************************/

        private Inotify outer;


        /***********************************************************************

            Iterator Operator overload - Iterates per inotify event fetched from
            the inotify instance of this struct.

            Returns:
                Result of each iteration

            Throws:
                upon failure to read inotify events

        ***********************************************************************/

        public int opApply ( int delegate ( ref inotify_event ) dg )
        {
            //255 is the default max filename length in linux)
            char[inotify_event.sizeof + 255 + 1] buffer_temp;
            void[] buffer = buffer_temp;

            int result = 0;

            ssize_t read_bytes;
            read_loop: while ( (read_bytes = read(this.outer.fd, buffer.ptr, buffer.length)) > 0 )
            {
                inotify_event *i_event;

                for ( uint i; i < read_bytes; i += inotify_event.sizeof + i_event.len  )
                {
                    i_event = cast(inotify_event*) &buffer[i];
                    result = dg(*i_event);

                    if (result)
                    {
                        break read_loop;
                    }
                }
            }

            return result;
        }
    }


    /***************************************************************************

        Constructor.

        Throws:
            upon failure to create a inotify instance (fd)

    ***************************************************************************/

    public this ( )
    {
        this(new InotifyException);
    }


    /***************************************************************************

        Constructor. Creates a Inotify file descriptor.

        Params:
            e = inotify exception instance to be used internally

        Throws:
            upon failure to create a inotify instance (fd)

    ***************************************************************************/

    public this ( InotifyException e )
    {
        this.e = e;
        this.fd = this.e.enforceRet!(inotify_init)(&verify).call();

        int flags  =  fcntl(this.fd, F_GETFL, 0);

        if ( fcntl(this.fd, F_SETFL, flags | O_NONBLOCK) < 0 )
        {
            scope (exit) errno = 0;

            int errnum = errno;

            throw this.e.set(errnum, identifier!(.fcntl));
        }
    }


    /***************************************************************************

        Required by ISelectable interface.

        Returns:
            file descriptor used to manage inotify event

    ***************************************************************************/

    public Handle fileHandle ( )
    {
        return cast(Handle)this.fd;
    }


    /***************************************************************************

        Manipulates  the  "watch  list"  associated  with an inotify instance.
        Each item ("watch") in the watch list specifies the pathname of a file
        or directory, along with some set of events that the kernel should
        monitor for the file referred to by that pathname. Either creates a new
        watch item, or modifies an existing watch. Each watch has a unique
        "watch descriptor", which is returned by this function.

        params:
            path   = File path to watch (directories are also supported)
            events = Inotify events that will be watched (bit mask)

        return:
             Unique "watch descriptor"

        Throws:
            upon failure to add the "watch descriptor"

    ***************************************************************************/

    public uint addWatch ( char[] path, uint events )
    {
        return cast(uint) this.e.enforceRet!(.inotify_add_watch)(&verify)
                      .call(this.fd, StringC.toCString(path), events);
    }


    /***************************************************************************

        Removes the provided item from the inotify instance.

        Returns:
            wd = "watch descriptor" that was removed (is no longer watched)

        Throws:
            upon failure to unwatch the "watch descriptor"

    ***************************************************************************/

    public uint rmWatch ( int wd )
    {
        return cast(uint) this.e.enforceRet!(.inotify_rm_watch)(&verify).call(this.fd, wd);
    }


    /***************************************************************************

        Reads the events associated to the inotify file descriptor, and return
        in the form of iterator

        Returns:
            EventsIterator containing all inotify events

        Throws:
            upon failure to read inotify events

    ***************************************************************************/

    public EventsIterator readEvents ( )
    {
        EventsIterator it;
        it.outer = this;

        return it;
    }


    /***************************************************************************

        Handy function to verify the success of system calls

        Params:
            fd = returned code by the system call

        Returns:
            True in case of success. False, otherwise.

    ***************************************************************************/

    private static bool verify ( int fd )
    {
        return fd >= 0;
    }


    /***************************************************************************

        Destructor. Destroys the inotify file descriptor.

    ***************************************************************************/

    ~this ( )
    {
        close(this.fd);
    }
}
