/*******************************************************************************

    Utilities to manipulate array types

    Copyright:
        Copyright (c) 2017 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.meta.types.Arrays;

import ocean.meta.traits.Basic;

/*******************************************************************************

    Params:
        T = any array type

    Returns:
        If T is static or dynamic array, evaluates to single type which is the
        element type of that array. If T is an associative array, return
        templated struct with separate type aliases for `Key` and `Value`.

*******************************************************************************/

public template ElementTypeOf ( T )
{
    static if (isArrayType!(T) == ArrayKind.Dynamic
            || isArrayType!(T) == ArrayKind.Static)
    {
        static if (is(T U : U[]))
        {
            alias U ElementTypeOf;
        }
    }
    else static if (isArrayType!(T) == ArrayKind.Associative)
    {
        alias AAElementType!(typeof(T.init.keys[0]), typeof(T.init.values[0]))
            ElementTypeOf;
    }
    else
    {
        static assert (false, "T must be some array type");
    }
}

///
unittest
{
    static assert (is(ElementTypeOf!(int[]) == int));
    static assert (is(ElementTypeOf!(int[5]) == int));
    static assert (is(ElementTypeOf!(int[][10]) == int[]));

    alias ElementTypeOf!(double[int]) ElementType;
    static assert (is(ElementType.Key == int));
    static assert (is(ElementType.Value == double));
}

/// see `ElementTypeOf`
public struct AAElementType ( TKey, TValue )
{
    alias TKey Key;
    alias TValue Value;
}
