/*******************************************************************************

    Traits for aggregate types - structs, classes, unions.

    Copyright:
        Copyright (C) 2017 dunnhumby Germany GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.meta.traits.Aggregates;

import ocean.meta.traits.Basic;
import ocean.meta.types.Qualifiers;

/*******************************************************************************

    Checks for presence of method/field with specified name in aggregate.

    In D1 most common idiom is to simply check for `is(typeof(T.something))` but
    in D2 it can backfire because of UFCS as global names are checked too - thus
    built-in `__traits(hasMember)` is used instead, which was not available in
    D1.

    Params:
        T = aggregate type to check
        name = method/field name to look for

    Returns:
        `true` if aggregate T has a method/field with an identifier `name`

*******************************************************************************/

public template hasMember ( T, istring name )
{
    static assert (isAggregateType!(T));

    version (D_Version2)
        mixin ("enum hasMember = __traits(hasMember, T, name);");
    else
        mixin ("const hasMember = is(typeof(T." ~ name ~ "));");
}

///
unittest
{
    struct S
    {
        void foo () { }
        int x;
    }

    static assert ( hasMember!(S, "foo"));
    static assert ( hasMember!(S, "x"));
    static assert (!hasMember!(S, "bar"));
}

/*******************************************************************************

    Checks for presence of a method with specified name and type for a given
    aggregate type.

    Params:
        T = aggregate type to check
        name = method/field name to look for
        F = method type (using `function` keyword for static method, `delegate`
            for non-static ones)

    Returns:
        `true` if aggregate T has a method/field with an identifier `name` and
        type `F`.

*******************************************************************************/

public template hasMethod ( T, istring name, F )
{
    static if (hasMember!(T, name))
    {
        static immutable hasMethod = is(typeof(mixin("&T.init." ~ name)) : F);
    }
    else
        static immutable hasMethod = false;
}

///
unittest
{
    struct S
    {
        int foo1 ( double ) { return 0; }
        static int foo2  ( double ) { return 0; }
        int delegate(double) foo3;
    }

    static assert ( hasMethod!(S, "foo1", int delegate(double)));
    static assert (!hasMethod!(S, "foo1", void delegate(double)));
    static assert (!hasMethod!(S, "foobar", int delegate(double)));

    static assert ( hasMethod!(S, "foo2", int function(double)));
    static assert (!hasMethod!(S, "foo3", int delegate(double)));
}
