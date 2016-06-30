/******************************************************************************

    Collection of common utilities built on top of (de)serializer

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.serialize.contiguous.Util;

/******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.serialize.contiguous.Contiguous,
       ocean.util.serialize.contiguous.Serializer,
       ocean.util.serialize.contiguous.Deserializer;

import ocean.core.Test;

/*******************************************************************************

    Copies struct data to other chunk and adjusts all internal pointers
    to reference new buffer.

    Params:
        src = source struct (must be already contiguous)
        dst = target struct chunk to copy data to. Will grow if current
            length is smaller than src.data.length

    Returns:
        `dst` by value

    Throws:
        DeserializationException if src is not well-formed

/******************************************************************************/

public Contiguous!(S) copy(S) ( Contiguous!(S) src, ref Contiguous!(S) dst )
{
    Deserializer.deserialize!(S)(src.data, dst);
    return dst;
}

/*******************************************************************************

    Deep copies any struct to its contiguous representation. Effectively does
    serialization and deserialization in one go.

    Params:
        src = any struct instance
        dst = contiguous struct to be filled with same values as src

    Returns:
        `dst` by value

*******************************************************************************/

public Contiguous!(S) copy(S) ( ref S src, ref Contiguous!(S) dst )
{
    Serializer.serialize(src, dst.data);
    dst = Deserializer.deserialize!(S)(dst.data);
    return dst;
}

unittest
{
    struct Test
    {
        int[] arr;
    }

    Test t; t.arr = [ 1, 2, 3 ];

    Contiguous!(Test) one, two;

    copy(t, one);

    test!("==")(one.ptr.arr, t.arr);
    one.enforceIntegrity();

    copy(one, two);

    test!("==")(two.ptr.arr, t.arr);
    two.enforceIntegrity();
}

/*******************************************************************************

    Simple wrapper on top of (de)serializer which allows to deep copy
    a given struct by storing all indirections in contiguous buffer. Most
    commonly used in tests - performance-critical applications should store
    `Contiguous!(S)` instead and copy it as it is much faster.

    Params:
        dst = resizable buffer used to serialize `src`
        src = struct to copy

    Returns:
        new struct instance stored in `dst` cast to S

*******************************************************************************/

public S deepCopy (S) (  ref S src, ref void[] dst )
{
    Serializer.serialize(src, dst);
    return *Deserializer.deserialize!(S)(dst).ptr;
}

/*******************************************************************************

    Ditto, but allocates new buffer each time called

*******************************************************************************/

public S deepCopy (S) ( ref S src )
{
    void[] empty;
    return deepCopy(src, empty);
}

///
unittest
{
    struct Test
    {
        int[] arr;
    }

    auto s1 = Test([ 1, 2, 3 ]);
    auto s2 = deepCopy(s1);

    test!("==")(s1.arr, s2.arr);
    test!("!is")(s1.arr.ptr, s2.arr.ptr);
}
