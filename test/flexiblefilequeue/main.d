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

    void doTest (bool open_existing)
    {
        for (ubyte size; size < ubyte.max; size++)
        {
            auto queue = new FlexibleFileQueue(test_file, 4, open_existing);

            for (ubyte i = 0; i < size; i++)
            {
                auto item = [i, cast(ubyte) (ubyte.max-i), i, cast(ubyte) (i * i)];
                assert(queue.push(item), "push failed");
            }

            for (ubyte i = 0; i < size; i++)
            {
                auto pop = queue.pop;
                auto item = [i, ubyte.max - i, i, cast(ubyte) (i * i)];
                assert(pop == item, "pop failed " ~ pop.stringof);
            }

            queue.clear();
        }
    }

    doTest(false);
    doTest(true);
}
