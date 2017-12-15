/*******************************************************************************

    Copyright:
        Copyright (c) 2017 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.meta.types.ReduceType_test;

import ocean.transition;
import ocean.meta.traits.Basic;
import ocean.meta.types.ReduceType;

struct ExampleReducer
{
    alias int Result;
    enum seed = 0;

    Result accumulate ( Result accum, Result next )
    {
        return accum + next;
    }

    Result visit ( T ) ( )
    {
        if (isIntegerType!(T))
            return 1;
        else
            return 0;
    }
}

unittest
{
    static assert (ReduceType!(int, ExampleReducer) == 1);
    static assert (ReduceType!(int[int], ExampleReducer) == 2);
}


struct CountSubTypes
{
    alias int Result;
    enum seed = 0;

    Result accumulate ( Result accum, Result next )
    {
        return accum + next;
    }

    Result visit ( T ) ( )
    {
        return 1;
    }
}

unittest
{
    static struct Sample
    {
        static struct Nested
        {
            mixin(Typedef!(int, "SomeInt"));
            SomeInt field;
        }

        Nested[3][] arr;
    }

    // root struct + dynamic array field + static array element + nested struct
    // element + nested struct field (typedef) + int
    static assert (ReduceType!(Sample, CountSubTypes) == 6);
}
