/*******************************************************************************

    Test for ReopenableFilesExt in combination with UnixSocketExt

    Copyright:
        Copyright (c) 2017 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module integrationtest.reopenfiles.main;

import ocean.transition;

import core.sys.posix.sys.stat;
import core.sys.linux.fcntl;

import ocean.core.Enforce;
import ocean.core.Test;
import ocean.io.FilePath;
import ocean.io.device.File;
import ocean.io.select.protocol.task.TaskSelectTransceiver;
import ocean.io.select.protocol.generic.ErrnoIOException: IOWarning, IOError;

import ocean.sys.socket.UnixSocket;
import ocean.stdc.posix.sys.un;

import ocean.task.Scheduler;
import ocean.task.Task;

import ocean.util.app.DaemonApp;
import ocean.util.test.DirectorySandbox;

/// Socket class to bind/connect
private istring socket_path = "reopensocket.socket";

/// Main application class
class ReopenableFilesApp : DaemonApp
{
    /// Count of the remaining tasks. Shut downs
    /// the scheduler when 0.
    private int task_remaining;

    /// Task used to send command and confirm the response
    class SendingTask: Task
    {
        /// Command to send
        cstring command_to_send;
        /// Response to expect
        cstring expected_response;

        /// Constructor
        this (cstring command_to_send,
            cstring expected_response)
        {
            this.command_to_send = command_to_send;
            this.expected_response = expected_response;
        }

        /// Main task method
        override void run()
        {
            auto socket_address = sockaddr_un.create(socket_path);

            auto client = new UnixSocket();

            auto socket_fd = client.socket();
            enforce(socket_fd >= 0, "socket() call failed!");

            auto connect_result = client.connect(&socket_address);
            enforce(connect_result == 0,
                    "connect() call failed");

            // set non-blocking mode on the client socket
            auto existing_flags = fcntl(client.fileHandle(),
                F_GETFL, 0);
            enforce(existing_flags != -1);
            enforce(fcntl(client.fileHandle(),
                F_SETFL, existing_flags | O_NONBLOCK) != -1);

            // Use the task-blocking tranceiver, so
            // the scheduler can handle other epoll clients
            auto transceiver = new TaskSelectTransceiver(client,
                new IOWarning(client), new IOError(client));
            transceiver.write(command_to_send);

            // Confirm the response!
            auto buff = new char[this.expected_response.length];
            transceiver.read(buff);
            test!("==")(buff, this.expected_response);

            if (--this.outer.task_remaining == 0)
            {
                theScheduler.shutdown();
            }
        }
    }

    /// Constructor.
    this ( )
    {
        initScheduler(SchedulerConfiguration.init);
        theScheduler.exception_handler = (Task, Exception e) {
            throw e;
        };

        istring name = "Application";
        istring desc = "Testing reopenable files ext";

        DaemonApp.OptionalSettings settings;

        super(name, desc, VersionInfo.init, settings);
    }

    /// Called after arguments and config file parsing.
    override protected int run ( Arguments args, ConfigParser config )
    {
        this.startEventHandling(theScheduler.epoll);

        auto original_file = new File;
        original_file.open("filelocation.txt", File.ReadWriteOpen);
        this.reopenable_files_ext.register(original_file);

        // move this file now
        auto path = new FilePath(original_file.path());
        path.rename("newfilelocation.txt");

        auto new_file = new File;
        new_file.open("filelocation.txt", File.ReadWriteOpen);
        new_file.write("Pre-reload");

        // we haven't done reloading
        test!("==")(original_file.length, 0);

        auto good_task = new SendingTask("reopen_files filelocation.txt\n",
            "ACK\n");
        theScheduler.schedule(good_task);

        auto bad_task = new SendingTask("reopen_files nonregistered.txt\n",
            "ERROR: Could not rotate the file 'nonregistered.txt'\n");
        theScheduler.schedule(bad_task);

        // Counter used to figure out when to exit the scheduler
        this.task_remaining = 2;

        // Spin the task and start working
        theScheduler.eventLoop();

        // Test if the file has been reloaded
        test!("!=")(original_file.length, 0);
        auto buff = new char["Pre-reload".length];
        original_file.read(buff);
        test!("==")(buff, "Pre-reload");

        return 0;
    }

}

version(UnitTest) {} else
void main(istring[] args)
{
    auto sandbox = DirectorySandbox.create(["etc", "log"]);
    scope (success)
        sandbox.remove();

    File.set("etc/config.ini", "[LOG.Root]\n" ~
               "console = false\n\n" ~
               "[UNIX_SOCKET]\npath=" ~ socket_path ~ "\nmode=0600");

    auto app = new ReopenableFilesApp;
    app.main(args);
}
