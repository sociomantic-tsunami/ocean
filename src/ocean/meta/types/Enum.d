/*******************************************************************************

    Copyright:
        Copyright (C) 2017 dunnhumby Germany GmbH. All rights reserved.

    NB: because this module is often used as purely compile-time dependency it
        used built-in asserts instead of `ocean.core.Test` to reduce amount of
        cyclic imports. `ocean.meta` modules in general are not supposed to
        import anything outside of `ocean.meta`.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.meta.types.Enum;

/*******************************************************************************

    If T is enum, aliases to its base type. Otherwise aliases to T.

    Params:
        T = any type

*******************************************************************************/

public template EnumBaseType ( T )
{
    static if (is(T U == enum))
    {
        alias EnumBaseType = U;
    }
    else
    {
        alias EnumBaseType = T;
    }
}

unittest
{
    enum Test : int
    {
        field = 42
    }

    static assert (is(EnumBaseType!(typeof(Test.field)) == int));
    static assert (is(EnumBaseType!double == double));
}
