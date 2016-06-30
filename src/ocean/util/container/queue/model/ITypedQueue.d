/******************************************************************************

    An interface for a FIFO queue with items of a specific type.

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

module ocean.util.container.queue.model.ITypedQueue;
import ocean.core.Test;


/******************************************************************************

    An interface for a FIFO queue with items of a specific type.

    Template_Params:
        T = Type of items to be stored in the queue

*******************************************************************************/

public interface ITypedQueue ( T )
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

        Removes all items from the queue

    ***************************************************************************/

    void clear ( );


    /**************************************************************************

        Pushes an item to the queue. The caller should set the returned item as
        desired

        Returns:
            Pointer to the newly pushed item, null if the item could not be pushed
            (see documentation of implementing class for possible failure reasons)

    ***************************************************************************/

    T* push ( );


    /**************************************************************************

        Discards the item at the top of the queue.

    ***************************************************************************/

    void discardTop ( );


    /**************************************************************************

        Returns:
            A pointer to the item at the top of the queue, null if the queue is
            empty

    ***************************************************************************/

    T* top ( );
}


/******************************************************************************

    A helper function to push an item into ITypedQueue.

    Note: this function performs a shallow copy of t into the queue.
    If this is not desired, the caller class is to call `push()` method of
    `ITypedQueue` and apply desired logic on returned pointer.

    Template_Params:
        T = type of items stored in queue

    Params:
        q = A queue to push into
        t = An item to push into q

    Returns:
        true if t pushed into q, false otherwise

*******************************************************************************/

public bool push ( T ) ( ITypedQueue!(T) q, T t )
{
    auto p = q.push();
    if ( p is null ) return false;
    *p = t;
    return true;
}


/******************************************************************************

    A helper function to pop an item from ITypedQueue.

    Note: this function performs a shallow copy of the popped item into t.
    if this is not desired, the caller class is to call `top()` method of
    `ITypedQueue` and apply desired logic on returned pointer and then call
    `discardTop()`.

    Template_Params:
        T = type of items stored in queue

    Params:
        q = A queue to pop from
        t = if pop succeeds, will hold item popped from q, when function ends

    Returns:
        true if top item was popped and copied to t, false otherwise

*******************************************************************************/

public bool pop ( T ) ( ITypedQueue!(T) q, ref T t )
{
    auto p = q.top();
    if ( p is null )
    {
        return false;
    }
    t = *p;
    q.discardTop();
    return true;
}


version ( UnitTest )
{
    /**************************************************************************

        Test the methods defined in the ITypedQueue interface

        params:
            queue = queue to run tests on
            items = an array of items to test the queue with

    ***************************************************************************/

    void testInterfaceMethods ( T ) ( ITypedQueue!( T ) queue, T[] items )
    {
        // test 'push' and 'top'
        foreach ( i, item; items)
        {
            test(push(queue, items[i]), "push should have been successfull");

            test!("==")(queue.length(), i + 1, "push method should have added an item!");
            test(queue.top() != null, "queue isn't empty. Should have topped something!");
        }

        // test 'pop' (which calls 'top' and 'discardTop')
        foreach ( i, item; items)
        {
            T popped;
            pop(queue, popped);

            test!("==")(popped, items[i], "First element in queue should change after we pop!");
            test!("==")(queue.length(), items.length - i - 1, "pop method should have removed a single item from queue!");
        }

        // test 'clear'
        foreach ( i, item; items)
        {
            test(push(queue, items[i]), "push should have been successfull");
        }

        queue.clear();
        test(queue.empty(), "clear method should have removed all items from queue!");
        test(!queue.length(), "clear method should have removed all items from queue. Length should be 0!");
    }
}
