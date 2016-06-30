/*******************************************************************************

    Implementation of buffer which contains elements with indirections
    within them. Such elements can't be implicitly converted between const
    and mutable and thus API must be conservatively mutable.

    Copyright:
        Copyright (c) 2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.buffer.WithIndirections;

template WithIndirectionsBufferImpl ( )
{
    /***************************************************************************

        Plain D array internally used as buffer storage

    ***************************************************************************/

    private T[] data;

    /***************************************************************************

        Assigns data to stored data from other slice

        Params:
            rhs   = slice to assign from

    ***************************************************************************/

    void opAssign ( T[] rhs )
    {
        this.length = rhs.length;
        this.data[] = rhs[];
    }

    ///
    unittest
    {
        auto buffer = createBuffer(new C(1), new C(2));
        auto old_ptr = buffer.data.ptr;
        buffer = [ new C(2), new C(3) ];
        test!("==")(buffer[], [ new C(2), new C(3) ]);
        test!("is")(buffer.data.ptr, old_ptr);
    }

    /***************************************************************************

        Assigns data to stored data from other slice

        Params:
            rhs   = slice to assign from
            begin = starting index for local data
            end   = end index for local data

    ***************************************************************************/

    void opSliceAssign ( U ) ( U[] rhs, ptrdiff_t begin = 0,
        ptrdiff_t end = -1 )
    {
        if (end < 0)
            end = this.length();
        this.data[begin .. end] = rhs[];
    }
    
    ///
    unittest
    {
        auto buffer = createBuffer(new C(1), new C(2));
        buffer[1 .. 2] = [ new C(3) ];
        test!("==")(buffer[], [ new C(1), new C(3) ]);
    }

    /***************************************************************************

        Individual element access.

        Params:
            i = element index

        Returns:
            Pointer to requested element

    ***************************************************************************/

    T* opIndex ( size_t i )
    {
        return &this.data[i];
    }

    ///
    unittest
    {
        auto buffer = createBuffer(new C(42));
        test!("==")(*buffer[0], new C(42));
    }

    /***************************************************************************

        Invidual element assignment

        Params:
            value = new element value
            i = element index

    ***************************************************************************/

    void opIndexAssign ( T value, size_t i )
    {
        this.data[i] = value;
    }

    ///
    unittest
    {
        auto buffer = createBuffer(new C(42));
        buffer[0] = new C(43);
        test!("==")(buffer[], [ new C(43) ]);
    }

    /***************************************************************************

        Appends to current buffer

        Params:
            rhs = array or element to append

    ***************************************************************************/

    void opCatAssign ( T rhs )
    {
        this.length = this.data.length + 1;
        this.data[$-1] = rhs;
    }

    ///
    unittest
    {
        auto buffer = createBuffer(new C(42));
        buffer.reserve(5);

        auto old_ptr = buffer.data.ptr;
        buffer ~= new C(43);
        test!("==")(buffer[], [ new C(42), new C(43) ]);
        test!("is")(buffer.data.ptr, old_ptr);
    }

    /***************************************************************************

        ditto

    ***************************************************************************/

    void opCatAssign ( T[] rhs )
    {
        this.length = this.data.length + rhs.length;
        this.data[$-rhs.length .. $] = rhs[];
    }

    ///
    unittest
    {
        auto buffer = createBuffer(new C(42));
        buffer.reserve(5);

        auto old_ptr = buffer.data.ptr;
        buffer ~= new C(43);
        test!("==")(buffer[], [ new C(42), new C(43) ]);
        test!("is")(buffer.data.ptr, old_ptr);
    }

    /***************************************************************************

        Buffer element iteration

        Params:
            dg = foreach loop body

    ***************************************************************************/

    int opApply ( int delegate(ref T) dg )
    {
        foreach (elem; this.data)
        {
            auto status = dg(elem);
            if (status != 0)
                return status;
        }

        return 0;
    }

    ///
    unittest
    {
        auto buffer = createBuffer(new C(1), new C(2), new C(3));
        size_t sum = 0;
        foreach (val; buffer)
        {
            if (val.x == 2)
                break;
            sum += val.x;
        }
        test!("==")(sum, 1);
    }

    /***************************************************************************

        Buffer element iteration (with index)

        Params:
            dg = foreach loop body

    ***************************************************************************/

    int opApply ( int delegate(ref size_t, ref T) dg )
    {
        foreach (index, elem; this.data)
        {
            auto status = dg(index, elem);
            if (status != 0)
                return status;
        }

        return 0;
    }

    ///
    unittest
    {
        auto buffer = createBuffer(new C(1), new C(2), new C(3), new C(4));
        size_t sum = 0;
        foreach (index, val; buffer)
        {
            if (val.x == 3)
                break;
            sum += index;
        }
        test!("==")(sum, 1);
    }
}
