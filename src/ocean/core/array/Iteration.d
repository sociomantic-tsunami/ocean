/*******************************************************************************

    Provides alternative means to iterate an array.

    Copyright:
        Copyright (c) 2017 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.array.Iteration;

version(UnitTest)
{
    import ocean.core.Test;
}

/*******************************************************************************

    See `reverse`.

*******************************************************************************/

public struct ReverseIteration ( T )
{
    private T[] slice;

    int opApply ( int delegate(ref T) dg )
    {
        for (ptrdiff_t idx = slice.length-1; idx >= 0; --idx)
        {
            int status = dg(this.slice[idx]);
            if (status != 0)
                return status;
        }

        return 0;
    }
}

/*******************************************************************************

    Params:
        slice = array to iterate

    Returns:
        struct that wraps the slice and, when used as iterator, provides
        elements of the slice starting from the last one

*******************************************************************************/

public ReverseIteration!(T) reverse ( T ) ( T[] slice )
{
    return ReverseIteration!(T)(slice);
}

///
unittest
{
    int[] arr1 = [ 1, 2, 3 ];
    int[] arr2;

    foreach (elem; reverse(arr1))
        arr2 ~= elem;

    test!("==")(arr2, [ 3, 2, 1 ]);
}
