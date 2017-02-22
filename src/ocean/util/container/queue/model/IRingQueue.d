/*******************************************************************************

    Base class for a fixed size memory-based ring queue.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.queue.model.IRingQueue;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.queue.model.IQueueInfo;

import ocean.util.container.mem.MemManager;



/*******************************************************************************

    Base class for a fixed size memory-based ring queue.

*******************************************************************************/

public abstract class IRingQueue ( IBaseQueue ) : IBaseQueue
{
    /***************************************************************************

        Data array -- the actual queue where the items are stored.

    ***************************************************************************/

    protected ubyte[] data;

    version (UnitTest)
    public ubyte[] get_data ()
    {
        return this.data;
    }

    /***************************************************************************

        Read & write positions (indices into the data array).

    ***************************************************************************/

    protected size_t write_to = 0;

    version (UnitTest)
    public size_t get_write_to ()
    {
        return this.write_to;
    }

    protected size_t read_from = 0;

    version (UnitTest)
    public size_t get_read_from ()
    {
        return this.read_from;
    }


    /***************************************************************************

        Number of items in the queue.

    ***************************************************************************/

    protected uint items = 0;

    version (UnitTest)
    public size_t get_items ()
    {
        return this.items;
    }

    /***************************************************************************

        Memory manager used to allocated / deallocate the queue's buffer.

    ***************************************************************************/

    private IMemManager mem_manager;


    /***************************************************************************

        Constructor. The queue's memory buffer is allocated by the GC.

        Params:
            dimension = size of queue in bytes

    ***************************************************************************/

    protected this ( size_t dimension )
    {
        auto manager = gcMemManager;
        this(manager, dimension);
    }


    /***************************************************************************

        Constructor. Allocates the queue's memory buffer with the provided
        memory manager.

        Params:
            mem_manager = memory manager to use to allocate queue's buffer
            dimension = size of queue in bytes

    ***************************************************************************/

    protected this ( IMemManager mem_manager, size_t dimension )
    in
    {
        assert(mem_manager !is null, typeof(this).stringof ~ ": memory manager is null");
        assert(dimension > 0, typeof(this).stringof ~ ": cannot construct a 0-length queue");
    }
    body
    {
        this.mem_manager = mem_manager;

        this.data = this.mem_manager.create(dimension);
    }


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Called for explicit deletes

        ***********************************************************************/

        override protected void dispose ( )
        {
            this.mem_manager.dispose(this.data);
        }
    }


    /***************************************************************************

        Called for explicit deletes and on collection

    ***************************************************************************/

    ~this ( )
    {
        this.mem_manager.dtor(this.data);
    }


    /***************************************************************************

        Returns:
            the number of items in the queue

    ***************************************************************************/

    public size_t length ( )
    {
        return this.items;
    }


    /***************************************************************************

        Tells whether the queue is empty.

        Returns:
            true if the queue is empty

    ***************************************************************************/

    public bool is_empty ( )
    {
        return this.items == 0;
    }


    /***************************************************************************

        Returns:
            number of bytes free in queue

    ***************************************************************************/

    public ulong free_space ( )
    {
        return this.data.length - this.used_space;
    }


    /***************************************************************************

        Returns:
            number of bytes stored in queue

    ***************************************************************************/

    abstract ulong used_space ( );


    /***************************************************************************

        Returns:
            total number of bytes used by queue (used space + free space)

    ***************************************************************************/

    public ulong total_space ( )
    {
        return this.data.length;
    }


    /***************************************************************************

        Removes all items from the queue.

    ***************************************************************************/

    public void clear ( )
    {
        this.write_to   = 0;
        this.read_from  = 0;
        this.items      = 0;
    }
}
