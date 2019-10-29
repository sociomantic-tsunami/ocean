/*******************************************************************************

    Traits for arrays and array-like types.

    Note: utils that operate on array types but evaluate to another type (and
    not some compile-time value) reside in `ocean.meta.types.Arrays`, not in
    this module.

    Copyright:
        Copyright (C) 2017 dunnhumby Germany GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.meta.traits.Arrays;

import ocean.meta.traits.Basic;
import ocean.meta.types.Arrays;
import ocean.meta.types.Qualifiers;

/*******************************************************************************

    Params:
        T = any type

    Returns:
        `true` if T represents UTF-8 string type

*******************************************************************************/

template isUTF8StringType ( T )
{
    static immutable isUTF8StringType =
        isBasicArrayType!(T) && is(Unqual!(ElementTypeOf!(T)) == char);
}

///
unittest
{
    static assert (isUTF8StringType!(char[1]));
    static assert (isUTF8StringType!(char[]));
    static assert (isUTF8StringType!(Immut!(char)[]));
    static assert (!isUTF8StringType!(wchar[]));
}

/*******************************************************************************

    Params:
        T = any type

    Returns:
        Depth of array nesting (1 for plain array) if T is an array, 0 otherwise

*******************************************************************************/

template rankOfArray ( T )
{
    static if (is(T S : S[]))
        enum rankOfArray = 1 + rankOfArray!S;
    else
        enum rankOfArray = 0;
}

///
unittest
{
    static assert (rankOfArray!(real[][]) == 2);
    static assert (rankOfArray!(real[2][]) == 2);
}
