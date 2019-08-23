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

alias Immut!(char)[] istring;
alias Const!(char)[] cstring;
alias char[]         mstring;

/*******************************************************************************

    Helper template to be used instead of plain types in function parameter
    list when one will need to be const-qualified in D2 world - usually this is
    necessary if function needs to handle string literals.

    This should be used instead of istring/cstring aliases in generic array
    processing functions as opposed to string-specific code.

    Example:

    ---
    void foo(Element)(Const!(Element)[] buf)
    {
    }

    foo!(char)("aaa"); // will work in both D1 and D2
    ---

*******************************************************************************/

template Const(T)
{
    alias const(T) Const;;
}

unittest
{
    alias Const!(int[]) Int;

    static assert (is(Int));

    static assert (is(Int == const));
}

/*******************************************************************************

    Same as Const!(T) but for immutable

    Example:

    ---
    Immut!(char)[] foo()
    {
        return "aaa"; // ok, immutable
        return new char[]; // error, mutable
    }
    ---

*******************************************************************************/

template Immut(T)
{
    alias immutable(T) Immut;
}

unittest
{
    alias Immut!(int[]) Int;

    static assert (is(Int));

    static assert (is(Int == immutable));
}

/*******************************************************************************

    Same as Const!(T) but for inout

    Example:

    ---
    Inout!(char[]) foo(Inout!(char[]) arg)
    {
        return arg;
    }

    mstring = foo("aaa"); // error
    istring = foo("aaa"); // ok
    mstring = foo("aaa".dup); // ok
    ---

*******************************************************************************/

template Inout(T)
{
    alias inout(T) Inout;
}

unittest
{
    alias Inout!(char[]) Str;

    Str foo ( Str arg ) { return arg; }

    char[] s1 = foo("aaa".dup);
    Immut!(char)[] s2 = foo("aaa");
}

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
