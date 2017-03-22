/*******************************************************************************

    Unittest for FileSystemEvent.

    Copyright:
        Copyright (c) 2014-2017 sociomantic labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module test.filesystemevent.main;

import ocean.text.convert.Formatter;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.Enforce;

import ocean.io.device.File;

import ocean.io.device.TempFile;

import ocean.io.select.client.TimerEvent;

import ocean.io.select.client.FileSystemEvent;

import ocean.io.select.EpollSelectDispatcher;

import ocean.io.model.IConduit: ISelectable;

import ocean.io.FilePath_tango;

import ocean.core.Test;

import ocean.util.test.DirectorySandbox;

import ocean.task.Task;

import ocean.task.Scheduler;

class FileModificationTestTask: Task
{
    /***************************************************************************

        File operations to be checked

    ***************************************************************************/

    private bool modified = false;
    private bool deleted  = false;
    private bool closed   = false;

    /***************************************************************************

        Name of the created file.

    ***************************************************************************/

    private cstring created_name;

    /***************************************************************************

        Path to the monitored file.

    ***************************************************************************/

    private FilePath temp_path;

    /***************************************************************************

        Variable to control/test the order of the file operations

    ***************************************************************************/

    private int operation_order = 0;

    /***************************************************************************

        Tested FileSystemEvent instance.

    ***************************************************************************/

    private FileSystemEvent inotifier;

    /***************************************************************************

        Test entry point. Prepares environment and tests the FileSystemEvent.

    ***************************************************************************/

    override public void run ( )
    {
        auto temp_file = new TempFile(TempFile.Permanent);
        this.temp_path = FilePath(temp_file.toString());

        this.inotifier  = new FileSystemEvent(&this.fileSystemHandler);
        inotifier.watch(cast(char[]) temp_file.toString(),
                       FileEventsEnum.IN_MODIFY | FileEventsEnum.IN_DELETE_SELF
                     | FileEventsEnum.IN_CLOSE_WRITE );

        theScheduler.epoll.register(inotifier);

        temp_file.write("something");
        temp_file.close;
        temp_path.remove();

        this.suspend();

        theScheduler.epoll.unregister(inotifier);

        test(this.modified);
        test(this.closed);
        test(this.deleted);
    }

    /**********************************************************************

        File System handler: called anytime a File System event occurs.

        Params:
            path   = monitored path
            event  = Inotify event (see FileEventsEnum)

    **********************************************************************/

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
                        if (this.suspended())
                            this.resume();
                    }
                    break;

                case FileEventsEnum.IN_IGNORED:
                    enforce(this.deleted);
                    break;

                default:
                    test(false, format("Unexpected file system event notification. {}", event));
            }
        }
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
    initScheduler(SchedulerConfiguration.init);
    theScheduler.exception_handler = (Task t, Exception e) {
        throw e;
    };

    auto test_task = new FileModificationTestTask;
    theScheduler.schedule(test_task);

    theScheduler.eventLoop();
}
