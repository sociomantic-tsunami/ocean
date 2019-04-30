/*******************************************************************************

    Generic utility allowing to recursively visit an arbitrary type and reduce
    its definition to some compile-time value. It is intended to be used as an
    implementation cornerstone for complex type traits to avoid having to
    rewrite the recursive type reflection boilerplate wherever it's needed.

    NB: because this module is often used as purely compile-time dependency it
        used built-in asserts instead of `ocean.core.Test` to reduce amount of
        cyclic imports. `ocean.meta` modules in general are not supposed to
        import anything outside of `ocean.meta`.

    Copyright:
        Copyright (c) 2017 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.meta.types.ReduceType;

import ocean.meta.traits.Basic;
import ocean.meta.types.Arrays;
import ocean.meta.types.Typedef;

/*******************************************************************************

    Reduces definition of a type to single value using provided Reducer.

    If Reducer does not specify `seed` and `accumulate` explicitly, defaults
    to `false` seed and `a || b` accumulator. `Result` must alias bool in such
    case.

    NB: currently `ReduceType` does not work with types which have recursive
    definition, for example `struct S { S* ptr; }`, crashing compiler at CTFE
    stage. This will be improved in the future.

    Params:
        T = arbitrary type to visit/reduce
        Reducer = struct type conforming `assertValidReducer` requirements used
            to do actual calculations/checks on the type

    Example:

    Example reducer that counts amount of integer typed entities accessible
    though the base types (i.e. fields and referenced types):

    ---
    static struct ExampleReducer
    {
        alias int Result;
        const seed = 0;

        Result accumulate ( Result accum, Result next )
        {
            return accum + next;
        }

        Result visit ( T ) ( )
        {
            if (isIntegerType!(T))
                return 1;
        }
    }

    static assert (ReduceType!(int, ExampleReducer) == 1);
    static assert (ReduceType!(int[int], ExampleReducer) == 2);
    ---

    Returns:
        value of type `Reducer.Result` calculated by calling `Reducer.visit` on
        each nested type of `T` recursively and reducing via
        `Reducer.accumulate`.

*******************************************************************************/

public template ReduceType ( T, Reducer )
{
    static immutable ReduceType = ReduceTypeImpl!(Reducer).init.reduce!(T)();
}

/*******************************************************************************

    Verifies that `Reducer` is an aggregate type that conforms type reducer
    requirements and issues static assertion otherwise.

    Params:
        Reducer = aggregate type to check

*******************************************************************************/

public template assertValidReducer ( Reducer )
{
    static assert (
        is(Reducer.Result),
        Reducer.stringof ~  " must define `Result` type alias"
    );
    static assert (
        is(typeof(Reducer.visit!(int))),
        Reducer.stringof ~ " must define `visit` templated function "
            ~ "that takes a type as template argument and returns single "
            ~ "value of Result type"
    );

    alias void assertValidReducer;
}

/*******************************************************************************

    Implementation for `ReduceType` handling type recursion

    Params:
        Reducer = see `ReduceType` param documentation

*******************************************************************************/

private struct ReduceTypeImpl ( Reducer )
{
    // Give better error messages for wrong `Reducer` definitions
    alias assertValidReducer!(Reducer) check;

    // Create instance of reducer struct in case implementation may need
    // internal state
    Reducer reducer;

    // Helper to calculate new value and update accumulator in one step
    private void accumulate ( T ) ( ref T accum, T next )
    {
        static if (is(typeof(Reducer.accumulate)))
        {
            accum = reducer.accumulate(accum, next);
        }
        else
        {
            static assert (
                is(T == bool),
                "Must specify custom accumulator method for non-bool results"
                    ~ "of ReduceType"
            );
            accum = accum || next;
        }
    }

    // Main recursive visiting implementation
    private Reducer.Result reduce ( T ) ( )
    {
        static if (is(typeof(reducer.seed)))
            auto result = reducer.seed;
        else
        {
            static assert (
                is(Reducer.Result == bool),
                "Default seed/accumulator are only supported for bool"
                    ~ " ReduceType results"
            );
            auto result = false;
        }

        accumulate(result, reducer.visit!(T)());

        static if (isPrimitiveType!(T))
        {
            // do nothing, already processed
        }
        else static if (isTypedef!(T))
        {
            accumulate(result, reducer.visit!(TypedefBaseType!(T)));
        }
        else static if (isAggregateType!(T))
        {
            foreach (TElem; typeof(T.init.tupleof))
                accumulate(result, reduce!(TElem)());
        }
        else static if (isArrayType!(T))
        {
            static if (
                   isArrayType!(T) == ArrayKind.Static
                || isArrayType!(T) == ArrayKind.Dynamic)
            {
                accumulate(result, reduce!(ElementTypeOf!(T))());
            }
            else
            {
                // associative
                accumulate(result, reduce!(ElementTypeOf!(T).Key));
                accumulate(result, reduce!(ElementTypeOf!(T).Value));
            }
        }
        else static if (isFunctionType!(T))
        {
            // ignored for now, visiting argument/return types may be
            // considered eventually
        }
        else static if (isPointerType!(T))
        {
            accumulate(result, reduce!(typeof(*T.init))());
        }
        else static if (is(T U == enum))
        {
            accumulate(result, reduce!(U)());
        }
        else
        {
            static assert (false,
                "Unexpected type kind during recursive iteration: " ~ T.stringof);
        }

        return result;
    }
}


version (UnitTest)
{
    import ocean.meta.types.Qualifiers;

    private struct TestAggregate
    {
        int x;
        float[] y;
        void* z;
    }

    private struct CheckPrimitiveReducer
    {
        alias bool Result;

        Result visit ( T ) ( )
        {
            return isPrimitiveType!(T);
        }
    }
}

// Sanity test of instantiation of `ReduceType` with primitive types
unittest
{
    assert(ReduceType!(int, CheckPrimitiveReducer));
    assert(ReduceType!(void, CheckPrimitiveReducer));
}

// Sanity test of instantiation of `ReduceType` with aggregate types
unittest
{
    assert(!ReduceType!(CheckPrimitiveReducer, CheckPrimitiveReducer));

    // Exposes compilation error
    // assert(ReduceType!(Const!TestAggregate, CheckPrimitiveReducer));
}

// Sanity test of instantiation of `ReduceType` with static array types
unittest
{
    assert(ReduceType!(float[9], CheckPrimitiveReducer));
    assert(ReduceType!(void[9], CheckPrimitiveReducer));
}

// Sanity test of instantiation of `ReduceType` with dynamic array types
unittest
{
    assert(ReduceType!(char[], CheckPrimitiveReducer));
    assert(ReduceType!(void[], CheckPrimitiveReducer));
}

// Sanity test of instantiation of `ReduceType` with function type
unittest
{
    auto test_dg = delegate ( ) { return 0; };
    assert(!ReduceType!(typeof(test_dg), CheckPrimitiveReducer));

    auto test_fn = function ( ) { return 0; };
    assert(!ReduceType!(typeof(test_fn), CheckPrimitiveReducer));
}

// Sanity test of instantiation of `ReduceType` with enums
unittest
{
    enum TestEnum : int { ZERO, ONE, TWO }
    assert(ReduceType!(TestEnum, CheckPrimitiveReducer));
}

// Sanity test of instantiation of `ReduceType` with pointer types
unittest
{
    assert(ReduceType!(int*, CheckPrimitiveReducer));

    // Exposes compilation error
    // assert(ReduceType!(void*, CheckPrimitiveReducer));
}
