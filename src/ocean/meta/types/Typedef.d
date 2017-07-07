/*******************************************************************************

    Copyright:
        Copyright (C) 2017 Sociomantic Labs GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.meta.types.Typedef;

import ocean.meta.types.Qualifiers;

/*******************************************************************************

    Replacement for `typedef` which is completely deprecated. It generates
    usual `typedef` when built with D1 compiler and wrapper struct with
    `alias this` when built with D2 compiler.

    Used as mixin(Typedef!(hash_t, "MyHash"))

    D2 version has `IsTypedef` member alias defined so that any struct type
    can be quickly checked if it originates from typedef via
    `is(typeof(S.IsTypedef))`. This is a hack reserved for backwards
    compatibility in libraries and should be never relied upon in user code.

    Template Parameters:
        T       = type to typedef
        name    = identifier string for new type
        initval = optional default value for that type

*******************************************************************************/

template Typedef(T, istring name, T initval)
{
    static assert (name.length, "Can't create Typedef with an empty identifier");
    version(D_Version2)
    {
        mixin(`
            enum Typedef =
                ("static struct " ~ name ~
                "{ " ~
                "alias IsTypedef = void;" ~
                T.stringof ~ " value = " ~ initval.stringof ~ ";" ~
                "alias value this;" ~
                "this(" ~ T.stringof ~ " rhs) { this.value = rhs; }" ~
                " }");
        `);
    }
    else
    {
        mixin(`
            const Typedef = ("typedef " ~ T.stringof ~ " " ~ name ~
                " = " ~ initval.stringof ~ ";");
        `);
    }
}

/// ditto
template Typedef(T, istring name)
{
    static assert (name.length, "Can't create Typedef with an empty identifier");
    version(D_Version2)
    {
        mixin(`
            enum Typedef =
                ("static struct " ~ name ~
                "{ " ~
                "alias IsTypedef = void;" ~
                T.stringof ~ " value; " ~
                "alias value this;" ~
                "this(" ~ T.stringof ~ " rhs) { this.value = rhs; }" ~
                " }");
        `);
    }
    else
    {
        mixin(`
            const Typedef = ("typedef " ~ T.stringof ~ " " ~ name ~ ";");
        `);
    }
}

unittest
{
    mixin(Typedef!(int, "MyInt1", 42));
    mixin(Typedef!(int, "MyInt2", 42));

    static assert (!is(MyInt1 : MyInt2));

    MyInt1 myint;
    assert(myint == 42);

    void foo1(MyInt2) { }
    void foo2(MyInt1) { }
    void foo3(int) { }

    static assert (!is(typeof(foo1(myint))));
    static assert ( is(typeof(foo2(myint))));
    static assert ( is(typeof(foo3(myint))));

    int base = myint;
    assert(base == myint);
    myint = cast(MyInt1) (base + 1);
    assert(myint == 43);
}

unittest
{
    struct MyType { }

    mixin(Typedef!(MyType, "MyType2"));
    MyType2 var;

    static assert (is(typeof(var) : MyType));
}

unittest
{
    mixin(Typedef!(int, "MyInt"));
    MyInt var = 42;
    assert (var == 42);
}
