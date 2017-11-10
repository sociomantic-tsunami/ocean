/*******************************************************************************

    Traits specializing in finding out indirections within compound
    types.

    Copyright:
        Copyright (c) 2017 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.meta.traits.Indirections;

import ocean.meta.types.ReduceType;
import ocean.meta.types.Arrays;
import ocean.meta.traits.Basic;

version(UnitTest)
{
    import ocean.meta.types.Qualifiers;
}

/*******************************************************************************

    Evaluates to true if a variable of any type in T is a reference type or has
    members or elements of reference types. References are
     - dynamic and associative arrays,
     - pointers (including function pointers) and delegates,
     - classes.

    Types that are not suitable to declare a variable, i.e. ``void`` and
    function types (the base types of function pointers) are not references.

    If T is empty then the result is false.

    Params:
        T = types to check (with no type the result is false)

*******************************************************************************/

public template hasIndirections ( T... )
{
    static immutable hasIndirections = ReduceType!(T, HasIndirectionsReducer);
}

///
unittest
{
    static assert (!hasIndirections!(int));
    static assert ( hasIndirections!(int[int]));
    static assert (!hasIndirections!(void));

    static struct S
    {
        union
        {
            int[] arr;
            double f;
        }
    }

    static assert ( hasIndirections!(S[5]));
}

unittest
{
    static struct S1 { }

    static struct S2
    {
        Const!(S1)[5] a;

        union
        {
            Immut!(int)[2][2] x;
            S1 y;
        }
    }

    static assert (!hasIndirections!(S2));

    static struct S3
    {
        void delegate(int) x;
    }

    static assert ( hasIndirections!(S3));

    static struct S4
    {
        Immut!(int[])[10] x;
    }

    static assert ( hasIndirections!(S4));
}

private struct HasIndirectionsReducer
{
    alias bool Result;

    Result visit ( T ) ( )
    {
        return isReferenceType!(T);
    }
}

/*******************************************************************************

    Checks if T or any of its subtypes is a multi-dimensional dynamic array.

    Params:
        T = type to check

    Returns:
        true if T or any of its subtypes is a multi-dimensional dynamic array or
        false otherwise.

*******************************************************************************/

public template containsMultiDimensionalDynamicArrays ( T )
{
    static immutable containsMultiDimensionalDynamicArrays =
        ReduceType!(T, MultiDimArraysReducer);
}

///
unittest
{
    static assert (!containsMultiDimensionalDynamicArrays!(int));
    static assert ( containsMultiDimensionalDynamicArrays!(int[][]));

    static struct S
    {
        int[][] arr;
    }

    static assert ( containsMultiDimensionalDynamicArrays!(S));
}

private struct MultiDimArraysReducer
{
    alias bool Result;

    Result visit ( T ) ( )
    {
        static if (isArrayType!(T) == ArrayKind.Dynamic)
            return isArrayType!(ElementTypeOf!(T)) == ArrayKind.Dynamic;
        else
            return false;
    }
}

unittest
{
    static assert(!containsMultiDimensionalDynamicArrays!(int));
    static assert(!containsMultiDimensionalDynamicArrays!(int[ ]));
    static assert(!containsMultiDimensionalDynamicArrays!(int[3]));

    static assert( containsMultiDimensionalDynamicArrays!(int[ ][ ]));
    static assert(!containsMultiDimensionalDynamicArrays!(int[3][ ]));
    static assert(!containsMultiDimensionalDynamicArrays!(int[ ][3]));
    static assert(!containsMultiDimensionalDynamicArrays!(int[3][3]));

    static assert( containsMultiDimensionalDynamicArrays!(int[ ][ ][ ]));
    static assert( containsMultiDimensionalDynamicArrays!(int[3][ ][ ]));
    static assert(!containsMultiDimensionalDynamicArrays!(int[ ][3][ ]));
    static assert(!containsMultiDimensionalDynamicArrays!(int[3][3][ ]));
    static assert( containsMultiDimensionalDynamicArrays!(int[ ][ ][3]));
    static assert(!containsMultiDimensionalDynamicArrays!(Immut!(int[3])[ ][3]));
    static assert(!containsMultiDimensionalDynamicArrays!(int[ ][3][3]));
    static assert(!containsMultiDimensionalDynamicArrays!(int[3][3][3]));

    static assert(!containsMultiDimensionalDynamicArrays!(void));
    static assert(!containsMultiDimensionalDynamicArrays!(void[]));
    static assert( containsMultiDimensionalDynamicArrays!(Const!(void[])[]));
    static assert(!containsMultiDimensionalDynamicArrays!(void[][3]));

    struct A
    {
        int x;
        char[] y;
        float[][][3][] z;
    }

    struct B
    {
        A[] a;
    }

    static assert(containsMultiDimensionalDynamicArrays!(A));

    struct C
    {
        int x;
        float[][3][] y;
        Const!(char)[] z;
    }

    static assert(!containsMultiDimensionalDynamicArrays!(C));
}
