/*******************************************************************************

    Copyright:
        Copyright (c) 2017 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.protocol.task.TaskSelectTransceiver_test;

import ocean.io.select.protocol.task.TaskSelectTransceiver;

import ocean.transition;
import ocean.stdc.posix.fcntl: O_NONBLOCK;
import core.sys.posix.unistd: write, close;
import ocean.sys.ErrnoException;
import ocean.io.device.IODevice;
import ocean.io.select.protocol.generic.ErrnoIOException;
import ocean.io.select.client.model.ISelectClient;
import ocean.task.Scheduler;
import ocean.task.Task;
import ocean.core.Test;

extern (C) private int pipe2(ref int[2] fd, int flags);

unittest
{
    // This test uses a pipe as an I/O device.
    int[2] pipefd;

    if (pipe2(pipefd, O_NONBLOCK))
        throw (new ErrnoException).useGlobalErrno("pipe2");

    // This TaskSelectTransceiver subclass uses a tiny 3-bytes buffer to test
    // the reading loop.
    static scope class TestTaskSelectTransceiver: TaskSelectTransceiver
    {
        this ( IODevice iodev )
        {
            super(iodev, new IOWarning(iodev), new IOError(iodev), 3);
        }

        ~this ( ) { .close(this.iodev.fileHandle); }
    }

    // Create an input-only task select transceiver for the reading end of the
    // pipe.
    scope intst = new TestTaskSelectTransceiver(new class IODevice
    {
        Handle fileHandle ( ) { return cast(Handle)pipefd[0]; }
        override ssize_t write ( Const!(void)[] src ) { assert(false); }
    });

    // Create an output-only task select transceiver for the writing end of the
    // pipe.
    scope outtst = new TestTaskSelectTransceiver(new class IODevice
    {
        Handle fileHandle ( ) { return cast(Handle)pipefd[1]; }
        override ssize_t read ( void[] dst ) { assert(false); }
        override ssize_t write ( Const!(void)[] src )
        {
            return .write(pipefd[1], src.ptr, src.length);
        }
    });

    initScheduler(SchedulerConfiguration.init);

    static immutable outstr = "Hello World!";
    char[outstr.length] instr;

    // Start a task that writes the test string to the pipe.
    theScheduler.schedule(new class Task
    {
        override void run     ( ) { outtst.write(outstr); }
        override void recycle ( ) { outtst.select_client.unregister(); }
    });

    // Start a task that reads the test string from the pipe.
    theScheduler.schedule(new class Task
    {
        override void run ( )
        {
            // Read only "Hello " to test readv().
            static immutable hello = "Hello ".length;
            intst.read(instr[0 .. hello]);
            auto world = instr[hello .. $];

            // Read "World!". The input buffer size makes only 3 characters
            // arrive at once.
            intst.readConsume(
                (void[] data)
                {
                    world[0 .. data.length] = cast(char[])data;
                    world = world[data.length .. $];
                    return data.length + !!world.length;
                }
            );
        }

        override void recycle ( ) { intst.select_client.unregister(); }
    });

    theScheduler.eventLoop();

    test!("==")(instr, outstr);
}
