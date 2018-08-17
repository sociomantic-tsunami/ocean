/*******************************************************************************

    Queue 64-bit values with the following abilities:
      - Only unique values can be pushed.
      - The existence of a value can be queried.
      - Values can be removed.

    The values can be of type `ulong`, `long` or `size_t` references: Pointers,
    class or interface objects.

    Copyright: Copyright (c) 2016-2018 dunnhumby Germany GmbH. All rights reserved

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

*******************************************************************************/

module ocean.util.container.TreeQueue;

/*******************************************************************************

    Tree queue template; `T` is the type of the values to store.
    The public interface of `TreeQueue!(T)` is always the same as of the
    `TreeQueue` struct inside the template, even if `T` is `ulong`.

*******************************************************************************/

template TreeQueue ( T )
{
    static if (is(T == ulong))
    {
        // Use TreeQueueCore directly.
        alias TreeQueueCore TreeQueue;
    }
    else
    {
        // Provide a wrapper for all public TreeQueueCore methods.
        struct TreeQueue
        {
            import ocean.core.Traits: isAssocArrayType;

            /*******************************************************************

                The wrapped tree queue core implementation.

            *******************************************************************/

            private TreeQueueCore core;

            /*******************************************************************

                Returns:
                    true if the queue is empty or false if it has elements.

            *******************************************************************/

            public bool is_empty ( )
            {
                return this.core.is_empty;
            }

            /*******************************************************************

                Pushes `value` into the queue if not already existing.

                Params:
                    value = the value to push
                    startwatch = true: Start a stop watch to add the time `id`
                        spent in the queue to the statistics when it is popped.
                        false: When `id` is popped count it as "notime" (see
                        `TreeQueueStats` documentation for details).

                Returns:
                    true if `value` was pushed into the queue or false if it
                    already existed.

            *******************************************************************/

            public bool push ( T value, bool startwatch = true )
            {
                return this.core.push(mixin(cast_ulong ~ "value"), startwatch);
            }

            /*******************************************************************

                Pop `foreach` iteration, calls the loop body with each value in
                the queue, in the order of pushing, then pops the value from the
                queue. If the loop body throws then the value stays in the
                queue, and the next iteration starts with this value.

            *******************************************************************/

            public int opApply ( int delegate ( ref T value ) dg )
            {
                return this.core.opApply(
                    (ref ulong value_)
                    {
                        auto value = mixin(cast_T ~ "value_");
                        return dg(value);
                    }
                );
            }

            /*******************************************************************

                Tells whether `value` is in the queue.

                Returns:
                    true if `value` is in the queue or false if not.

            *******************************************************************/

            public bool exists ( T value )
            {
                return this.core.exists(mixin(cast_ulong ~ "value"));
            }

            /*******************************************************************

                Removes `value` from the queue.

                Returns:
                    true if `value` was removed from queue or false if not
                    found.

            *******************************************************************/

            public bool remove ( T value )
            {
                return this.core.remove(mixin(cast_ulong ~ "value"));
            }

            /*******************************************************************

                Returns:
                    the usage statistics.

            *******************************************************************/

            public TreeQueueStats stats ( )
            {
                return this.core.stats;
            }

            /*******************************************************************

                Sets the tree queue statistics to `src`.

                Params:
                    src = the new tree queue statistics

                Returns:
                    src

            *******************************************************************/

            public TreeQueueStats stats ( TreeQueueStats src )
            {
                return this.core.stats = src;
            }

            /*******************************************************************

                The `pointer_values` constant tells whether `T` is a pointer,
                class or interface so values need to be cast via
                `cast(void*)cast(ulong)`, and `size_t` needs to be `ulong`.

            *******************************************************************/

            static if (is(T PtrBase == PtrBase*))
            {
                private const pointer_values = true;
            }
            else
            {
                private const pointer_values = is(T == class) ||
                                               is(T == interface);
            }

            /*******************************************************************

                Validation of `T` and mixin string definitions for casting the
                values.

            *******************************************************************/

            static if (pointer_values)
            {
                static assert(is(size_t == ulong));
                private const cast_ulong = "cast(ulong)cast(void*)";
                private const cast_T     = "cast(T)cast(void*)";
            }
            else
            {
                static assert(is(T == long), "The TreeQueue value type is " ~
                              "expected to be a 64-bit integer or reference " ~
                              "type, not \"" ~ T.stringof ~ "\"");
                private const cast_ulong = "cast(ulong)";
                private const cast_T     = "cast(T)";
            }
        }
    }
}

/// Make sure the template compiles.
unittest
{
    TreeQueue!(ulong) a;
    TreeQueue!(void*) b;
}

/*******************************************************************************

    Queue usage statistics.

*******************************************************************************/

public struct TreeQueueStats
{
    import ocean.util.TimeHistogram;

    /***************************************************************************

        Statistics of the amount of time each record spends in the queue, from
        being pushed to popped.
        Counts only records that are pushed with `startwatch == true`.
        Does not count records removed via `remove`.

    ***************************************************************************/

    public TimeHistogram time_histogram;

    /***************************************************************************

        The number of elements pushed to the queue with `startwatch == false`.

    ***************************************************************************/

    public uint notime;
}

/*******************************************************************************

    Tree queue implementation.

*******************************************************************************/

private struct TreeQueueCore
{
    import ocean.util.container.TreeMap;
    import ocean.transition : Unqual;

    /***************************************************************************

        Queue element and ebtree nodeitem.

    ***************************************************************************/

    struct NodeItem
    {
        import ocean.util.container.ebtree.c.eb64tree: eb64_node;
        import ocean.time.StopWatch;

        /***********************************************************************

            ebtree node; the key is the request id.

        ***********************************************************************/

        eb64_node ebnode;

        /***********************************************************************

            List links

        ***********************************************************************/

        typeof(this) prev = null, next = null;

        /***********************************************************************

            Tracks the time this record spends in the queue.

        ***********************************************************************/

        StopWatch time_in_queue;

        /***********************************************************************

            Make sure the request id is zero if and only if this instance is
            not in the linked list queue (i.e. the links are null).

        ***********************************************************************/

        invariant ( )
        {
            if (this.ebnode.key)
            {
                assert(this.prev !is null || this.next is null);
            }
            else
            {
                assert(this.prev is null);
                assert(this.next is null);
            }
        }
    }

    /***************************************************************************

        Queue usage statistics.

    ***************************************************************************/

    public TreeQueueStats stats;

    /***************************************************************************

        The map.

    ***************************************************************************/

    private TreeMap!(NodeItem) ebtree;

    /***************************************************************************

        The first and last element in the list (i.e. queue).

    ***************************************************************************/

    private NodeItem* head = null, tail = null;

    /***************************************************************************

        Checks the consistency between the tree and the list.

    ***************************************************************************/

    invariant ( )
    {
        auto _this = cast(TreeQueueCore*)this; // cast away const in invariant
        if (_this.ebtree.is_empty)
        {
            assert(this.head is null);
            assert(this.tail is null);
        }
        else
        {
            assert(this.head !is null);
            assert(this.tail !is null);
        }
    }

    /***************************************************************************

        Returns:
            true if the queue is empty or false if it has elements.

    ***************************************************************************/

    public bool is_empty ( )
    {
        return this.head is null;
    }

    /***************************************************************************

        Pushes id into the queue if not already existing.

        Params:
            id = request id
            startwatch = true: Start a stop watch to add the time `id` spent
                in the queue to the statistics when it is popped. false: When
                `id` is popped count it as "notime" (see `TreeQueueStats`
                documentation for details).

        Returns:
            true if id was pushed into the queue or false if it already existed.

    ***************************************************************************/

    public bool push ( ulong id, bool startwatch = true )
    out
    {
        assert(!this.ebtree.is_empty, "ebtree empty after push");
    }
    body
    {
        bool added;
        auto item = this.ebtree.put(id, added);

        if (added)
        {
            if (this.head)
            {
                assert(!this.head.prev);
                this.head.prev = item;
            }
            else // null head: queue is empty
            {
                assert(this.tail is null);
                this.tail = item;
            }

            item.next = this.head;
            this.head = item;

            if (startwatch)
                item.time_in_queue.start();
            // else leave it at its init value so that it's counted as notime
            // when popped in opApply
        }

        return added;
    }

    /***************************************************************************

        Pop `foreach` iteration, calls the loop body with each request id in the
        queue, in the order of pushing, then the request id from the queue.
        If the loop body throws then the element stays in the queue, and the
        next iteration starts with this element.

    ***************************************************************************/

    public int opApply ( int delegate ( ref ulong id ) dg )
    {
        int stop = 0;

        while (!stop && this.tail)
        {
            assert(this);

            auto request_id = this.tail.ebnode.key;

            // Update this.tail before removing the nodeitem because
            // ebtree.remove() deallocates it.
            auto nodeitem_to_remove = this.tail;

            if (auto new_tail = this.tail.prev)
            {
                assert(new_tail.next is this.tail);
                new_tail.next = null;
                this.tail = new_tail;
            }
            else
            {
                assert(this.head is this.tail);
                this.head = this.tail = null;
            }

            with (*nodeitem_to_remove)
            {
                if (time_in_queue == time_in_queue.init)
                    this.stats.notime++;
                else
                    this.stats.time_histogram.countMicros(time_in_queue.microsec);
            }

            this.ebtree.remove(*nodeitem_to_remove);

            stop = dg(request_id);
        }

        return stop;
    }

    /***************************************************************************

        Returns:
            true if id is in the queue or false if not.

    ***************************************************************************/

    public bool exists ( ulong id )
    {
        return !!(id in this.ebtree);
    }

    /***************************************************************************

        Removes id from the queue.

        Returns:
            true if id was removed from queue or false if not found.

        In:
            id must not be 0.

    ***************************************************************************/

    public bool remove ( ulong id )
    {
        if (auto item = id in this.ebtree)
        {
            if (item.prev)
                item.prev.next = item.next;
            else
                this.head = item.next;

            if (item.next)
                item.next.prev = item.prev;
            else
                this.tail = item.prev;

            this.ebtree.remove(*item);
            return true;
        }
        else
        {
            return false;
        }
    }
}
