/*******************************************************************************

    This modules contains utilities and aliases that are used during D1->D2
    transition process. Idea is to define single module that contains wrapper
    aliases / structures and switch all code to use it. Once actual porting
    time comes it will be enough to simply change version in this module.

    version(D2) can't be used because D2 code can't be even parsed by D1
    compiler, resorting to commenting out because of that.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.transition;

import ocean.meta.traits.Basic;
import ocean.meta.types.Arrays;

public import ocean.core.TypeConvert : assumeUnique;
public import ocean.meta.types.Qualifiers;
public import ocean.meta.types.Typedef;

/*******************************************************************************

    Checks (non-transitively) if type is mutable

    Params:
        T = any plain type

*******************************************************************************/

template isMutable( T )
{
    enum isMutable = !is(T == const) && !is(T == immutable);
}

unittest
{
    static assert (!isMutable!(typeof("aaa"[0])));
}

/*******************************************************************************

    Helper to smooth transition between D1 and D2 runtime behaviours regarding
    array stomping. In D2 appending to array slice after length has been changed
    results in allocating new array to prevent overwriting old data.

    We use and actually rely on that behaviour for buffer re-usage.
    `assumeSafeAppend` from object.d enables stomping back but adding using this
    no-op wrapper in D1 code will save time on trying to find those extremely
    subtle issues upon actual transition.

    All places that reset length to 0 will need to call this helper.

    Params:
        array = array slice that is going to be overwritten

*******************************************************************************/

void enableStomping(T)(ref T[] array)
{
    static assert (
        is(T == Unqual!(T)),
        "Must not call `enableStomping` on const/immutable array"
    );

    assumeSafeAppend(array);
}

/*******************************************************************************

    Helper template that can be used instead of octal literals. In some cases
    preserving octal notation is really important for readability and those
    can't be simply replace with decimal/hex ones.

    Params:
        literal = octal number literal as string

*******************************************************************************/

static import ocean.text.convert.Integer_tango;

template Octal(string literal)
{
    static immutable Octal = ocean.text.convert.Integer_tango.parse(literal, 8);
}

unittest
{
    static assert (Octal!("00") == 0);
    static assert (Octal!("12") == 10);
    static assert (Octal!("1") == 1);
    static assert (Octal!("0001") == 1);
    static assert (Octal!("0010") == 8);
    static assert (Octal!("666") == (6 + 8*6 + 8*8*6));
}

/*******************************************************************************

    Mixin helper to generate proper opCmp declaration. It differs between D1
    and D2 runtime and not matching exact signature will result in weird
    segmentation faults from inside the runtime.

    Params:
        func_body = code of opCmp as string. Must refer to argument as `rhs`

    Returns:
        full declaration/definition of opCmp that matches current compiler

*******************************************************************************/

string genOpCmp(string func_body)
{
    string result;

    // We need to know if it's a class or not. If it is, one might want to
    // compare against literals, so we cannot take it by `const ref`.

    result ~= "static if (is(typeof(this) == class))\n{\n";
    result ~= "override int opCmp(Object rhs)\n";
    result ~= func_body;
    result ~= "\n}\nelse\n{\n";
    result ~= "int opCmp(const typeof(this) rhs) const\n";
    result ~= func_body;
    result ~= "\n}\n";

    return result;
}

unittest
{
    struct S
    {
        int x;

        mixin (genOpCmp("
        {
            if (this.x >= rhs.x)
                return this.x > rhs.x;
            return -1;
        }
        "));

        equals_t opEquals (S rhs)
        {
            return this.opCmp(rhs) == 0;
        }
    }

    class C
    {
        private int x;

        this (int a)
        {
            this.x = a;
        }

        mixin (genOpCmp(
        `{
            auto o = cast(typeof(this)) rhs;
            if (o is null)
                return -1;
            if (this.x >= o.x)
                return this.x > o.x;
            return -1;
        }`));
    }

    assert (S(1) < S(2));
    assert (S(2) > S(1));
    assert (S(2) >= S(2));
    assert (S(2) <= S(2));
    assert (new C(1) < new C(2));
    assert (new C(2) > new C(1));
    assert (new C(2) >= new C(2));
    assert (new C(2) <= new C(2));
}

/*******************************************************************************

    Mixin helper to generate proper opEquals declaration. It differs between D1
    and D2 runtime and not matching exact signature will result in the default
    version, defined by the compiler, to be silently called instead.

    Params:
        func_body = code of opEquals as string. Must refer to argument as `rhs`

    Returns:
        full declaration/definition of opEquals that matches current compiler

*******************************************************************************/

public string genOpEquals(string func_body)
{
    string result;

    // We need to know if it's a class or not. If it is, one might want to
    // compare against literals, so we cannot take it by `const ref`.

    result ~= "static if (is(typeof(this) == class))\n{\n";
    result ~= "override equals_t opEquals(Object rhs)\n";
    result ~= func_body;
    result ~= "\n}\nelse\n{\n";
    result ~= "bool opEquals(const typeof(this) rhs) const\n";
    result ~= func_body;
    result ~= "\n}\n";

    return result;
}

unittest
{
    struct S
    {
        int x;
        int y;

        // Use a crazy definition, as the default one would pass those tests :)
        mixin (genOpEquals("
        {
            return this.x == rhs.y && this.y == rhs.x;
        }
        "));
    }

    class C
    {
        private int x;

        this (int a)
        {
            this.x = a;
        }

        mixin (genOpEquals(
        `{
            auto o = cast(typeof(this)) rhs;
            if (o is null) return false;
            return (this.x == o.x);
        }`));
    }

    assert (S(2, 1) == S(1, 2));
    assert (new C(2) == new C(2));

    assert (S(1, 2) != S(1, 2));
    assert (S(2, 1) != S(2, 1));
    assert (!(S(1, 2) == S(1, 2)));
    assert (!(S(2, 1) == S(2, 1)));

    C nil;

    assert (new C(1) != new C(2));
    assert (new C(2) != new C(1));
    assert (!(new C(1) == new C(2)));
    assert (!(new C(2) == new C(1)));
    assert (new C(1) != nil);
    assert (!(new C(1) == nil));

    // D1 runtime dereference null if it's LHS...
    //assert (nil != new C(2));
    //assert (!(nil == new C(2)));
}

/*******************************************************************************

    In D1, typeof(this) is always a reference type to the aggregate, while in
    D2 it's the actual type of the aggregate. It doesn't change anything for
    classes which are reference types, but for struct and unions, it yields
    a pointer instead of the actual type.
    d1tod2fix does the conversion automatically for `structs`, but there are
    places where manual intervention is needed (e.g. `mixin template`s).

*******************************************************************************/

public template TypeofThis()
{
    alias typeof(this) This;
}

version (unittest)
{
    private struct FooClass
    {
        mixin TypeofThis;
    }
    private struct FooStruct
    {
        mixin TypeofThis;
    }

    private union FooUnion
    {
        mixin TypeofThis;
    }
}

unittest
{
    static assert (is(FooClass.This == FooClass));
    static assert (is(FooStruct.This == FooStruct));
    static assert (is(FooUnion.This == FooUnion));
}

/*******************************************************************************

    Helper which provides stub implementation of GC.usage if it is not present
    upstream in order to keep ocean compiling and passing tests.

*******************************************************************************/

static import core.memory;

deprecated("Use `core.memory : GC.stats` directly")
void gc_usage ( out size_t used, out size_t free )
{
    auto stats = core.memory.GC.stats();
    used = stats.usedSize;
    free = stats.freeSize;
}

/*******************************************************************************

    Utility intended to help with situations when generic function had to return
    its templated argument which could turn out to be a static array. In D1 that
    would require slicing such argument as returning static array types is not
    allowed. In D2, however, static arrays are value types and such slicing is
    neither necessary nor memory-safe.

    Examples:

    ---
    SliceIfD1StaticArray!(T) foo ( T ) ( T input )
    {
        return input;
    }

    foo(42);
    foo("abcd"); // wouldn't work if `foo` tried to return just T
    ---

    Params:
        T = any type

    Returns:
        If T is a static array, evaluates to matching dynamic array. Othwerwise
        evaluates to just T.

*******************************************************************************/

public template SliceIfD1StaticArray ( T )
{
    alias T SliceIfD1StaticArray;
}

unittest
{
    static assert (is(SliceIfD1StaticArray!(int[4]) == int[4]));
    static assert (is(SliceIfD1StaticArray!(int[]) == int[]));
    static assert (is(SliceIfD1StaticArray!(double) == double));
}
