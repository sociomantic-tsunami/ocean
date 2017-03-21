/*******************************************************************************

    Test-suite for UnixSocketExt's logger (re)configuration.

    Copyright:
        Copyright (c) 2017 sociomantic labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module test.logger_unixsocketext.main;

import ocean.core.Enforce;
import Ocean = ocean.core.Test;
import ocean.io.select.EpollSelectDispatcher;
import ocean.io.Stdout;
import ocean.io.stream.TextFile;
import ocean.stdc.posix.sys.socket;
import ocean.stdc.posix.sys.un;
import ocean.sys.socket.UnixSocket;
import ocean.task.Scheduler;
import ocean.task.Task;
import ocean.task.util.Timer;
import ocean.text.convert.Formatter;
import ocean.transition;
import ocean.util.app.DaemonApp;
import ocean.util.log.model.ILogger;
import ocean.util.log.Logger;
import ocean.util.test.DirectorySandbox;


/// Logger instances
private Logger new_ns1;
private Logger new_ns2;

static this ()
{
    new_ns1 = Log.lookup("UnixSocketExtTest.NS1.Foo");
    new_ns2 = Log.lookup("UnixSocketExtTest.NS2.Foo");
}

///
public final class TestedApp : DaemonApp
{
    public this ()
    {
        super("UnixSocketExt",
              "Test for DaemonApp's UnixSocketExt logger configuration",
              null);
    }

    public override int run (Arguments args, ConfigParser config)
    {
        SchedulerConfiguration sconfig;
        initScheduler(sconfig);

        scope task = new TestTask;
        theScheduler.schedule(task);

        this.startEventHandling(theScheduler.epoll);
        theScheduler.eventLoop();

        return task.error ? 1 : 0;
    }
}

private final class TestTask : Task
{
    public bool error = true;
    private UnixSocket client;

    private const istring HelpMsg = `SetLogger is a command to change the configuration of a logger
The modification is temporary and will not be in effect after restart

Usage: SetLogger help
       SetLogger set Name [ARGS...]

    - help  = Print this usage message;
    - set   = Set the provided arguments for logger 'Name', keep existing values intact

Arguments to 'set' are key-value pairs, e.g. 'level=trace' or 'file=log/newfile.log'.
Note that the order in which arguments are processed is not guaranteed,
except for 'additive' which will affect subsequent arguments.
As a result, if 'additive' is provided, it should be before 'level',
or it won't be taken into account.
`;

    public override void run ()
    {
        // We need this for `connect` to succeed
        wait(1_000);

        this.client = new UnixSocket();
        scope(exit)
        {
            this.client.close();
            this.client = null;
        }

        auto addr = sockaddr_un.create(`mytest.socket`);
        this.client.socket(SOCK_STREAM | SOCK_NONBLOCK);
        auto connect_result = this.client.connect(&addr);
        assert(connect_result == 0, "connect() call failed");

        try
        {
            this.doTest();
            this.error = false;
        }
        catch (Exception e)
        {
            this.error = true;
            Stderr.formatln("Test failed (at {}:{}):", e.file, e.line);
            Stderr(getMsg(e)).nl;
        }

        theScheduler.shutdown();
    }

    private void doTest ()
    {
        cstring response;

        // Ensure argumentless SetLogger returns us the help message
        response = this.send("SetLogger\n");
        Ocean.test!("==")(response, HelpMsg);

        // And the help command should work as well
        response = this.send("SetLogger help\n");
        Ocean.test!("==")(response, HelpMsg);

        // Sanity checks that the config was applied
        Ocean.test!("==")(new_ns1.level, ILogger.Level.Error);
        Ocean.test!("==")(new_ns2.level, ILogger.Level.Error);

        // Reconfiguring a single logger
        response = this.send("SetLogger set UnixSocketExtTest.NS1.Foo level=Info\n");
        Ocean.test!("==")(response, "OK\n");
        Ocean.test!("==")(new_ns1.level, ILogger.Level.Info);
        Ocean.test!("==")(new_ns2.level, ILogger.Level.Error);

        // Reconfiguring a single logger through a parent

        response = this.send("SetLogger set UnixSocketExtTest.NS2 additive=true level=Warn\n");
        Ocean.test!("==")(response, "OK\n");
        Ocean.test!("==")(new_ns1.level, ILogger.Level.Info);
        Ocean.test!("==")(new_ns2.level, ILogger.Level.Warn);

        // Reconfiguring both loggers through a parent
        response = this.send("SetLogger set UnixSocketExtTest additive=true level=Error\n");
        Ocean.test!("==")(response, "OK\n");
        Ocean.test!("==")(new_ns1.level, ILogger.Level.Error);
        Ocean.test!("==")(new_ns2.level, ILogger.Level.Error);

        // Configuring Root logger
        response = this.send("SetLogger set Root additive=true level=Fatal\n");
        Ocean.test!("==")(response, "OK\n");

        Ocean.test!("==")(Log.root.level, ILogger.Level.Fatal);
        Ocean.test!("==")(new_ns1.level, ILogger.Level.Fatal);
        Ocean.test!("==")(new_ns2.level, ILogger.Level.Fatal);

        // Configuring Root logger without additive
        response = this.send("SetLogger set Root level=Trace\n");
        Ocean.test!("==")(response, "OK\n");

        Ocean.test!("==")(Log.root.level, ILogger.Level.Trace);
        Ocean.test!("==")(new_ns1.level, ILogger.Level.Fatal);
        Ocean.test!("==")(new_ns2.level, ILogger.Level.Fatal);
    }

    private cstring send (cstring query)
    {
        static mstring buffer;

        if (buffer is null)
            buffer = new mstring(1020);

        this.client.write(query);
        wait(1_000);
        ssize_t read_size = client.recv(buffer, 0);
        assert(read_size > 0, query);
        return buffer[0 .. read_size];
    }
}


/// Entry point
int main (istring[] args)
{
    scope sandbox = DirectorySandbox.create(["etc", "log"]);
    scope (success) sandbox.remove();
    scope (failure) sandbox.exitSandbox();

    scope config = new TextFileOutput("etc/config.ini");
    config.print(`[UNIX_SOCKET]
path=./mytest.socket

[LOG.Root]
level = error
propagate = true
console = false
file = log/root.log
file_layout = simple

[LOG.UnixSocketExtTest.NS1.Foo]
file = log/ns1.log

[LOG.UnixSocketExtTest.NS2.Foo]
file = log/ns2.log
`);
    config.flush();

    scope app = new TestedApp();
    return app.main(args);
}
