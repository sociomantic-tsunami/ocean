/*******************************************************************************

    Templates to define types with modified qualifiers based on some input
    types.

    Many of helper templates here have been added because of D1 to D2 migration
    to hide behind them qualifiers not supported in D1 (const, immutable,
    inout). Others, like `Unqual`, are generally useful even outside of
    migration context.

    NB: because this module is often used as purely compile-time dependency it
        used built-in asserts instead of `ocean.core.Test` to reduce amount of
        cyclic imports. `ocean.meta` modules in general are not supposed to
        import anything outside of `ocean.meta`.

    Copyright:
        Copyright (C) 2017 dunnhumby Germany GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.meta.types.Qualifiers;

/*******************************************************************************

    Convenience string type aliases.

    Initially defined to help with D2 migration but proved themselves as useful
    shortcuts to reduce visual code clutter.

*******************************************************************************/

deprecated("Use `string` directly")
alias immutable(char)[] istring;
alias const(char)[] cstring;
alias char[]         mstring;

/*******************************************************************************

    Strips top-most type qualifier.

    This is a small helper useful for adapting templated code where template
    parameter can possibly be deduced as const or immutable. Using this type
    directly in implementation will result in unmodifiable variables which isn't
    always wanted.

    Example:

    ---
    void foo(Element)(Element[] buf)
    {
        // this causes an error if element
        // gets deduced as const
        Element tmp;
        tmp = Element.init;

        // this is ok
        Unqual!(Element) tmp;
        tmp = Element.init;
    }
    ---

*******************************************************************************/

template Unqual(T)
{
    static if (is(T U == const U))
    {
        alias U Unqual;
    }
    else static if (is(T U == immutable U))
    {
        alias U Unqual;
    }
    else
    {
        alias T Unqual;
    }
}

unittest
{
    static assert (is(Unqual!(typeof("a"[0])) == char));
}
