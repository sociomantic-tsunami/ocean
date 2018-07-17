/*******************************************************************************

    Implementation of buffer which contains elements with no indirections
    within them (== purely value types).

    Copyright:
        Copyright (c) 2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.buffer.NoIndirections;

template NoIndirectionsBufferImpl ( )
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

    void opAssign ( in T[] rhs )
    {
        this.length = rhs.length;
        this.data[] = rhs[];
    }

    /***************************************************************************

        Assigns data to stored data from other slice

        Params:
            rhs   = slice to assign from
            begin = starting index for local data
            end   = end index for local data

    ***************************************************************************/

    void opSliceAssign ( in T[] rhs, ptrdiff_t begin = 0,
        ptrdiff_t end = -1 )
    {
        if (end < 0)
            end = this.length();
        this.data[begin .. end] = rhs[];
    }

    /***************************************************************************

        Sets all elements of internal slice to rhs

        Params:
            rhs   = value to assign from
            begin = starting index for local data
            end   = end index for local data

    ***************************************************************************/

    void opSliceAssign ( in T rhs, ptrdiff_t begin = 0,
        ptrdiff_t end = -1 )
    {
        if (end < 0)
            end = this.length();
        this.data[begin .. end] = rhs;
    }

    /***************************************************************************

        Individual element access.

        Params:
            i = element index

        Returns:
            Requested element itself or pointer to requested element for
                structs

    ***************************************************************************/

    T* opIndex ( size_t i )
    {
        return &this.data[i];
    }

    /***************************************************************************

        Invidual element assignment

        Params:
            value = new element value
            i = element index

    ***************************************************************************/

    void opIndexAssign ( in T value, size_t i )
    {
        this.data[i] = value;
    }

    /***************************************************************************

        Appends to current buffer

        Params:
            rhs = array or element to append

    ***************************************************************************/

    void opCatAssign ( in T rhs )
    {
        this.length = this.data.length + 1;
        this.data[$-1] = rhs;
    }

    /***************************************************************************

        ditto

    ***************************************************************************/

    void opCatAssign ( in T[] rhs )
    {
        this.length = this.data.length + rhs.length;
        this.data[$-rhs.length .. $] = rhs[];
    }

    /***************************************************************************

        Buffer element iteration

        Params:
            dg = foreach loop body

    ***************************************************************************/

    int opApply ( scope int delegate(ref Const!(T)) dg ) const
    {
        foreach (elem; this.data)
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

    int opApply ( scope int delegate(ref size_t, ref Const!(T)) dg ) const
    {
        foreach (index, elem; this.data)
        {
            auto status = dg(index, elem);
            if (status != 0)
                return status;
        }

        return 0;
    }
}
