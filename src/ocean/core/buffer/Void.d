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

    /***************************************************************************

        ditto

    ***************************************************************************/

    void opCatAssign ( in ubyte[] rhs )
    {
        this.length = this.data.length + rhs.length;
        this.data[$-rhs.length .. $] = rhs[];
    }

    /***************************************************************************

        Buffer element iteration

        Params:
            dg = foreach loop body

    ***************************************************************************/

    int opApply ( scope int delegate(ref Const!(ubyte)) dg ) const
    {
        foreach (elem; cast(ubyte[]) this.data)
        {
            auto status = dg(elem);
            if (status != 0)
                return status;
        }

        return 0;
    }

    /***************************************************************************

        Buffer element iteration (with index)

        Params:
            dg = foreach loop body

    ***************************************************************************/

    int opApply ( scope int delegate(ref size_t, ref Const!(ubyte)) dg ) const
    {
        foreach (index, elem; cast(ubyte[]) this.data)
        {
            auto status = dg(index, elem);
            if (status != 0)
                return status;
        }

        return 0;
    }
}
