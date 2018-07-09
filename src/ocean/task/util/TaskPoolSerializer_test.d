/*******************************************************************************

    Copyright:
        Copyright (c) 2017 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.util.TaskPoolSerializer_test;

import ocean.task.util.TaskPoolSerializer;

import ocean.core.Test;
import ocean.io.Stdout;
import ocean.io.device.MemoryDevice;
import ocean.task.Scheduler;
import ocean.task.Task;
import ocean.task.TaskPool;
import ocean.task.util.Timer;
import ocean.util.serialize.contiguous.Contiguous;
import ocean.util.serialize.contiguous.Deserializer;
import ocean.util.serialize.contiguous.Serializer;
import Util = ocean.util.serialize.contiguous.Util;

unittest
{
    static struct TaskArgs
    {
        int i;
    }

    static class TestTask : Task
    {
        static int result;

        public Contiguous!(TaskArgs) args;

        override public void run ( )
        {
            wait(1);
            result += args.ptr.i;
        }

        public void copyArguments( TaskArgs data )
        {
            Util.copy(data, this.args);
        }

        public void serialize ( ref void[] buffer )
        {
            Serializer.serialize(*this.args.ptr, buffer);
        }

        public void deserialize ( void[] buffer )
        {
            Deserializer.deserialize(buffer, this.args);
        }
    }

    initScheduler(SchedulerConfiguration.init);
    TaskPoolSerializer serializer = new TaskPoolSerializer();

    auto pool = new TaskPool!(TestTask);
    pool.start(TaskArgs(1));
    pool.start(TaskArgs(2));
    pool.start(TaskArgs(3));
    pool.start(TaskArgs(4));
    pool.start(TaskArgs(5));

    auto storage = new MemoryDevice;
    serializer.dump(pool, storage);

    //Run the event loop and reset the pool and result so we have a clean slate.
    theScheduler.eventLoop();
    TestTask.result = 0;
    pool.clear();

    storage.seek(0);
    size_t items = serializer.load(pool, storage);
    theScheduler.eventLoop();

    test!("==")(items, 5, "Incorrect number of items loaded");
    test!("==")(TestTask.result, 15, "Wrong result for restored tasks.");
}
