/*******************************************************************************

    Traits specific to various function-like types

    Copyright:
        Copyright (c) 2017 sociomantic Labs GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.meta.traits.Function;

import ocean.meta.AliasSeq;
import ocean.meta.traits.Basic;

/*******************************************************************************

    Evaluates to a compile-time sequence representing the parameters of Fn

    Params:
        TCallable = callable type (function/delegate/function pointer)

*******************************************************************************/

template ParametersOf ( TCallable )
{
    static if (is( TCallable Params == function ))
        alias AliasSeq!(Params) ParametersOf;
    else static if (is( TCallable TDgPtr == delegate ))
        alias AliasSeq!(ParametersOf!(TDgPtr)) ParametersOf;
    else static if (is( TCallable TFunc == TFunc* ))
        alias AliasSeq!(ParametersOf!(TFunc)) ParametersOf;
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
