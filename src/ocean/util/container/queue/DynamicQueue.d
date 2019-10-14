/*******************************************************************************

    Wrapper for a common boilerplate to imitate queue using dynamic array.

    Provides IQueue!(T) interfaces, stores items internally using dynamic
    array of items. Will grow indefinitely as long as there is any spare
    memory. Popped items will initially be marked as "free" and occasionally
    whole array will be shifted to optimized used memory space.

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.queue.DynamicQueue;

import ocean.core.Buffer;
import ocean.core.array.Mutation : removeShift;
import ocean.util.container.queue.model.IQueue;

version (unittest)
{
    import ocean.core.Test;
}

/// ditto
class DynamicQueue ( T ) : IQueue!(T)
{
    /// Underlying item storage
    private Buffer!(T) buffer;
    /// Marks oldest stored item offset (== the one that will be popped next)
    private size_t oldest;

    /// When set to 'true`, will automatically shift all items in the underlying
    /// array to utilize freed space. It is a recommended default.
    public bool auto_shrink = true;

    /***************************************************************************

        Removes all items from the queue.

    ***************************************************************************/

    override public void clear ( )
    {
        this.buffer.reset();
        this.oldest = 0;
    }

    /***************************************************************************

        Reserves space for an element of the size T.sizeof at the queue and
        returns a pointer to it.
        The value of the element must then be copied to the location pointed to
        before calling push() or pop() the next time.

        Returns:
            pointer to the element pushed into the queue or null if the queue is
            full.

    ***************************************************************************/

    override public T* push ( )
    {
        if (this.auto_shrink)
        {
            if (this.oldest > this.buffer.length / 3)
                this.shrink();
        }

        this.buffer.length = this.buffer.length + 1;
        return &this.buffer[][$-1];
    }

    /***************************************************************************

        Pushes an element into the queue.

        Params:
            element = element to push (will be left unchanged)

        Returns:
            true on success or false if the queue is full.

    ***************************************************************************/

    override public bool push ( T element )
    {
        *this.push() = element;
        return true;
    }

    /***************************************************************************

        Pops an element from the queue and returns a pointer to that element.
        The value of the element must then be copied from the location pointed
        to before calling push() or pop() the next time.

        Returns:
            pointer to the element popped from the queue or null if the queue is
            empty.

    ***************************************************************************/

    override public T* pop ( )
    {
        if (this.buffer.length <= this.oldest)
            return null;

        return &this.buffer[][this.oldest++];
    }

    /***************************************************************************

        Returns:
            the number of items in the queue

    ***************************************************************************/

    override public size_t length ( )
    {
        return this.buffer.length - this.oldest;
    }

    /***************************************************************************

        Returns:
            number of bytes stored in queue

    ***************************************************************************/

    override public ulong used_space ( )
    {
        return this.length * T.sizeof;
    }

    /***************************************************************************

        Returns:
            number of bytes free in queue

    ***************************************************************************/

    override public ulong free_space ( )
    {
        return this.oldest * T.sizeof;
    }

    /***************************************************************************

        Returns:
            total number of bytes used by queue (used space + free space)

    ***************************************************************************/

    override public ulong total_space ( )
    {
        return this.buffer.length * T.sizeof;
    }

    /***************************************************************************

        Tells whether the queue is empty.

        Returns:
            true if the queue is empty

    ***************************************************************************/

    public bool is_empty ( )
    {
        return this.oldest == this.buffer.length;
    }

    /***************************************************************************

        Finds out whether the provided number of bytes will fit in the queue.

        Params:
            bytes = size of item to check

        Returns:
            true if the bytes fits, else false

    ***************************************************************************/

    public bool willFit ( size_t bytes )
    {
        return true;
    }

    /***************************************************************************

        Shifts lefts currently used slots of the underlying array to optimize
        memory usage.

    ***************************************************************************/

    public void shrink ()
    {
        removeShift(this.buffer, 0, this.oldest);
        this.oldest = 0;
    }
}

///
unittest
{
    auto queue = new DynamicQueue!(int);
    queue.push(1);
    queue.push(2);
    queue.push(3);
    test!("==")(*queue.pop(), 1);
    test!("==")(*queue.pop(), 2);
    test!("==")(*queue.pop(), 3);
}

unittest
{
    static struct S { int field; }
    auto queue = new DynamicQueue!(S);

    queue.shrink();

    queue.push(S(1));
    test!("==")(queue.length, 1);

    queue.clear();
    test!("==")(queue.length, 0);

    test!("is")(queue.pop(), null);
    queue.push(S(2));
    test!("==")(*queue.pop(), S(2));

    test!("==")(queue.used_space(), 0);
    for (int i; i < 100; ++i)
        queue.push(S(i));
    for (int i; i < 10; ++i)
        queue.pop();
    test!("==")(queue.length(), 90);
    test!("==")(queue.used_space(), 90 * S.sizeof);
    test!("==")(queue.free_space(), 10 * S.sizeof);
    test!("==")(queue.total_space(), 100 * S.sizeof);
    queue.shrink();
    test!("==")(queue.total_space(), 90 * S.sizeof);
    test!("==")(*queue.pop(), S(10));

    test!("==")(queue.is_empty(), false);
    test!("==")(queue.willFit(size_t.max), true);
}
