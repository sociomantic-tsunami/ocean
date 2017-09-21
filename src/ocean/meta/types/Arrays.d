/*******************************************************************************

    Utilities to manipulate array types

    NB: because this module is often used as purely compile-time dependency it
        used built-in asserts instead of `ocean.core.Test` to reduce amount of
        cyclic imports. `ocean.meta` modules in general are not supposed to
        import anything outside of `ocean.meta`.

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

/*******************************************************************************

    Params:
        T = any type

    Returns:
        If T is static or dynamic array, evaluates to single type which is the
        element type of that array. If such element type would also be an array,
        evaluates to its element type instead and so on recursively. In all
        other cases evaluates to just T.

*******************************************************************************/

public template StripAllArrays ( T )
{
    static if (isArrayType!(T) == ArrayKind.Dynamic
            || isArrayType!(T) == ArrayKind.Static)
    {
        alias StripAllArrays!(ElementTypeOf!(T)) StripAllArrays;
    }
    else
    {
        alias T StripAllArrays;
    }
}

///
unittest
{
    static assert (is(StripAllArrays!(int[][4][][]) == int));
    static assert (is(StripAllArrays!(int[float][4][][]) == int[float]));
    static assert (is(StripAllArrays!(double) == double));
}
