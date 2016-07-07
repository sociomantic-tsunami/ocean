/*******************************************************************************

    Utility for manipulation of reusable mutable array buffers.

    NB: because of DMD1 bug, declaring Buffer!(Buffer!(T)) is not possible and
    will result in compile-time error complaining about recursive template
    instantiation.

    Copyright:
        Copyright (c) 2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.Buffer;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.TypeConvert;
import ocean.core.Traits;
import ocean.core.Test;

import ocean.core.buffer.Void;
import ocean.core.buffer.WithIndirections;
import ocean.core.buffer.NoIndirections;

Buffer!(Unqual!(T)) createBuffer ( T ) ( T[] initial... )
{
    return Buffer!(Unqual!(T))(initial.dup);
}

struct Buffer ( T )
{
    /***************************************************************************

        Disable postblit constructor in D2 to prevent copying

    ***************************************************************************/

    version (D_Version2)
    {
        mixin(`
            @disable this(this);
        `);
    }

    /***************************************************************************

        Mixin appropriate API based on kind of element type requested

    ***************************************************************************/

    static if (is(T == void))
    {
        alias ubyte ElementType;
        mixin VoidBufferImpl Impl;
    }
    else static if (is(typeof({ T x; Const!(T) y; x = y; })))
    {
        alias T ElementType;
        mixin NoIndirectionsBufferImpl Impl;
    }
    else
    {
        alias T ElementType;
        mixin WithIndirectionsBufferImpl Impl;
    }

    /***************************************************************************

        Add opAssign from currently used implementation to main overload set
        so that it won't get shadowed by opAssign automatically generated
        from postblit.

    ***************************************************************************/

    alias Impl.opAssign opAssign;

    /***************************************************************************

        More readable alias for resetting buffer length to 0 while preserving
        capacity.

    ***************************************************************************/

    void reset ( )
    {
        this.length = 0;
    }

    ///
    unittest
    {
        static if (!is(ElementType == class))
        {
            Buffer!(T) buffer;
            buffer = [ some!(ElementType), some!(ElementType) ];
            buffer.reset();
            test!("==")(buffer[], (T[]).init);
            test!("!is")(buffer.data.ptr, null);
        }
    }

    /***************************************************************************

        Returns:
            stored data length

    ***************************************************************************/

    size_t length ( ) /* d1to2fix_inject: const */
    {
        return this.data.length;
    }

    ///
    unittest
    {
        static if (!is(ElementType == class))
        {
            Buffer!(T) buffer;
            buffer = [ some!(ElementType), some!(ElementType), some!(ElementType) ];
            test!("==")(buffer.length, 3);
        }
    }

    /***************************************************************************

        Resizes buffer and allows memory stomping

        Params:
            new_length = length to resize to

    ***************************************************************************/

    void length ( size_t new_length )
    {
        version (D_Version2)
            assumeSafeAppend(this.data);
        this.data.length = new_length;
        version (D_Version2)
            assumeSafeAppend(this.data);
    }

    ///
    unittest
    {
        static if (!is(ElementType == class))
        {
            Buffer!(T) buffer;
            buffer.length = 1;
            test!("==")(buffer.length, 1);
        }
    }

    /***************************************************************************

        Ensures buffer has enough capacity to hold specified length but does
        not modify effective length.

        Params:
            new_length = length to extend capacity to

    ***************************************************************************/

    void reserve ( size_t new_length )
    {
        version (D_Version2)
            assumeSafeAppend(this.data);
        auto old_length = this.data.length;
        this.data.length = new_length;
        this.data.length = old_length;
        version (D_Version2)
            assumeSafeAppend(this.data);
    }

    ///
    unittest
    {
        static if (!is(ElementType == class))
        {
            Buffer!(T) buffer;
            buffer.reserve(20);
            auto to_append = [ some!(ElementType), some!(ElementType) ];
            testNoAlloc({
                buffer ~= some!(ElementType);
                buffer ~= to_append;
            } ());
        }
    }

    /***************************************************************************

        Exposes owned data as an array slice

        Params:
            begin = start index, inclusive
            end = end index, exclusive

        Returns:
            requested slice fo stored data

    ***************************************************************************/

    Inout!(T[]) opSlice ( size_t begin, size_t end ) /* d1to2fix_inject: inout */
    {
        return this.data[begin .. end];
    }

    ///
    unittest
    {
        static if (!is(ElementType == class))
        {
            auto buffer = createBuffer([ some!(ElementType), some!(ElementType) ]);
            test!("==")(buffer[0 .. buffer.length],
                [ some!(ElementType), some!(ElementType) ]);
        }
    }

    /***************************************************************************

        Exposes owned data as an array slice

        Returns:
            requested slice fo stored data

    ***************************************************************************/

    Inout!(T[]) opSlice ( ) /* d1to2fix_inject: inout */
    {
        return this.data[];
    }

    ///
    unittest
    {
        static if (!is(ElementType == class))
        {
            auto buffer = createBuffer([ some!(ElementType), some!(ElementType) ]);
            test!("==")(buffer[],
                [ some!(ElementType), some!(ElementType) ]);
        }
    }
}

unittest
{
    Buffer!(void) buffer;
}

unittest
{
    Buffer!(char) buffer;
}

version (UnitTest)
{
    struct S
    {
        int x;
        char y;
    }
}

unittest
{
    Buffer!(S) buffer;
}

unittest
{
    Buffer!(istring) buffer1;
    Buffer!(cstring) buffer2;
    Buffer!(mstring) buffer3;
}

version (UnitTest)
{
    class C
    {
        int x;

        this ( int x )
        {
            this.x = x;
        }

        override int opCmp ( Object _rhs )
        {
            auto rhs = cast(C) _rhs;
            return this.x < rhs.x ? 1
                : this.x > rhs.x ? -1 : 0;
        }

        override equals_t opEquals ( Object rhs )
        {
            return this.opCmp(rhs) == 0;
        }
    }
}

/******************************************************************************

    Creates valid comparable value of generic type T.

    Useful when writing templated test cases to create initial data set that
    is more likely to pass comparison checks than plain T.init

    For classes tries using either default constructor or one which accepts
    same arguments as class fields.

    Params:
        T = type to create value of

    Returns:
        some value of T

******************************************************************************/

version (UnitTest)
private T some ( T ) ( )
{
    static if (isFloatingPointType!(T))
        return 42.0;
    else static if (isIntegerType!(T))
        return 42;
    else static if (is(T == class))
    {
        static if (is(typeof(new T())))
            return new T();
        else static if (is(typeof(new T(T.init.tupleof))))
        {
            typeof(T.init.tupleof) pseudoargs;
            foreach (ref arg; pseudoargs)
                arg = some!(typeof(arg));
            return new T(pseudoargs);
        }
        else
            static assert (false, "Class without supported constructor declaration");
    }
    else
        return T.init;
}

///
unittest
{
    assert (some!(int) == 42);
    assert (some!(double) == 42.0);

    static class C1
    {
        int x;
        this ( ) { this.x = 42; }
    }
    assert (some!(C1).x == 42);

    static class C2
    {
        int x;
        this ( int x ) { this.x = x; }
    }
    assert (some!(C2).x == 42);
}
