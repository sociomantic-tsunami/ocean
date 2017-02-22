/*******************************************************************************

    Fixed size memory-based ring queue with a fixed element size.

    TODO:
        Update the classes in this module to be able to use a custom allocater
        like the constructors of FlexibleByteRingQueue allow.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.queue.FixedRingQueue;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.queue.model.IRingQueue;

import ocean.util.container.queue.model.IQueue;

import ocean.util.container.queue.model.IByteQueue;

import ocean.util.container.mem.MemManager;



/*******************************************************************************

    Ring queue for elements of type T, T must be a value type.

*******************************************************************************/

class FixedRingQueue ( T ) : FixedRingQueueBase!(IQueue!(T))
{
    /***************************************************************************

        Constructor

        Params:
            max_items = maximum number of elements in queue

    ***************************************************************************/

    public this ( size_t max_items )
    {
        super(max_items, T.sizeof);
    }

    /***************************************************************************

        Pushes an element into the queue.

        Params:
            element = element to push (will be left unchanged)

        Returns:
            true on success or false if the queue is full.

    ***************************************************************************/

    public bool push ( T element )
    {
        T* element_in_queue = this.push();

        if (element_in_queue)
        {
            *element_in_queue = element;
            return true;
        }
        else
        {
            return false;
        }
    }

    /***************************************************************************

        Pushes an element into the queue and returns a pointer to that element.
        The value of the element must then be copied to the location pointed to
        before calling push() or pop() the next time.

        Returns:
            pointer to the element pushed into the queue or null if the queue is
            full.

    ***************************************************************************/

    public T* push ( )
    {
        return cast (T*) super.push_().ptr;
    }

    /***************************************************************************

        Pops an element from the queue.

        Params:
            element = destination for popped element, will be changed only if
                      the return value is true.

        Returns:
            true on success or false if the queue is empty.

    ***************************************************************************/

    public bool pop ( ref T element )
    {
        T* element_in_queue = this.pop();

        if (element_in_queue)
        {
            element = *element_in_queue;
            return true;
        }
        else
        {
            return false;
        }
    }


    /***************************************************************************

        Pops an element from the queue and returns a pointer to that element.
        The value of the element must then be copied from the location pointed
        to before calling push() or pop() the next time.

        Returns:
            pointer to the element popped from the queue or null if the queue is
            empty.

    ***************************************************************************/

    public T* pop ( )
    {
        return cast (T*) super.pop_().ptr;
    }
}

/*******************************************************************************

    Ring queue for raw element data.

*******************************************************************************/

class FixedByteRingQueue : FixedRingQueueBase!(IByteQueue)
{
    /***************************************************************************

        Constructor

        Params:
            element_size = element size in bytes
            max_items        = maximum number of elements in queue

    ***************************************************************************/

    this ( size_t element_size, size_t max_items )
    {
        super(max_items, element_size);
    }

    /***************************************************************************

        Pushes an element into the queue.

        Params:
            element = element to push (will be left unchanged)

        Returns:
            true on success or false if the queue is full.

    ***************************************************************************/

    bool push ( ubyte[] element )
    in
    {
        assert (element.length == super.element_size, "element size mismatch");
    }
    body
    {
        auto element_in_queue = super.push_();

        if (element_in_queue)
        {
            element_in_queue[] = element[];
            return true;
        }
        else
        {
            return false;
        }
    }

    /***************************************************************************

        Pushes an element into the queue and returns a slice to that element.
        The value of the element must then be copied to the sliced location
        before the next push() or pop() is called.

        Returns:
            slice to the element pushed into the queue or null if the queue is
            full.

    ***************************************************************************/

    ubyte[] push ( size_t ignored = 0 )
    {
        return cast(ubyte[])super.push_();
    }

    /***************************************************************************

        Pops an element from the queue and returns a slice to that element.
        The value of the element must then be copied from the sliced location
        before the next push() or pop() is called.

        Returns:
            pointer to the element popped from the queue or null if the queue is
            empty.

     ***************************************************************************/

    ubyte[] pop ( )
    {
        return cast(ubyte[])super.pop_();
    }

    ubyte[] peek ( )
    {
        return super.peek_();
    }

    /***************************************************************************

        Pops an element from the queue and copies the value to element.

        Params:
            element = destination buffer, the length must be the element size.
                      Will be changed only if the return value is true.

        Returns:
            true on success or false if the queue is empty.

    ***************************************************************************/

    bool pop ( ubyte[] element )
    in
    {
        assert (element.length == super.element_size, "element size mismatch");
    }
    body
    {
        auto element_in_queue = cast(ubyte[])super.pop_();

        if (element_in_queue)
        {
            element[] = element_in_queue[];
            return true;
        }
        else
        {
            return false;
        }
    }
}

/*******************************************************************************

    Ring queue base class.

*******************************************************************************/

abstract class FixedRingQueueBase ( IBaseQueue ) : IRingQueue!(IBaseQueue)
{
    /***************************************************************************

        Maximum number of elements in queue

    ***************************************************************************/

    protected size_t max_items;

    /***************************************************************************

        Element size in bytes

    ***************************************************************************/

    protected size_t element_size;

    /***************************************************************************

        Consistency check

    ***************************************************************************/

    invariant ( )
    {
        assert (super.items <= this.max_items);

        // Both read and write position must be integer multiples of the element
        // size.

        assert (!(super.write_to  % this.element_size));
        assert (!(super.read_from % this.element_size));

        // If the queue is empty or full, the read position must equal the write
        // position. If the read position equals the write position, the queue
        // must be empty or full.

        assert ((0 < super.items && super.items < this.max_items) ^ (super.read_from == super.write_to));

        assert (super.write_to  < super.data.length);
        assert (super.read_from < super.data.length);

        size_t used_space = super.items * this.element_size;

        if (super.write_to < super.read_from)
        {
            assert (used_space == super.data.length - (super.read_from - super.write_to));
        }
        else if (super.write_to > super.read_from)
        {
            assert (used_space == super.write_to - super.read_from);
        }
        else if (super.items)
        {
            assert (super.items == this.max_items);
            assert (used_space == super.data.length);
        }
        else
        {
            assert (!used_space);
        }
    }

    /***************************************************************************

        Constructor

        Params:
            element_size = element size in bytes
            max_items        = maximum number of elements in queue

    ***************************************************************************/

    this ( size_t max_items, size_t element_size )
    in
    {
        assert (element_size);
        assert (max_items);
    }
    body
    {
        super((this.element_size = element_size) * (this.max_items = max_items));
    }

    /***************************************************************************

        Returns:
            number of bytes stored in queue

    ***************************************************************************/

    override ulong used_space ( )
    {
        return super.items * this.element_size;
    }

    /***************************************************************************

        Returns:
            maximum number of elements that could be held in queue.

    ***************************************************************************/

    size_t maxItems ( )
    {
        return this.max_items;
    }


    /***************************************************************************

        Finds out whether another item will fit

        Params:
            bytes = size of item to check, ignored as sizes is fixed

        Returns:
            true if the item fits, else false

    ***************************************************************************/

    public bool willFit ( size_t bytes = 0)
    {
        return super.items < this.max_items;
    }


    /***************************************************************************

        Pushes an element into the queue and returns a slice to that element.
        The value of the element must then be copied to the sliced location
        before the next push_() or pop_() is called.

        Returns:
            slice to the element pushed into the queue or null if the queue is
            full.

    ***************************************************************************/

    protected void[] push_ ( )
    out (element)
    {
        assert (!element || element.length == this.element_size);
    }
    body
    {
        if (super.items < this.max_items)
        {
            super.items++;

            return this.getElement(super.write_to);
        }
        else
        {
            return null;
        }
    }

    /***************************************************************************

        Pops an element from the queue and returns a slice to that element.
        The value of the element must then be copied from the sliced location
        before the next push() or pop() is called.

        Returns:
            slice of the element popped from the queue or null if the queue is
            empty.

    ***************************************************************************/

    protected void[] pop_ ( )
    out (element)
    {
        assert (!element || element.length == this.element_size);
    }
    body
    {
        if (super.items)
        {
            super.items--;

            return this.getElement(super.read_from);
        }
        else
        {
            return null;
        }
    }


    protected ubyte[] peek_ ( )
    out (element)
    {
        assert (!element || element.length == this.element_size);
    }
    body
    {
        if (super.items)
        {
            auto read_pos = super.read_from;

            return cast(ubyte[])this.getElement(read_pos);
        }
        else
        {
            return null;
        }
    }

    /***************************************************************************

        Slices the element at position pos in super.data and increments pos by
        the element size. If pos reaches the end of data, it is reset (wrapped
        around) to 0.

        Params:
            pos = position in super.data

        Returns:
            slice to the element at the requested position in super.data.

    ***************************************************************************/

    private void[] getElement ( ref size_t pos )
    {
        size_t end = pos + this.element_size;

        ubyte[] chunk = super.data[pos .. end];

        pos = end;

        if (pos == super.data.length)
        {
            pos = 0;
        }

        return chunk;
    }
}

unittest
{
    static size_t pos ( size_t n )
    {
        return n * int.sizeof;
    }

    scope queue = new FixedRingQueue!(int)(3);

    int n;

    assert (queue.is_empty);
    assert (!queue.pop());
    assert (queue.is_empty);

    assert (queue.push(1));
    assert (queue.get_write_to  == pos(1));
    assert (queue.get_read_from == pos(0));
    assert (!queue.is_empty);

    assert (queue.pop(n));
    assert (n == 1);

    assert (queue.is_empty);
    assert (!queue.pop());
    assert (queue.get_write_to == queue.get_read_from);

    assert (queue.push(2));
    assert (!queue.is_empty);
    assert (queue.push(3));
    assert (queue.push(4));
    assert (!queue.push(5));
    assert (queue.get_write_to == queue.get_read_from);

    assert (queue.pop(n));
    assert (n == 2);

    assert (queue.pop(n));
    assert (n == 3);

    assert (queue.pop(n));
    assert (n == 4);

    assert (queue.is_empty);
    assert (!queue.pop());
    assert (queue.get_write_to == queue.get_read_from);

    assert (queue.push(5));

    assert (queue.pop(n));
    assert (n == 5);

    assert (queue.is_empty);
    assert (!queue.pop());
    assert (queue.get_write_to == queue.get_read_from);
}

