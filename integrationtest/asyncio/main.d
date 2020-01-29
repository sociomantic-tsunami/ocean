/*******************************************************************************

    Test for AsyncIO.

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module integrationtest.asyncio.main;

import ocean.meta.types.Qualifiers;

import core.sys.posix.sys.stat;
import core.sys.posix.pthread;
import ocean.core.Test;
import ocean.sys.ErrnoException;
import ocean.util.app.DaemonApp;
import ocean.task.Scheduler;
import ocean.task.Task;
import ocean.util.aio.AsyncIO;
import ocean.io.device.File;
import ocean.util.test.DirectorySandbox;

extern(C) int pthread_getattr_np(pthread_t thread, pthread_attr_t* attr);

class AsyncIOUsingApp: DaemonApp
{
    AsyncIO async_io;

    this ( )
    {

        istring name = "Application";
        istring desc = "Testing async IO";

        DaemonApp.OptionalSettings settings;
        settings.use_task_ext = true;

        super(name, desc, VersionInfo.init, settings);
    }


    /// Per-thread context to be used by the delegate
    class AioContext: AsyncIO.Context
    {
        void* thread_sp;
    }

    /// Delegate to call once per thread to create and
    /// initialize the thread context. Normally used
    /// to initialize libraries needed for the callback
    /// delegates
    AsyncIO.Context makeContext()
    {
        auto ctx = new AioContext;

        pthread_attr_t attr;
        void* stack_addr;
        size_t stack_size;

        pthread_getattr_np(pthread_self(), &attr);
        pthread_attr_getstack(&attr, &stack_addr, &stack_size);
        pthread_attr_destroy(&attr);

        ctx.thread_sp = stack_addr;

        return ctx;
    }

    /// counter value to set from the working thread
    int counter;

    /// last thread's sp value
    void* thread_sp;

    /// Callback called from another thread to set the counter
    private void setCounter (AsyncIO.Context ctx)
    {
        auto myctx = cast(AioContext)ctx;

        this.thread_sp = myctx.thread_sp;
        this.counter++;
    }

    // Called after arguments and config file parsing.
    override protected int run ( Arguments args, ConfigParser config )
    {
        this.async_io = new AsyncIO(theScheduler.epoll, 10, &makeContext);

        // open a new file
        auto f = new File("var/output.txt", File.ReadWriteAppending);

        char[] buf = "Hello darkness, my old friend.".dup;
        this.async_io.blocking.write(buf, f.fileHandle());

        buf[] = '\0';
        this.async_io.blocking.pread(buf, f.fileHandle(), 0);

        test!("==")(buf[], "Hello darkness, my old friend.");
        test!("==")(f.length, buf.length);

        this.async_io.blocking.callDelegate(&setCounter);
        test!("==")(this.counter, 1);
        test!("!is")(this.thread_sp, null);

        theScheduler.shutdown();
        return 0; // return code to OS
    }
}

version (unittest) {} else
void main(istring[] args)
{

    initScheduler(SchedulerConfiguration.init);
    theScheduler.exception_handler = (Task t, Exception e) {
        throw e;
    };

    auto sandbox = DirectorySandbox.create(["etc", "log", "var"]);

    File.set("etc/config.ini", "[LOG.Root]\n" ~
               "console = false\n\n");

    auto app = new AsyncIOUsingApp;
    auto ret = app.main(args);
}
