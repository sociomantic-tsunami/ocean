/*******************************************************************************

    Utility that resets value state in a way that its memory can be reused again
    as much as possible. Resets arrays to 0 length and values to their init
    state.

    Copyright:
        Copyright (c) 2018 sociomantic labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.meta.values.Reset;

import ocean.transition;

import ocean.meta.values.VisitValue;
import ocean.meta.traits.Basic;

import ocean.core.Test;

/*******************************************************************************

    Utility that resets value state in a way that its memory can be reused again
    as much as possible. Resets arrays to 0 length and values to their init
    state.

    Non-class references are ignored. For classes it tries to recurse
    into fields of the class instance without nullifying actual reference.

    Params:
        value = value to reset

*******************************************************************************/

public void reset ( T ) ( ref T value )
{
    Reset visitor;
    visitValue(value, visitor);
}

///
unittest
{
    // Can reset single value:
    int x = 42;
    reset(x);
    test!("==")(x, 0);

    // Or some array:
    int[] arr = [ 1, 2, 3 ];
    reset(arr);
    test!("==")(arr.length, 0);
    test!("!=")(arr.ptr, null);

    // Or some aggregate recursively:
    struct S
    {
        int x;
        mstring buf;
    }

    auto s = S(42, "abcd".dup);
    reset(s);
    test!("==")(s.x, 0);
    test!("==")(s.buf.length, 0);
}

/// Visitor for ocean.meta.values.VisitValue
private struct Reset
{
    // has to be public to be usable from VisitValue module
    public bool visit ( T ) ( T* value )
    {
        static if (isArrayType!(T) == ArrayKind.Dynamic)
        {
            (*value).length = 0;
            enableStomping(*value);
        }
        else static if (isPrimitiveType!(T))
        {
            *value = T.init;
        }

        return is(T == class) || !isReferenceType!(T);
    }
}
