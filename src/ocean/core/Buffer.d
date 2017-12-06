/*******************************************************************************

    Utility for manipulation of reusable mutable array buffers.

    Notes:
    * Because of a DMD1 bug, declaring Buffer!(Buffer!(T)) is not possible and
      will result in a compile-time error complaining about recursive template
      instantiation.
    * Buffers of void of any dimension greater than one are disallowed (i.e.
      Buffer!(void) is allowed; Buffer!(void[]), Buffer!(void[][]), etc are
      not). For > 1d arrays, you should use buffers of ubyte instead. The reason
      for this limitation is that any array type can be implicitly cast to
      void[], leading to internal ambiguities in the code of Buffer. (A fix for
      this problem may possible, but would add a lot of complexity to the code.)

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

import ocean.core.Traits;

import ocean.core.buffer.Void;
import ocean.core.buffer.WithIndirections;
import ocean.core.buffer.NoIndirections;

Buffer!(Unqual!(T)) createBuffer ( T ) ( T[] initial... )
{
    return Buffer!(Unqual!(T))(initial.dup);
}

struct Buffer ( T )
{
    static assert (
        !isArrayType!(T) || !is(BaseTypeOfArrays!(T) == void),
        "Buffer doesn't work as void[][] replacement, try use ubyte[][] instead"
    );

    /***************************************************************************

        Disable postblit constructor in D2 to prevent copying

    ***************************************************************************/

    version (D_Version2)
    {
        mixin(`
            @disable this(this);
            @disable void opAssign (Buffer!(T) other);
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
        (&this).length = 0;
    }

    /***************************************************************************

        Returns:
            stored data length

    ***************************************************************************/

    size_t length ( ) const
    {
        return (&this).data.length;
    }

    /***************************************************************************

        Resizes buffer and allows memory stomping

        Params:
            new_length = length to resize to

    ***************************************************************************/

    void length ( size_t new_length )
    {
        version (D_Version2)
            assumeSafeAppend((&this).data);
        (&this).data.length = new_length;
        version (D_Version2)
            assumeSafeAppend((&this).data);
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
            assumeSafeAppend((&this).data);
        auto old_length = (&this).data.length;
        (&this).data.length = new_length;
        (&this).data.length = old_length;
        version (D_Version2)
            assumeSafeAppend((&this).data);
    }

    /***************************************************************************

        Exposes owned data as an array slice

        Params:
            begin = start index, inclusive
            end = end index, exclusive

        Returns:
            requested slice fo stored data

    ***************************************************************************/

    Inout!(T[]) opSlice ( size_t begin, size_t end ) inout
    {
        return (&this).data[begin .. end];
    }

    /***************************************************************************

        Exposes owned data as an array slice

        Returns:
            requested slice fo stored data

    ***************************************************************************/

    Inout!(T[]) opSlice ( ) inout
    {
        return (&this).data[];
    }
}

unittest
{
    // test instantiation with various types

    {
        Buffer!(void) buffer;
    }

    {
        Buffer!(char) buffer;
    }

    {
        static struct S
        {
        }

        Buffer!(S) buffer;
    }

    {
        Buffer!(istring) buffer1;
        Buffer!(cstring) buffer2;
        Buffer!(mstring) buffer3;
    }

    {
        static class C
        {
        }

        Buffer!(C) buffer;
    }
}
