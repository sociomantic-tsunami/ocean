/*******************************************************************************

    Utilities to get string representations of symbols.

    Copyright:
        Copyright (c) 2017 sociomantic Labs GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.meta.codegen.Identifier;

import ocean.meta.AliasSeq;
import ocean.meta.codegen.CTFE;
import ocean.meta.types.Qualifiers;
import ocean.meta.traits.Function;

version (UnitTest)
{
    import ocean.meta.types.Typedef;
}

/*******************************************************************************

    Returns "name" (identifier) of a given symbol as string

    When used with aggregate type field, will return only name of field itself,
    without any qualification.

    Params:
        Sym = any symbol alias

*******************************************************************************/

public template identifier ( alias Sym )
{
    static if (is(typeof(Sym) == function))
        static immutable identifier = funcIdentifierHack!(Sym)();
    else
        static immutable identifier = Sym.stringof;
}

///
unittest
{
    class ClassName { int fieldName; }

    static assert (identifier!(ClassName) == "ClassName");
    assert (identifier!(ClassName) == "ClassName");

    static assert (identifier!(ClassName.fieldName) == "fieldName");
    assert (identifier!(ClassName.fieldName) == "fieldName");

    void funcName ( ) { }

    static assert (identifier!(funcName) == "funcName");
    assert (identifier!(funcName) == "funcName");

    extern(C) static void funcNameArgs ( int a, double b ) { }

    static assert (identifier!(funcNameArgs) == "funcNameArgs");
    assert (identifier!(funcNameArgs) == "funcNameArgs");
}

/*******************************************************************************

    Because of interaction with optional parens syntax, one can't simply do
    `foo.stringof` if `foo` is a function symbol and fake argument list needs
    to be constructed.

*******************************************************************************/

private istring funcIdentifierHack(alias Sym)()
{
    // Sym.stringof is treated as Sym().stringof
    // ugly workaround:
    ParametersOf!(typeof(Sym)) args;
    auto name = Sym(args).stringof[];
    size_t bracketIndex = 0;
    while (name[bracketIndex] != '(' && bracketIndex < name.length)
        ++bracketIndex;
    return name[0 .. bracketIndex];
}

/*******************************************************************************

    Template to get the name of the ith member of a struct / class.

    Used over plain `identifier` when iterating over aggregate fields with
    `.tupleof` as D1 compiler refuses to pass such field as template alias
    parameter.

    Params:
        i = index of member to get
        T = type of compound to get member name from

    Returns:
        name of the ith member

*******************************************************************************/

public template fieldIdentifier ( T, size_t i )
{
    static immutable istring fieldIdentifier = stripQualifiedPrefix(T.tupleof[i].stringof);
}

unittest
{
    static struct TestStruct
    {
        int a;
        double b;
    }

    static assert (fieldIdentifier!(TestStruct, 0) == "a");
    static assert (fieldIdentifier!(TestStruct, 1) == "b");

    assert (fieldIdentifier!(TestStruct, 0) == "a");
    assert (fieldIdentifier!(TestStruct, 1) == "b");

    struct Foo { AliasSeq!(int, double, Object) fields; }
    version (D_Version2)
        static assert (fieldIdentifier!(Foo, 0) == "__fields_field_0");
    else
        static assert (fieldIdentifier!(Foo, 0) == "_fields_field_0");
}
