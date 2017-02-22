/*******************************************************************************

    Unittest for FileSystemEvent.

    Copyright:      Copyright (c) 2014 sociomantic labs. All rights reserved

*******************************************************************************/

import ocean.transition;

import ocean.io.device.TempFile;

import ocean.io.select.client.TimerEvent;

import ocean.io.select.client.FileSystemEvent;

import ocean.io.select.EpollSelectDispatcher;

import ocean.io.model.IConduit: ISelectable;

import ocean.io.FilePath_tango;

import ocean.core.Test;



/*******************************************************************************

    Class to perform a single test on FileSystemEvent

*******************************************************************************/

private class FileSystemEventTest
{
    /***************************************************************************

        Epoll where the inotifier instance will be registered

    ***************************************************************************/

    private EpollSelectDispatcher epoll;


    /***************************************************************************

        Temporary file used to generate file system events

    ***************************************************************************/

    private TempFile temp_file;


    /***************************************************************************

        Filepath of the temporary file

    ***************************************************************************/

    private FilePath temp_path;


    /***************************************************************************

        File operations to be checked

    ***************************************************************************/

    private bool modified = false;
    private bool deleted  = false;
    private bool closed   = false;


    /***************************************************************************

        Variable to control/test the order of the file operations

    ***************************************************************************/

    private int operation_order = 0;


    /***************************************************************************

        Constructor

        Also register a timer event to time-out the test after 1s, in case the
        file event notification fails.

    ***************************************************************************/

    this ( )
    {
        this.epoll = new EpollSelectDispatcher;

        this.temp_file = new TempFile(TempFile.Permanent);
        this.temp_path = FilePath(this.temp_file.toString());

        TimerEvent timer = new TimerEvent(&this.timerHandler);
        this.epoll.register(timer);
        timer.set(1, 0, 0, 0);

        this.run();
    }


    /***************************************************************************

        Run the test:
            Creates a watch to a temporary file which is written, closed and
            deleted.
            The epoll is blocked until the FileSystem handler shutdown the epoll,
            or the timer (worst case/failed test).

    ***************************************************************************/

    public void run ( )
    {
        auto inotifier  = new FileSystemEvent(&this.fileSystemHandler);
        inotifier.watch(cast(char[]) this.temp_file.toString(),
                           FileEventsEnum.IN_MODIFY | FileEventsEnum.IN_DELETE_SELF
                         | FileEventsEnum.IN_CLOSE_WRITE );

        this.epoll.register(inotifier);

        this.temp_file.write("something");
        this.temp_file.close;
        this.temp_path.remove();

        this.epoll.eventLoop();

        test(this.modified);
        test(this.closed);
        test(this.deleted);
    }


    /***************************************************************************

        File System handler: called anytime a File System event occurs.

        Params:
            path   = Path of the file
            event  = Inotify event (see FileEventsEnum)

    ****************************************************************************/

    private void fileSystemHandler ( char[] path, uint event )
    {
        if ( this.temp_path == path )
        {
            this.operation_order++;

            switch ( event )
            {
                case FileEventsEnum.IN_MODIFY:

                    if ( this.operation_order == 1 )
                    {
                        this.modified = true;
                    }
                    break;

                case FileEventsEnum.IN_CLOSE_WRITE:

                    if ( this.operation_order == 2 )
                    {
                        this.closed = true;
                    }
                    break;

                case FileEventsEnum.IN_DELETE_SELF:

                    if ( this.operation_order == 3 )
                    {
                        this.deleted = true;
                    }
                    break;


                default:
                    test(false, "Unexpected file system event notification.");
            }
        }

        if ( this.modified && this.closed && this.deleted )
        {
            this.epoll.shutdown();
        }
    }


    /***************************************************************************

        Timer Handler: Called when the timer is fired.

        Note: The timer is needed to assure epoll does not get blocked
              indefinitely.

        Returns:
            Always false - Timer will not be re-set.

    ***************************************************************************/

    private bool timerHandler ( )
    {
        this.epoll.shutdown();

        return false;
    }
}


/*******************************************************************************

    Dummy main (required by compiler).

*******************************************************************************/

void main ( )
{
}

/***************************************************************************

    UnitTest

***************************************************************************/

unittest
{
    new FileSystemEventTest();
}
