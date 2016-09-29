/*******************************************************************************

    Utility functions for loading and dumping task pools for preserving
    tasks between application restarts.

    To use the serialization and deserialization funtionality the derived
    task must implement 'serialize' and 'deserialize'.

    public void serialize ( ref void[] buffer )

    public void deserialize ( void[] buffer )

    See usage example in the unit test for example implementation.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.task.util.TaskPoolSerializer;

/*******************************************************************************

    Utility functions for loading and dumping task pools for preserving
    tasks between application restarts.

*******************************************************************************/

public class TaskPoolSerializer
{
    import ocean.transition;

    import ocean.core.Array: concat;
    import ocean.core.Enforce;
    import ocean.core.Traits;
    import ocean.core.TypeConvert;
    import ocean.io.device.File;
    import ocean.io.model.IConduit;
    import ocean.io.FilePath;
    import ocean.io.serialize.SimpleSerializer;
    import ocean.task.Task;

    /***************************************************************************

        Reusable serialization and deserialization buffer for tasks.

    ***************************************************************************/

    private void[] serialize_buffer;

    /***************************************************************************

        Temporary file path to be used while dumping tasks to disk.

    ***************************************************************************/

    private mstring temp_dump_file_path;

    /***************************************************************************

        Dump the current contents of the task pool to disk.
        If the task pool is empty then no file will be created.

        Uses `ocean.io.device.File` instead of `ocean.io.device.TempFile` due to
        issues copying across partitions in the AUFS storage driver.

        Params:
            task_pool = The task pool to dump to disk.
            dump_file_path = Dump current active tasks to the file path.

        Returns:
            The number of items dumped to disk.

        Throws:
            Exception on failure to create file.

    ***************************************************************************/

    public size_t dump ( TaskPoolT ) ( TaskPoolT task_pool, cstring dump_file_path )
    {
        if ( task_pool.num_busy == 0 ) return 0;

        concat(this.temp_dump_file_path, dump_file_path, ".tmp");
        scope file = new File(this.temp_dump_file_path, File.WriteCreate);

        auto items_written = this.dump(task_pool, file);
        file.sync();
        file.close();
        FilePath(this.temp_dump_file_path).rename(dump_file_path);
        return items_written;
    }

    /***************************************************************************

        Dump the current contents of the task pool to the output stream.

        Params:
            task_pool = The task pool to dump to the output stream.
            stream = The stream to dump tasks to.

    ***************************************************************************/

    public size_t dump ( TaskPoolT ) ( TaskPoolT task_pool, OutputStream stream )
    {
        static assert(hasMethod!(TaskPoolT.TaskType, "serialize",
                      void delegate ( ref void[] )));

        size_t num_busy = task_pool.num_busy;
        SimpleSerializerArrays.write(stream, num_busy);

        scope pool_itr = task_pool.new BusyItemsIterator;
        foreach ( raw_task; pool_itr )
        {
            this.serialize_buffer.length = 0;
            enableStomping(this.serialize_buffer);

            auto task = downcast!(TaskPoolT.TaskType)(raw_task);
            assert(task);
            task.serialize(this.serialize_buffer);

            SimpleSerializerArrays.write(stream, this.serialize_buffer);
        }

        return num_busy;
    }

    /***************************************************************************

        Loads serialized tasks from disk. Does nothing if no file exists.

        Params:
            task_pool = The task pool that the tasks will be loaded in to.
            load_file_path = The file path of the file to load.

        Returns:
            The number of items loaded from the file.

        Throws:
            When serialized data has been corrupted and expected number of
            items is not the amount read.

    ***************************************************************************/

    public size_t load ( TaskPoolT ) ( TaskPoolT task_pool, cstring load_file_path )
    {
        if ( !FilePath(load_file_path).exists ) return 0;

        scope file = new File(load_file_path);
        scope ( success )
            FilePath(load_file_path).remove();

        return this.load(task_pool, file);
    }

    /***************************************************************************

        Restores tasks from the InputStream to the TaskPool.

        Params:
            task_pool = The task pool that the tasks will be loaded in to.
            stream = InputStream containing the serialized tasks.

        Returns:
            The number of tasks loaded from the stream.

        Throws:
            When serialized data has been corrupted and expected number of
            items is not the amount read.

    ***************************************************************************/

    public size_t load ( TaskPoolT ) ( TaskPoolT task_pool, InputStream stream )
    {
        static assert(is(typeof(TaskPoolT.TaskType.deserialize)),
            "Must contain `deserialize` method for restoring");

        size_t total_items;

        SimpleSerializerArrays.read(stream, total_items);

        size_t len, tasks_loaded;

        while ( tasks_loaded < total_items )
        {
            SimpleSerializerArrays.read(stream, this.serialize_buffer);
            task_pool.restore(this.serialize_buffer);
            ++tasks_loaded;
        }

        enforce!("==")(tasks_loaded, total_items);
        return tasks_loaded;
    }

}

version ( UnitTest )
{
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
}

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
            Deserializer.deserialize!(TaskArgs)(buffer, this.args);
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
