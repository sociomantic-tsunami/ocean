/*******************************************************************************

    Traits specific to various function-like types

    NB: because this module is often used as purely compile-time dependency it
        used built-in asserts instead of `ocean.core.Test` to reduce amount of
        cyclic imports. `ocean.meta` modules in general are not supposed to
        import anything outside of `ocean.meta`.

    Copyright:
        Copyright (c) 2017 sociomantic Labs GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.meta.types.Function;

import ocean.meta.AliasSeq;
import ocean.meta.traits.Basic;
import ocean.meta.types.Typedef;

/*******************************************************************************

    Evaluates to a compile-time sequence representing the parameters of
    Callable

    Params:
        Callable = callable type (function/delegate/function pointer) or
            function symbol. Represented by variadic template of length 1 to
            accept both types and function symbols.

*******************************************************************************/

public template ParametersOf ( Callable... )
{
    static assert (Callable.length == 1);

    static if (is(Callable[0] Params == function))
        alias AliasSeq!(Params) ParametersOf;
    else static if (is(typeof(Callable[0]) Params == function))
        alias AliasSeq!(Params) ParametersOf;
    else static if (is(Callable[0] TDgPtr == delegate))
        alias AliasSeq!(ParametersOf!(TDgPtr)) ParametersOf;
    else static if (is(Callable[0] TFunc == TFunc*))
        alias AliasSeq!(ParametersOf!(TFunc)) ParametersOf;
    else static if (isTypedef!(Callable[0]))
        alias ParametersOf!(TypedefBaseType!(Callable[0])) ParametersOf;
    else
        static assert (false, "Argument is not a function");
}

///
unittest
{
    void foo(int x, ref double y, char[] z) {}
    alias ParametersOf!(typeof(foo)) Params;

    static assert (Params.length == 3);
    static assert (is(Params[0] == int));
    static assert (is(Params[1] == double));
    static assert (is(Params[2] == char[]));
}

unittest
{
    void foo(int x, ref double y, char[] z) {}
    alias ParametersOf!(typeof(&foo)) Params;

    static assert (Params.length == 3);
    static assert (is(Params[0] == int));
    static assert (is(Params[1] == double));
    static assert (is(Params[2] == char[]));
}

unittest
{
    void delegate(int x, ref double y, char[] z) dg;
    alias ParametersOf!(typeof(dg)) Params;

    static assert (Params.length == 3);
    static assert (is(Params[0] == int));
    static assert (is(Params[1] == double));
    static assert (is(Params[2] == char[]));
}

/*******************************************************************************

    Deduces return type of a callable

    Params:
        Callable = callable type (function/delegate/function pointer) or
            function symbol. Represented by variadic template of length 1 to
            accept both types and function symbols.

    Returns:
        evaluates to return type of the callable

*******************************************************************************/

public template ReturnTypeOf ( Callable... )
{
    static assert (Callable.length == 1);

    static if (is(typeof(Callable[0]) == function))
    {
        alias typeof({
                ParametersOf!(Callable[0]) args;
                return Callable[0](args);
            } ()) ReturnTypeOf;
    }
    else
    {
        alias typeof({
                ParametersOf!(Callable[0]) args;
                Callable[0] call;
                return call(args);
            } ()) ReturnTypeOf;
    }
}

///
unittest
{
    static assert (is(ReturnTypeOf!(void function()) == void));
    static assert (is(ReturnTypeOf!(int function(char)) == int));
    static assert (is(ReturnTypeOf!(int delegate(char)) == int));

    double foo ( char[], int ) { return 0; }
    static assert (is(ReturnTypeOf!(foo) == double));
    static assert (is(ReturnTypeOf!(typeof(&foo)) == double));

    static assert (is(ReturnTypeOf!(int delegate(ref int)) == int));
}

unittest
{
    mixin (Typedef!(int, "MyType"));
    MyType foo2() { return MyType.init; }
    static assert (is(ReturnTypeOf!(foo2) == MyType));

    mixin (Typedef!(double function(), "MyFuncType"));
    alias ReturnTypeOf!(MyFuncType) X;
    static assert (is(ReturnTypeOf!(MyFuncType) == double));
}
