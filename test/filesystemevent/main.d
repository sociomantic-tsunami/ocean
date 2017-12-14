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
import ocean.io.Stdout;
import ocean.task.util.Event;


class FileCreationTestTask: Task
{
    private TaskEvent task_event;
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

        Test that tests monitoring a directory and watching for the file
        creation.

    ***************************************************************************/

    private void testFileCreation ( )
    {
        scope(failure)
        {
            Stderr.formatln("Got exception in testFileCreation");
        }
        auto path = this.watched_path.dup;
        inotifier.watch(path,
               FileEventsEnum.IN_CREATE);

        theScheduler.epoll.register(inotifier);

        auto file_name = "test_file";
        File.set(file_name, "".dup);

        Stderr.formatln("Suspending the task!").flush;
        this.suspend();
        Stderr.formatln("Resumed the task!").flush;

        theScheduler.epoll.unregister(inotifier);

        Stderr.formatln("Unregistered the inotifier!").flush;

        test(this.created);
        test!("==")(this.created_name, file_name);

        inotifier.unwatch(path);
    }

    /***************************************************************************

        Test that tests modifications/closing/deleting performed on individual
        file (not a directory)

    ***************************************************************************/

    private void testFileModification ( )
    {
        scope(failure)
        {
            Stderr.formatln("Got exception in testFileModification");
        }

        Stderr.formatln("Testing file modification.").flush;
        auto temp_file = new File(this.watched_path ~ "/myfile", File.WriteCreate);
        this.temp_path = FilePath(temp_file.toString());

        Stderr.formatln("temp_file.toString(): '{}'", temp_file.toString());
        Stderr.formatln("temp_file.toString(): '{}'", cast(char[])temp_file.toString()).flush;

        inotifier.watch(temp_file.toString().dup,
                       FileEventsEnum.IN_MODIFY /*| FileEventsEnum.IN_DELETE_SELF*/
                     | FileEventsEnum.IN_CLOSE_WRITE );

        theScheduler.epoll.register(inotifier);

        temp_file.write("something");
        temp_file.close;
        //temp_path.remove();

        Stderr.formatln("I wrote closed and removed {}", this.temp_path);

        Stderr.formatln("Suspending test test task").flush;
        theScheduler.processEvents();
        this.task_event.wait();
        Stderr.formatln("Resuming test test task").flush;

        theScheduler.epoll.unregister(inotifier);
        Stderr.formatln("Unregistered inotifier").flush;

        test(this.modified);
        test(this.closed);
        //test(this.deleted);
    }

    /***************************************************************************

        Test entry point. Prepares environment and tests the FileSystemEvent.

    ***************************************************************************/
import ocean.sys.Environment;
    override public void run ( )
    {
        auto sandbox = DirectorySandbox.create();
        scope (exit)
            sandbox.exitSandbox();

        Stderr.formatln("we're in: {}", Environment.cwd).flush;
        this.watched_path = sandbox.path;///Environment.cwd;

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
import ocean.io.Stdout;
    private void fileSystemHandler ( FileSystemEvent.RaisedEvent raised_event )
    {
        Stderr.formatln("Raised event. {}", raised_event.active).flush;
        with (raised_event.Active) switch (raised_event.active)
        {
        case directory_file_event:
            auto event = raised_event.directory_file_event;

            Stderr.formatln("directory event path {} watched path {}. Equal? {}",
                    event.path, this.watched_path, event.path == this.watched_path).flush;

            if ( this.watched_path == event.path )
            {
                switch ( event.event )
                {
                    case FileEventsEnum.IN_CREATE:
                        Stderr.formatln("IN_CREATE: {}", event.name.dup).flush;
                        this.created = true;
                        this.created_name = event.name.dup;

                        if (this.suspended())
                        {
                            Stderr.formatln("Was suspended, now resuming.").flush;
                            this.resume();
                        }
                        else
                        {
                            Stderr.formatln("Was not suspended, no, mate.").flush;
                        }

                        break;
                    default:
                        Stderr.formatln("This is unexpected. Code: {}", event.event).flush;
                        test(false, "Unexpected file system event notification.");
                }
            }
            break;

        case file_event:
            auto event = raised_event.file_event;
            Stderr.formatln("file_event: {}", event.event).flush;

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
                            this.task_event.trigger();
                        }
                        break;

                        /*
                    case FileEventsEnum.IN_DELETE_SELF:

                        if ( this.operation_order == 3 )
                        {
                            this.deleted = true;
                        }
                        break;

                        */
                    case FileEventsEnum.IN_IGNORED:
//                        enforce(this.deleted);
                        break;

                    default:
                        test(false, "Unexpected file system event notification.");
                }
            }
            break;

        default:
            Stderr.formatln("I got into the default??? {}", raised_event.active).flush;
            assert(false);
        }
    }
}


/*******************************************************************************

    Main test

*******************************************************************************/

import core.stdc.stdlib;
void main ( )
{
    initScheduler(SchedulerConfiguration.init);
    theScheduler.exception_handler = (Task t, Exception e) {
        Stderr.formatln("Got exception: {}", getMsg(e)).flush;
        abort();
    };

    auto dir_test_task = new FileCreationTestTask;
    theScheduler.schedule(dir_test_task);
    theScheduler.eventLoop();
}
