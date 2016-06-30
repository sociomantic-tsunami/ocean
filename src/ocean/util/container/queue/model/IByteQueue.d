/*******************************************************************************

    Base class for a queue storing raw ubyte data.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.queue.model.IByteQueue;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.queue.model.IQueueInfo;



/*******************************************************************************

    Base class for a queue storing raw ubyte data.

*******************************************************************************/

public interface IByteQueue : IQueueInfo
{
    /***************************************************************************

        Removes all items from the queue.

    ***************************************************************************/

    public void clear ( );


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

    public ubyte[] push ( size_t size );


    /***************************************************************************

        Pushes an item into the queue.

        Params:
            item = data item to push

        Returns:
            true if the item was pushed successfully, false if it didn't fit

    ***************************************************************************/

    public bool push ( ubyte[] item );


    /***************************************************************************

        Pops an item from the queue.

        Returns:
            item popped from queue, may be null if queue is empty

    ***************************************************************************/

    public ubyte[] pop ( );


    /***************************************************************************

        Peek at the next item that would be popped from the queue.

        Returns:
            item that would be popped from queue, may be null if queue is empty

    ***************************************************************************/

    public ubyte[] peek ( );
}

