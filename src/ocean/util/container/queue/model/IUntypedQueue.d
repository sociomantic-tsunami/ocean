/******************************************************************************

    An interface for a FIFO queue with items of unspecified type.

    This interface is deliberately designed to be as minimal as possible,
    only covering the core functionality shared by the wide variety of possible
    queue implementations. For example, even a basic pop function which returns
    an item is not generic -- certain implementations may need to relinquish the
    item after popping it, making a simple pop-then-return implementation
    impossible. For this reason, some additional helper functions are provided,
    which may be useful with some queue implementations.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.queue.model.IUntypedQueue;

import ocean.core.Array : copy;


/******************************************************************************

    An interface for a FIFO queue with items of unspecified type (opaque chunks
    of data).

*******************************************************************************/

public interface IUntypedQueue
{
    /**************************************************************************

        Returns:
            true if queue is empty, false otherwise

    ***************************************************************************/

    bool empty ( );


    /**************************************************************************

        Returns:
            number of items in the queue

    ***************************************************************************/

    size_t length ( );


    /**************************************************************************

        Returns:
            number of bytes in the queue

    ***************************************************************************/

    size_t size ( );


    /**************************************************************************

        Removes all items from the queue

    ***************************************************************************/

    void clear ( );


    /**************************************************************************

        Pushes an item of `size` bytes to the queue. The caller should set the
        returned item as desired

        Params:
            size = number of bytes to push into queue

        Returns:
            Newly pushed item, null if the item could not be pushed (see
            documentation of implementing class for possible failure reasons)

    ***************************************************************************/

    void[] push ( size_t size );


    /**************************************************************************

        Discards the item at the top of the queue.

    ***************************************************************************/

    void discardTop ( );


    /**************************************************************************

        Returns:
            The item at the top of the queue, null if the queue is empty

    ***************************************************************************/

    void[] top ( );
}


/******************************************************************************

    A helper function to push into IUntypedQueue.

    Note: this function performs a shallow copy of t into the queue.
    If this is not desired, the caller class is to call `push()` method of
    `IUntypedQueue` and apply desired logic on returned pointer.

    Params:
        q = A queue to push into
        t = An item to push into q

    Returns:
        true if t pushed into q, false otherwise

*******************************************************************************/

public bool push ( IUntypedQueue q, void[] t )
{
    auto s = q.push(t.length);
    if ( s is null ) return false;
    s.copy(t);
    return true;
}


/******************************************************************************

    A helper function to pop from IUntypedQueue.

    Note: this function performs a shallow copy of the popped item into t.
    if this is not desired, the caller class is to call `top()` method of
    `IUntypedQueue` and apply desired logic on returned pointer and then call
    `discardTop()`.

    Params:
        q = A queue to pop from
        t = will hold the item popped from q, when function ends

    Returns:
        true if top item was popped and copied to t, false otherwise

*******************************************************************************/

public bool pop ( IUntypedQueue q, ref void[] t )
{
    auto p = q.top();
    if ( p is null )
    {
        return false;
    }
    t.copy(p);
    q.discardTop();
    return true;
}
