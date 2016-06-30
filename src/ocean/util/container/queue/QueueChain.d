/*******************************************************************************

    Composes two queues, with the second acting as an overflow of the first.

    Items are initially pushed into the main queue until it is full. Subsequent
    items then begin to be pushed into the swap queue and will continue doing so
    until the swap queue becomes empty again.

    Items are popped first from the main queue, and secondly from the overflow
    queue.

    The composed queues do not have to be of the same type (they are both simply
    required to implement the IByteQueue interface). A common usage pattern is
    to chain a file-based queue as an overflow of a memory-based queue.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.queue.QueueChain;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.queue.model.IByteQueue;

import ocean.util.container.queue.model.IQueueInfo;

import ocean.util.container.queue.FlexibleRingQueue;


import ocean.io.stream.Buffered,
       ocean.io.device.File,
       Filesystem = ocean.io.Path;



public class QueueChain : IByteQueue
{
    /***************************************************************************

        Queues

    ***************************************************************************/

    private IByteQueue queue, swap;


    /***************************************************************************

        Constructor

        Params:
            queue = queue instance that will be used
            swap  = queue instance that will be used as swap

    ***************************************************************************/

    public this ( IByteQueue queue, IByteQueue swap )
    {
        this.queue = queue;
        this.swap  = swap;
    }


    /***************************************************************************

        Pushes an item into the queue.

        Params:
            item = data item to push

        Returns:
            true if the item was pushed successfully, false if it didn't fit

    ***************************************************************************/

    public bool push ( ubyte[] item )
    {
        if ( item.length == 0 ) return false;

        if ( this.swap.is_empty() && this.queue.willFit(item.length) )
        {
            return this.queue.push(item);
        }
        else
        {
            return this.swap.push(item);
        }
    }


    /***************************************************************************

        Reserves space for an item of <size> bytes on the queue but doesn't
        fill the content. The caller is expected to fill in the content using
        the returned slice.

        Params:
            size = size of the space of the item that should be reserved

        Returns:
            slice to the reserved space if it was successfully reserved,
            else null

    ***************************************************************************/

    public ubyte[] push ( size_t size )
    {
        if ( this.swap.is_empty() && this.queue.willFit(size) )
        {
            return this.queue.push(size);
        }
        else
        {
            return this.swap.push(size);
        }
    }


    /***************************************************************************

        Pops an item from the queue.

        Returns:
            item popped from queue, may be null if queue is empty

    ***************************************************************************/

    public ubyte[] pop ( )
    {
        if ( this.queue.is_empty() == false )
        {
            return this.queue.pop();
        }
        else
        {
            bool fits ( )
            {
                auto len = this.swap.peek().length;

                return len > 0 && this.queue.willFit(len);
            }

            while ( fits() )
            {
                this.queue.push(this.swap.pop());
            }

            return this.queue.pop();
        }
    }


    /***************************************************************************

        Peek at the next item that would be popped from the queue.

        Returns:
            item that would be popped from queue, may be null if queue is empty

    ***************************************************************************/

    public ubyte[] peek ( )
    {
        if ( this.queue.is_empty() == false )
        {
            return this.queue.peek();
        }

        return this.swap.peek();
    }


    /***************************************************************************

        Finds out whether the provided number of bytes will fit in the queue.

        Params:
            bytes = size of item to check

        Returns:
            always true

    ***************************************************************************/

    public bool willFit ( size_t bytes )
    {
        return this.queue.willFit(bytes) || this.swap.willFit(bytes);
    }


    /***************************************************************************

        Returns:
            total number of bytes used by queue (used space + free space)

    ***************************************************************************/

    public ulong total_space ( )
    {
        return queue.total_space() + swap.total_space();
    }


    /***************************************************************************

        Returns:
            number of bytes stored in queue

    ***************************************************************************/

    public ulong used_space ( )
    {
        return queue.used_space() + swap.used_space();
    }


    /***************************************************************************

        Returns:
            number of bytes free in queue

    ***************************************************************************/

    public ulong free_space ( )
    {
        if ( swap.is_empty() == false ) return swap.free_space();

        return queue.free_space() + swap.free_space();
    }


    /***************************************************************************

        Returns:
            the number of items in the queue

    ***************************************************************************/

    public size_t length ( )
    {
        return queue.length() + swap.length();
    }


    /***************************************************************************

        Tells whether the queue is empty.

        Returns:
            true if the queue is empty

    ***************************************************************************/

    public bool is_empty ( )
    {
        return queue.is_empty() && swap.is_empty();
    }


    /***************************************************************************

        Deletes all items

    ***************************************************************************/

    public void clear ( )
    {
        this.queue.clear();
        this.swap.clear();
    }
}
