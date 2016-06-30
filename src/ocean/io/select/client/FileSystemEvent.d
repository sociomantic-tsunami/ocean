/*******************************************************************************

    File system event which can be registered with the
    EpollSelectDispatcher. The implementation uses inotify internally, see
    ocean.sys.Inotify and http://man7.org/linux/man-pages/man7/inotify.7.html

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.client.FileSystemEvent;




/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.sys.Inotify;
import ocean.sys.linux.inotify;

import ocean.stdc.posix.unistd;;

import ocean.io.select.EpollSelectDispatcher;
import ocean.io.select.client.model.ISelectClient: ISelectClient;



/***************************************************************************

    Convenience alias

***************************************************************************/

public alias EventBitMask FileEventsEnum;


class FileSystemEvent : ISelectClient
{
    /***************************************************************************

        Alias for event handler delegate.

    ***************************************************************************/

    public alias void delegate ( char[] path, uint event ) Handler;


    /***************************************************************************

        Inotify wrapper

    ***************************************************************************/

    private Inotify fd;


    /***************************************************************************

        Event handler delegate, specified in the constructor and called whenever
        a watched file system event fires.

    ***************************************************************************/

    private Handler handler;


    /***************************************************************************

        Associative array which maps inotify "watch descriptor" against "path".
        When a watch is performed in inotify, a new entry is created in this array.
        On the other hand, every unwatch implies the removal of the entry.

        Note: The array will never have 2 entries with same path. When same path
        is provided to watch, the existing "watch descriptor" is re-used
        See inotify manual for further details.

    ***************************************************************************/

    private char[][uint] watched_files;


    /***********************************************************************

        Constructor. Creates a custom event and hooks it up to the provided
        event handler.

        Params:
            handler = event handler

    ***********************************************************************/

    public this ( Handler handler )
    {
        this.fd = new Inotify;
        this.handler = handler;
    }


    /***********************************************************************

        Replace the handle delegate

        Params:
            handler = event handler

    ***********************************************************************/

    public void setHandler ( Handler handler )
    {
        this.handler = handler;
    }


    /***********************************************************************

        Required by ISelectable interface.

        Returns:
            file descriptor used to manage custom event

    ***********************************************************************/

    public override Handle fileHandle ( )
    {
        return this.fd.fileHandle;
    }


    /***************************************************************************

        Returns:
            the epoll events to register for.

    ***************************************************************************/

    public override Event events ( )
    {
        return Event.EPOLLIN;
    }


    /***************************************************************************

        Adds or updates the events being watched for the specified path. The
        handler delegate previously specified will be called when one of the
        watched events occurs.

        params:
            path   = File path to watch (directories are also supported)
            events = Inotify events that will be watched (flags)

        Throws:
            upon failure during addition of new file to watch

    ***************************************************************************/

    public void watch ( char[] path, FileEventsEnum events )
    {
        //Attention: Existing wd is returned if path is being watched
        uint wd = this.fd.addWatch(path, events);

        if ( auto existing_path = wd in this.watched_files )
        {
            assert(*existing_path == path);
        }
        else
        {
            this.watched_files[wd] = path;
        }
    }


    /***************************************************************************

        Stops watching the specified path. The handler delegate will no longer
        be called when events on this path occur.

        Returns:
            True, if path was successfully removed
            False, the path was not found in the list of watched paths

        Throws:
            upon failure when removing the watch of a file

    ***************************************************************************/

    public bool unwatch ( char[] path )
    {
        bool removed = false;

        foreach ( wd, wd_path; this.watched_files )
        {
            if ( wd_path == path )
            {
                this.fd.rmWatch(wd);
                this.watched_files.remove(wd);
                removed = true;
                break;
            }
        }

        return removed;
    }


    /***************************************************************************

        Event handler, invoked by the epoll select dispatcher.

        Params:
            event = event(s) reported by epoll

        Returns:
            true to stay registered in epoll or false to unregister.

    ***************************************************************************/

    public override bool handle ( Event event )
    {
        foreach ( ev; this.fd.readEvents() )
        {
            assert(ev.mask);

            auto path = ev.wd in this.watched_files;
            assert(path !is null);

            this.handler( *path , ev.mask);
        }

        return true;
    }

}
