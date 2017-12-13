/*******************************************************************************

    Utility to reset fields of a struct to their .init value while preserving
    array pointers (their length is set to 0 but memory is kept available for
    further reuse).

    Although the functionality provided in this module is similar to that in
    `ocean.util.DeepReset`, it differs in some fundamental ways (details of
    which can be found in the function documentation below).

    This utility is intended to be used in very specific cases, with
    `ocean.util.DeepReset` being the preferred choice for general resetting
    needs.

    Copyright: Copyright (c) 2017 sociomantic labs GmbH. All rights reserved

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.StructShallowReset;


import ocean.core.Traits: isAssocArrayType;

version ( UnitTest )
{
    import ocean.core.Test;
}


/*******************************************************************************

    Resets each field of a struct in a shallow manner. Just like
    `ocean.util.DeepReset : DeepReset`, this function sets non-aggregate members
    in the struct to their init value, and resets the lengths of dynamic arrays
    in the struct to zero. Also, just like DeepReset, associative arrays are not
    supported.

    The differences between this function and DeepReset are:
        1. Only structs are supported (not classes)
        2. Structs containing nested structs/classes are not supported
        3. Structs containing static arrays are not supported

    The main motivation for introducing this function (and not simply using the
    existing DeepReset functionality) is that DeepReset recurses into and
    individually resets every element of each dynamic array present in the
    struct. However, this additional work is sometimes overkill for certain
    performance critical applications where just resetting the lengths of the
    dynamic arrays to zero suffices.

    Params:
        T = the type of the struct
        dst = the struct to be reset

*******************************************************************************/

public void structShallowReset ( T ) ( ref T dst )
{
    static assert(is(T == struct),
        "structShallowReset: '" ~ T.stringof ~ "' is not a struct");

    foreach ( i, member; dst.tupleof )
    {
        static assert(
            !isAssocArrayType!(typeof(member)) &&
            !is(typeof(member) == class) &&
            !is(typeof(member) == struct),
            "structShallowReset does not support member '" ~
            dst.tupleof[i].stringof ~ "' of type '" ~ typeof(member).stringof ~
            "'");

        static if ( is(typeof(member) S : S[]) ) // some sort of array
        {
            static if ( is(typeof(member) U == S[]) ) // dynamic array
            {
                dst.tupleof[i].length = 0;
            }
            else // static array
            {
                static assert(false, "structShallowReset does not support " ~
                    "member '" ~ dst.tupleof[i].stringof ~ "' of type '" ~
                    typeof(member).stringof ~ "' (static array)");
            }
        }
        else
        {
            dst.tupleof[i] = dst.tupleof[i].init;
        }
    }
}

unittest
{
    struct A
    {
        int w;
        int[] x;
        char y;
        char[] z;
    }

    A a;

    a.w = 10;
    a.x ~= 200;
    a.x ~= 300;
    a.y = 'a';
    a.z ~= 'p';
    a.z ~= 'q';
    a.z ~= 'r';

    test!("==")(a.w, 10);
    test!("==")(a.x.length, 2);
    test!("==")(a.y, 'a');
    test!("==")(a.z.length, 3);

    structShallowReset(a);

    test!("==")(a.w, typeof(a.w).init);
    test!("==")(a.x.length, 0);
    test!("==")(a.y, typeof(a.y).init);
    test!("==")(a.z.length, 0);
}
