/*******************************************************************************

    Unittest for FileSystemEvent.

    Copyright:
        Copyright (c) 2014-2017 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module integrationtest.filesystemevent.main;

import ocean.transition;

import ocean.core.Enforce;

import ocean.io.device.File;

import ocean.io.device.TempFile;

import ocean.io.select.client.TimerEvent;

import ocean.io.select.client.FileSystemEvent;

import ocean.io.select.EpollSelectDispatcher;

import ocean.io.model.IConduit: ISelectable;

import ocean.io.FilePath;

import ocean.core.Test;

import ocean.util.test.DirectorySandbox;

import ocean.task.Task;

import ocean.task.Scheduler;

import ocean.task.util.Event;

import ocean.text.convert.Formatter;

import ocean.sys.Environment;


class FileCreationTestTask: Task
{
    /***************************************************************************

        File operations to be checked

    ***************************************************************************/

    private bool created;
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

        Path to the monitored directory.

    ***************************************************************************/

    private cstring watched_path;

    /***************************************************************************

        Tested FileSystemEvent instance.

    ***************************************************************************/

    private FileSystemEvent inotifier;

    /***************************************************************************

        TaskEvent to suspend/resume the task.

    ***************************************************************************/

    private TaskEvent task_event;

    /***************************************************************************

        Test that tests monitoring a directory and watching for the file
        creation.

    ***************************************************************************/

    private void testFileCreation ( )
    {
        inotifier.watch(this.watched_path.dup,
               FileEventsEnum.IN_CREATE);

        theScheduler.epoll.register(inotifier);

        auto file_name = "test_file";
        File.set(file_name, "".dup);

        this.task_event.wait();

        theScheduler.epoll.unregister(inotifier);
        inotifier.unwatch(this.watched_path.dup);

        test(this.created);
        test!("==")(this.created_name, file_name);
    }

    /***************************************************************************

        Test that tests modifications/closing/deleting performed on individual
        file (not a directory)

    ***************************************************************************/

    private void testFileModification ( )
    {
        auto temp_file = new File("./testfile_modification", File.WriteCreate);
        this.temp_path = FilePath(temp_file.toString());

        inotifier.watch(cast(char[]) temp_file.toString(),
                       FileEventsEnum.IN_MODIFY | FileEventsEnum.IN_DELETE_SELF
                     | FileEventsEnum.IN_CLOSE_WRITE );

        theScheduler.epoll.register(inotifier);

        temp_file.write("something");
        temp_file.close;
        temp_path.remove();

        this.task_event.wait();

        theScheduler.epoll.unregister(inotifier);

        test(this.modified);
        test(this.closed);
        test(this.deleted);
    }

    /***************************************************************************

        Test entry point. Prepares environment and tests the FileSystemEvent.

    ***************************************************************************/

    override public void run ( )
    {
        auto makd_tmpdir = Environment.get("MAKD_TMPDIR");
        mstring path_template;
        sformat(path_template, "{}/Dunittests-XXXXXXXX",
                makd_tmpdir.length? makd_tmpdir : "/tmp");

        auto sandbox = DirectorySandbox.create(null, path_template);
        scope (exit)
            sandbox.exitSandbox();

        this.watched_path = sandbox.path;

        this.inotifier  = new FileSystemEvent(&this.fileSystemHandler);

        this.testFileCreation();
        this.testFileModification();
    }

    /**********************************************************************

        File System handler: called anytime a File System event occurs.

        Params:
            path   = monitored path
            name = name of the file
            event  = Inotify event (see FileEventsEnum)

    **********************************************************************/

    private void fileSystemHandler ( FileSystemEvent.RaisedEvent raised_event )
    {
        with (raised_event.Active) switch (raised_event.active)
        {
        case directory_file_event:
            auto event = raised_event.directory_file_event;

            if ( this.watched_path == event.path )
            {
                switch ( event.event )
                {
                    case FileEventsEnum.IN_CREATE:
                        this.created = true;
                        this.created_name = event.name.dup;
                        this.task_event.trigger();
                        break;
                    default:
                        test(false, "Unexpected file system event notification.");
                }
            }
            break;

        case file_event:
            auto event = raised_event.file_event;

            if ( this.temp_path == event.path )
            {
                this.operation_order++;

                switch ( event.event )
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
                            this.task_event.trigger();
                        }
                        break;

                    case FileEventsEnum.IN_IGNORED:
                        enforce(this.deleted);
                        break;

                    default:
                        test(false, "Unexpected file system event notification.");
                }
            }
            break;

        default:
            assert(false);
        }
    }
}


/*******************************************************************************

    Main test

*******************************************************************************/

version(UnitTest) {} else
void main ( )
{
    initScheduler(SchedulerConfiguration.init);
    theScheduler.exception_handler = (Task t, Exception e) {
        throw e;
    };

    auto dir_test_task = new FileCreationTestTask;
    theScheduler.schedule(dir_test_task);
    theScheduler.eventLoop();
}
