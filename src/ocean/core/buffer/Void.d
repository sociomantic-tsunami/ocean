/*******************************************************************************

    Implementation of buffer version compatible with void[].

    Copyright:
        Copyright (c) 2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.buffer.Void;

template VoidBufferImpl ( )
{
    /***************************************************************************

        Plain D array internally used as buffer storage

    ***************************************************************************/

    private ubyte[] data;

    /***************************************************************************

        Assigns data to stored data from other slice

        Params:
            rhs   = slice to assign from

    ***************************************************************************/

    void opAssign ( in void[] rhs )
    {
        this.length = rhs.length;
        this.data[] = (cast(ubyte[]) rhs)[];
    }

    ///
    unittest
    {
        Buffer!(void) buffer;
        buffer = arrayOf!(ubyte)(2, 3, 4);
        test!("==")(buffer[], arrayOf!(ubyte)(2, 3, 4));
    }

    /***************************************************************************

        Assigns data to stored data from other slice

        Params:
            rhs   = slice to assign from
            begin = starting index for local data
            end   = end index for local data

    ***************************************************************************/

    void opSliceAssign ( in void[] rhs, ptrdiff_t begin = 0,
        ptrdiff_t end = -1 )
    {
        if (end < 0)
            end = this.length();
        this.data[begin .. end] = (cast(ubyte[]) rhs)[];
    }
    
    ///
    unittest
    {
        Buffer!(void) buffer;
        buffer.length = 4;
        buffer[1 .. 4] = arrayOf!(ubyte)(2, 3, 4);
        test!("==")(buffer[], arrayOf!(ubyte)( 0, 2, 3, 4));
    }

    /***************************************************************************

        Individual element access.

        Params:
            i = element index

        Returns:
            Requested element

    ***************************************************************************/

    ubyte* opIndex ( size_t i )
    {
        return &this.data[i];
    }

    ///
    unittest
    {
        Buffer!(void) buffer;
        buffer.length = 2;
        buffer[1] = 42;
        test!("==")(*buffer[1], 42);
    }

    /***************************************************************************

        Invidual element assignment

        Params:
            value = new element value
            i = element index

    ***************************************************************************/

    void opIndexAssign ( ubyte value, size_t i )
    {
        this.data[i] = value;
    }

    ///
    unittest
    {
        Buffer!(void) buffer;
        buffer.length = 2;
        buffer[1] = 42;
        test!("==")(buffer[], arrayOf!(ubyte)(0, 42));
    }

    /***************************************************************************

        Appends to current buffer

        Params:
            rhs = array or element to append

    ***************************************************************************/

    void opCatAssign ( in ubyte rhs )
    {
        this.length = this.data.length + 1;
        this.data[$-1] = rhs;
    }

    ///
    unittest
    {
        Buffer!(void) buffer;
        buffer ~= 42;
        test!("==")(buffer[], arrayOf!(ubyte)(42));
    }

    /***************************************************************************

        ditto

    ***************************************************************************/

    void opCatAssign ( in ubyte[] rhs )
    {
        this.length = this.data.length + rhs.length;
        this.data[$-rhs.length .. $] = rhs[];
    }

    ///
    unittest
    {
        Buffer!(void) buffer;
        buffer ~= 42;
        test!("==")(buffer[], arrayOf!(ubyte)(42));
    }

    /***************************************************************************

        Buffer element iteration

        Params:
            dg = foreach loop body

    ***************************************************************************/

    int opApply ( int delegate(ref Const!(ubyte)) dg ) /* d1to2fix_inject: const */
    {
        foreach (elem; cast(ubyte[]) this.data)
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
        Buffer!(void) buffer;
        buffer = arrayOf!(ubyte)(1, 2, 3, 4);
        size_t sum = 0;
        foreach (val; buffer)
        {
            if (val == 3)
                break;
            sum += val;
        }
        test!("==")(sum, 3);
    }

    /***************************************************************************

        Buffer element iteration (with index)

        Params:
            dg = foreach loop body

    ***************************************************************************/

    int opApply ( int delegate(ref size_t, ref Const!(ubyte)) dg ) /* d1to2fix_inject: const */
    {
        foreach (index, elem; cast(ubyte[]) this.data)
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
        Buffer!(void) buffer;
        buffer = arrayOf!(ubyte)(1, 2, 3, 4);
        size_t sum = 0;
        foreach (index, val; buffer)
        {
            if (val == 3)
                break;
            sum += index;
        }
        test!("==")(sum, 1);
    } 
}
