/*******************************************************************************

    Integration tests for `ocean.util.container.queue.FlexibleFileQueue`

    Those tests perform I/O operations.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

*******************************************************************************/

module flexiblefilequeue.main;


import ocean.transition;
import ocean.io.Stdout;
import ocean.text.util.StringC;
import ocean.util.container.queue.FlexibleFileQueue;
import ocean.util.test.DirectorySandbox;

public void main ()
{
    // Create will cd us into the sandbox
    auto test_dir = DirectorySandbox.create(["flexiblefilequeue"]);
    scope (exit) test_dir.remove();

    const istring test_file = "testfile";


    static void pushItems (FlexibleFileQueue queue, size_t size)
    {
        for (ubyte i = 0; i < size; i++)
        {
            auto item = [i, cast(ubyte) (ubyte.max-i), i, cast(ubyte) (i * i)];
            assert(queue.push(item), "push failed");
        }
    }

    static void popItems (FlexibleFileQueue queue, size_t size)
    {
        for (ubyte i = 0; i < size; i++)
        {
            auto pop = queue.pop;
            auto item = [i, ubyte.max - i, i, cast(ubyte) (i * i)];
            assert(pop == item, "pop failed " ~ pop.stringof);
        }
    }

    void doTest (bool open_existing)
    {
        for (ubyte size; size < ubyte.max; size++)
        {
            auto queue = new FlexibleFileQueue(test_file, 4, open_existing);
            pushItems(queue, size);
            popItems(queue, size);
            queue.clear();
        }
    }

    doTest(false);
    doTest(true);

    void reopenTestWrite ()
    {
        scope queue = new FlexibleFileQueue(test_file, 4, true);
        assert(queue.is_empty());
        assert(queue.length() == 0);
        pushItems(queue, 100);
        assert(!queue.is_empty());
        assert(queue.length() == 100);
    }

    void reopenTestRead ()
    {
        scope queue = new FlexibleFileQueue(test_file, 4, true);
        assert(!queue.is_empty());
        assert(queue.length() == 100);
        popItems(queue, 100);
        assert(queue.is_empty());
        assert(queue.length() == 0);
    }

    reopenTestWrite();
    reopenTestRead();
}
