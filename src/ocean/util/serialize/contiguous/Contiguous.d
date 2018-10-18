/******************************************************************************

    Defines struct type that is guaranteed to be stored in a contiguous byte
    buffer including all referenced arrays / pointers.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.serialize.contiguous.Contiguous;


import ocean.transition;
import ocean.core.Verify;
import ocean.meta.traits.Indirections;
import ocean.core.Enforce;

version(UnitTest)
{
    import ocean.core.Test;
    debug = ContiguousIntegrity;
}


/*******************************************************************************

    "Tag" struct that wraps a void[] buffer with deserialized contents for
    the struct of type S. Intended as type-safe tool to guarantee that any
    operations on such structs preserve the contiguous data layout

    Params:
        S = type of the wrapped struct

*******************************************************************************/

struct Contiguous( S )
{
    /***************************************************************************

        Data buffer that stores deserialized struct data together with all
        referenced arrays in a single contiguous chunk

        `package` protection is used so that contiguous (de)serializer can
        access it directly

    ***************************************************************************/

    package void[] data;

    /***************************************************************************

        Used to work with `Contiguous!(S)` as if it was S*:

        --------
        struct S { int a; }
        Contiguous!(S) s = getS();
        s.ptr.a = 42;
        --------

        (replace it with "alias this" in D2)

        NB! You may only modify value types accessed via .ptr or elements
        of stored dynamic arrays. Modifying actual arrays (i.e. appending
        new elements) is strictly prohibited and can result in very hard to
        debug memory corruptions. When in doubt consult one of this module
        developers.

        Returns:
            Pointer to stored data cast to struct type

    /**************************************************************************/

    public S* ptr ( )
    {
        verify(((&this).data.length == 0) || ((&this).data.length >= S.sizeof));

        if ((&this).data.length == 0)
            return null;

        return cast(S*) (&this).data.ptr;
    }

    /***************************************************************************

        Recursively iterates `this` and all referenced pointers / arrays and
        verifies that data is indeed contiguous.

        Throws:
            Exception if assumption is not verified

    ***************************************************************************/

    public void enforceIntegrity()
    {
        if ((&this).data.ptr)
        {
            enforceContiguous(*cast(S*) (&this).data.ptr, (&this).data);
        }
    }

    /***************************************************************************

        Length getter.

        Returns:
            length of underlying data buffer

    ***************************************************************************/

    public size_t length()
    {
        return (&this).data.length;
    }

    /***************************************************************************

        Resets length to 0 allowing same buffer to be used as null indicator
        without creating new GC allocation later

    ***************************************************************************/

    public Contiguous!(S) reset()
    {
        (&this).data.length = 0;
        enableStomping((&this).data);
        return *(&this);
    }

    debug(ContiguousIntegrity)
    {
        invariant()
        {
            // can't call this.enforceIntegrity because it will trigger
            // invariant recursively being a public method

            if ((&this).data.length)
            {
                enforceContiguous(*cast(S*) (&this).data.ptr, (&this).data);
            }
        }
    }
}

unittest
{
    struct S { int x; }

    Contiguous!(S) instance;
    instance.data = (cast(void*) new S)[0..S.sizeof];
    instance.ptr.x = 42;

    instance.enforceIntegrity();

    test!("==")(
        instance.data,
        [ cast(ubyte)42, cast(ubyte) 0, cast(ubyte) 0, cast(ubyte) 0 ][]
    );

    test!("==")(instance.length, 4);
    instance.reset();
    test!("==")(instance.length, 0);
}

/*******************************************************************************

    Iterates over S members recursively and verifies that it only refers
    to data inside of contiguous data chunk

    Params:
        input = struct instance to verify
        allowed_range = data buffer it must fit into

    Throws:
        Exception if assumption is not verified

*******************************************************************************/

private void enforceContiguous (S) ( ref S input, in void[] allowed_range )
{
    static assert (
        is(S == struct),
        "can't verify integrity of non-struct types"
    );

    foreach (i, ref member; input.tupleof)
    {
        alias typeof(member) Member;

        static if (hasIndirections!(Member))
        {
            static if (is(Member U : U[]))
            {
                // static + dynamic arrays

                static if (is(Unqual!(Member) == U[]))
                {
                    if (member.ptr)
                    {
                        enforceRange(member, allowed_range);
                    }
                }

                static if (is(U == struct))
                {
                    foreach (ref element; member)
                    {
                        enforceContiguous(element, allowed_range);
                    }
                }
            }
            else static if (is(Member == struct))
            {
               // member structs

                enforceContiguous(member, allowed_range);
            }
            else
            {
                alias ensureValueTypeMember!(S, i) evt;
            }
        }
    }
}

/*******************************************************************************

    Verifies that `slice` only refers to data inside `allowed_range`

    Params:
        slice = array slice to verify
        allowed_range = data buffer it must fit into

    Throws:
        Exception if assumption is not verified

*******************************************************************************/

private void enforceRange(in void[] slice, in void[] allowed_range)
{
    auto upper_limit = allowed_range.ptr + allowed_range.length;
    enforce!(">=")(slice.ptr, allowed_range.ptr);
    enforce!("<=")(slice.ptr, upper_limit);
    enforce!("<=")(slice.ptr + slice.length, upper_limit);
}

/*******************************************************************************

    Ensures that the type of the `i`th member of `S` (i.e. `S.tupleof[i]`) is a
    value type; that is, it contains no references.

    Params:
        S = an aggregate type (usually a struct)
        i = the index of the aggregate member to check

*******************************************************************************/

package template ensureValueTypeMember ( S, size_t i )
{
    alias ensureValueTypeMember!(S, i, typeof(S.tupleof)[i]) ensureValueTypeMember;
}

/*******************************************************************************

    Ensures that `T`, which is a the nested type of the type of the `i`th member
    of `S` (i.e. `S.tupleof[i]`),  is a value type; that is, it contains no
    references.

    Params:
        S = an aggregate type (usually a struct), for the message
        i = the index of the aggregate member to check, for the message
        T = the type that is expected to be a value type

*******************************************************************************/

package template ensureValueTypeMember ( S, size_t i, T )
{
    alias typeof(S.tupleof)[i] M;

    static if (is (T == union))
    {
        static assert (!containsDynamicArray!(T),
                       M.stringof ~ " " ~ S.tupleof[i].stringof ~
                       " - unions containing dynamic arrays are not " ~
                       "allowed, sorry");
    }

    static assert(!hasIndirections!(T),
                  M.stringof ~ " " ~ S.tupleof[i].stringof ~
                  " is a or contains an unsupported reference type");
}

version (UnitTest)
    import core.stdc.string: memset;

unittest
{
    mixin(Typedef!(int, "MyInt"));

    // prepare structures
    static struct S1
    {
        void[] arr;
        MyInt[2][2] static_arr;
    }

    static struct S2
    {
        int a, b, c;

        union
        {
            char x;
            int y;
        }

        S1 subs;
    }

    // prepare data
    void[] buffer = new void[100];
    auto tested = cast(S2*) buffer.ptr;
    tested.subs.arr = (buffer.ptr + S2.sizeof)[0..2];

    enforceContiguous(*tested, buffer);

    tested.subs.arr = new void[2];
    testThrown!(Exception)(enforceContiguous(*tested, buffer));

    static struct S4
    {
        Const!(char[])[] str = ["Hello", "World"];
    }

    auto tested2 = cast(S4*) memset(buffer.ptr, 0, buffer.length);

    *tested2 = S4.init;
    test!("==")(tested2.str.length, 2);
    testThrown!(Exception)(enforceContiguous(*tested2, buffer));
}

unittest
{
    static struct S { int x; }
    Contiguous!(S) s;
    s.data = new void[42];
    s.data.length = 0;
    test!("==")(s.ptr(), null);
}
