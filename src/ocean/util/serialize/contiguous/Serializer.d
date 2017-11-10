/******************************************************************************

    Home for binary contiguous Serializer. Check the `Serializer` struct
    documentation for more details.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.serialize.contiguous.Serializer;

/******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.util.serialize.contiguous.Contiguous;

import ocean.core.Traits : ContainsDynamicArray;

import ocean.core.Test;

debug(SerializationTrace) import ocean.io.Stdout;

/******************************************************************************

    Binary serializer that generates contiguous structs. It recursively
    iterates over struct fields copying any array contents into the same
    byte buffer and clear the array pointer field. Latter is done to avoid
    accidental access via dangling pointer once that data is read from external
    source.

    Arrays of arrays are stored with small optimization, keeping only length
    part of the slice (as .ptr will be always null)

    Deserializer later does similar iteration updating all internal pointers.

*******************************************************************************/

struct Serializer
{
    /**************************************************************************

        Convenience shortcut

    **************************************************************************/

    alias typeof(*(&this)) This;

    /***************************************************************************

        Serializes the data in s

        Params:
            src = struct to serialize
            dst = buffer to write to. It is only extended if needed and
                never shrunk

        Template_Params:
            S = type of the struct to dump

    ***************************************************************************/

    public static void[] serialize ( S, D ) ( ref S src, ref D[] dst )
    out (data)
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("< serialize!({})(<src>, {}) : {}", S.stringof,
                dst.ptr, data.ptr);
        }
    }
    body
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("> serialize!({})(<src>, {})", S.stringof, dst.ptr);
        }

        static assert (D.sizeof == 1, "dst buffer can't be interpreted as void[]");
        void[]* dst_untyped = cast (void[]*) &dst;
        auto data = This.resize(*dst_untyped, This.countRequiredSize(src));

        data[0 .. S.sizeof] = (cast(void*) &src)[0 .. S.sizeof];
        auto s_root = cast(Unqual!(S)*) data.ptr;

        static if (ContainsDynamicArray!(S))
        {
            void[] remaining = This.dumpAllArrays(*s_root, data[S.sizeof .. $]);

            return data[0 .. $ - remaining.length];
        }
        else
        {
            foreach (i, T; typeof(S.tupleof))
                alias ensureValueTypeMember!(S, i) evt;

            return data[0 .. src.sizeof];
        }
    }

    /***************************************************************************

        In-place serialization that takes advantage of the fact Contiguous
        instances already have required data layout. All arrays within
        `src` will be reset to null (and their length to 0) making their data
        unreachable from original struct. This is done to minimize risk of
        dangling array pointers.

        Params:
            src = contiguous struct instance to serialize

        Returns:
            slice of internal `src` byte array after setting all array pointers
            to null

    ***************************************************************************/

    public static void[] serialize ( S ) ( ref Contiguous!(S) src )
    {
        This.resetReferences(*src.ptr);
        return src.data[];
    }

    /***************************************************************************

        Return the serialized length of input

        Template_Params:
            type of the struct

        Params:
            input = struct to get the serialized length of

        Returns:
            serialized length of input

    ***************************************************************************/

    public static size_t countRequiredSize ( S ) ( ref S input )
    out (size)
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("< countRequiredSize!({})(<input>) : {}", S.stringof, cast(size_t)size);
        }
    }
    body
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("> countRequiredSize!({})(<input>)", S.stringof);
        }

        static if (ContainsDynamicArray!(S))
        {
            return input.sizeof + This.countAllArraySize(input);
        }
        else
        {
            foreach (i, T; typeof(S.tupleof))
                alias ensureValueTypeMember!(S, i) evt;

            return input.sizeof;
        }
    }

    /***************************************************************************

        Resizes the passed buffer reference in case it is not large enough to
        store len bytes. If resized, new memory is allocated as ubyte[] chunk so
        that GC ignores it.

        Params:
            buffer = buffer to resize
            len    = length to resize to

        Returns:
            slice to the potentially resized buffer

    ***************************************************************************/

    private static void[] resize ( ref void[] buffer, size_t len )
    out (buffer_out)
    {
        assert (buffer_out.ptr is buffer.ptr);
        assert (buffer_out.length == buffer.length);

        debug (SerializationTrace)
        {
            Stdout.formatln("< resize({}, {}) : ", buffer.ptr, len,
                buffer_out.ptr);
        }
    }
    body
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("> resize({}, {})", buffer.ptr, len);
        }

        if (len > buffer.length)
        {
            if (buffer is null)
            {
                buffer = new ubyte[len];
            }
            else
            {
                // Since len > buffer.length, we defensively enable stomping
                // before in case it hasn't been done by the caller
                enableStomping(buffer);
                buffer.length = len;
                enableStomping(buffer);
            }
        }

        return buffer;
    }

    /**************************************************************************

        Calculates the length of ALL serialized dynamic arrays in s.

        Params:
            s = S instance to calculate the length of the serialized dynamic
                arrays for

        Returns:
            the length of the serialized dynamic arrays of s.

     **************************************************************************/

    private static size_t countAllArraySize ( S ) ( S s )
    out (size)
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("< countAllArraySize!({})(<s>) : {}",
                S.stringof, cast(size_t)size);
        }
    }
    body
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("> countAllArraySize!({})(<s>)", S.stringof);
        }

        size_t len = 0;

        static if (ContainsDynamicArray!(S))
        {
            foreach (i, ref field; s.tupleof)
            {
                alias typeof (field) Field;

                static if (is (Field == struct))
                {
                    // Recurse into struct field.
                    static if (ContainsDynamicArray!(Field))
                    {
                        len += This.countAllArraySize(field);
                    }
                }
                else static if (is (Field Element == Element[]))
                {
                    // Dump dynamic array.

                    len += This.countArraySize!(S, i)(field);
                }
                else static if (is (Field Element : Element[]))
                {
                    // Static array

                    static if (ContainsDynamicArray!(Element))
                    {
                        // Recurse into static array elements which contain a
                        // dynamic array.
                        len += This.countElementSize!(S, i)(field);
                    }
                    else
                    {
                        alias ensureValueTypeMember!(S, i, Element) evt;
                    }
                }
                else
                {
                    alias ensureValueTypeMember!(S, i) evt;
                }
            }
        }
        else
        {
            foreach (i, T; typeof(S.tupleof))
                alias ensureValueTypeMember!(S, i) evt;
        }

        return len;
    }

    /**************************************************************************

        Calculates the length of the serialized dynamic arrays in all elements
        of array.

        Params:
            array = array to calculate the length of the serialized dynamic
                    arrays in all elements

        Returns:
             the length of the serialized dynamic arrays in all elements of
             array.

    ***************************************************************************/

    private static size_t countArraySize ( S, size_t i, T ) ( T[] array )
    out (size)
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("< countArraySize!({})({} @{}) : {}",
                T.stringof, array.length, array.ptr, cast(size_t)size);
        }
    }
    body
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("> countArraySize!({})({} @{})", T.stringof, array.length, array.ptr);
        }

        size_t len = size_t.sizeof;

        static if (is (Unqual!(T) Element == Element[]))
        {
            // array is a dynamic array of dynamic arrays.

            foreach (element; array)
            {
                len += This.countArraySize!(S, i)(element);
            }
        }
        else
        {
            // array is a dynamic array of values.

            len += array.length * T.sizeof;

            static if (ContainsDynamicArray!(T))
            {
                foreach (element; array)
                {
                    len += This.countElementSize!(S, i)(element);
                }
            }
            else
            {
                alias ensureValueTypeMember!(S, i, T) evt;
            }
        }

        return len;
    }

    /**************************************************************************

        Calculates the length of the serialized dynamic arrays in element.

        Params:
            element = element to calculate the length of the serialized dynamic
                      arrays

        Returns:
             the length of the serialized dynamic arrays in element.

    ***************************************************************************/

    private static size_t countElementSize ( S, size_t i, T ) ( T element )
    out (size)
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("< countElementSize!({})(<element>) : {}",
                T.stringof, cast(size_t)size);
        }
    }
    body
    {
        static assert (ContainsDynamicArray!(T), T.stringof ~
                       " contains no dynamic array - nothing to do");

        debug (SerializationTrace)
        {
            Stdout.formatln("> countElementSize!({})(<element>)", T.stringof);
        }

        static if (is (T == struct))
        {
            static if (ContainsDynamicArray!(T))
            {
                return This.countAllArraySize(element);
            }
        }
        else static if (is (T Element : Element[]))
        {
            static assert (!is (Element[] == T),
                           "expected a static, not a dynamic array of " ~ T.stringof);

            size_t len = 0;

            foreach (subelement; element)
            {
                static if (is(Unqual!(Element) Sub == Sub[]))
                {
                    // subelement is a dynamic array
                    len += This.countArraySize!(S, i)(subelement);
                }
                else
                {
                    // subelement is a value containing dynamic arrays
                    len += This.countElementSize!(S, i)(subelement);
                }
            }

            return len;
        }
        else
        {
            static assert (false,
                           "struct or static array expected, not " ~ T.stringof);
        }
    }

    /**************************************************************************

        Serializes the dynamic array data in s and sets the dynamic arrays to
        null.

        Params:
            s    = instance of S to serialize and reset the dynamic arrays
            data = destination buffer

        Returns:
            the tail of data, starting with the next after the last byte that
            was populated.

    ***************************************************************************/

    private static void[] dumpAllArrays ( S ) ( ref S s, void[] data )
    out (result)
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("< dumpAllArrays!({})({}, {}) : {} @{}",
                S.stringof, &s, data.ptr, result.length, result.ptr);
        }
    }
    body
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("> dumpAllArrays!({})({}, {})",
                S.stringof, &s, data.ptr);
        }

        static if (ContainsDynamicArray!(S))
        {
            foreach (i, ref field; s.tupleof)
            {
                alias typeof(field) Field;

                static if (is (Field == struct))
                {
                    // Recurse into struct field.

                    auto ptr = cast(Unqual!(Field)*) &field;
                    data = This.dumpAllArrays(*ptr, data);
                }
                else static if (is (Field Element == Element[]))
                {
                    // Dump dynamic array.

                    data = This.dumpArray!(S, i)(field, data);
                    *(cast(Unqual!(Field)*)&field) = null;
                }
                else static if (is (Field Element : Element[]))
                {
                    // Dump static array

                    static if (ContainsDynamicArray!(Element))
                    {
                        // Recurse into static array elements which contain a
                        // dynamic array.

                        debug (SerializationTrace)
                        {
                            Stdout.formatln("  iterating static array of length {}",
                                field.length);
                        }

                        data = This.dumpStaticArray!(S, i)(field[], data);
                    }
                    else
                    {
                        // The field is a static array not containing dynamic
                        // arrays so the array elements should be values.
                        alias ensureValueTypeMember!(S, i, Element) evt;
                    }
                }
                else
                {
                    alias ensureValueTypeMember!(S, i) evt;
                }
            }
        }
        else
        {
            foreach (i, T; typeof(S.tupleof))
                alias ensureValueTypeMember!(S, i) evt;
        }

        return data;
    }

    /**************************************************************************

        Serializes array and the dynamic arrays in all of its elements and sets
        the dynamic arrays, including array itself, to null.

        Params:
            array = this array and all dynamic subarrays will be serialized and
                    reset
            data  = destination buffer

        Returns:
            the tail of data, starting with the next after the last byte that
            was populated.

    ***************************************************************************/

    private static void[] dumpArray ( S, size_t i, T ) ( T[] array, void[] data )
    out (result)
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("< dumpArray!({})({} @{}, {} @{}) : {} @{}",
                T.stringof, array.length, array.ptr, data.length, data.ptr, result.length, result.ptr);
        }
    }
    body
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("> dumpArray!({})({} @{}, {} @{})",
                T.stringof, array.length, array.ptr, data.length, data.ptr);
        }

        *cast (size_t*) data[0 .. size_t.sizeof] = array.length;

        data = data[size_t.sizeof .. $];

        if (array.length)
        {
            static if (is (Unqual!(T) Element == Element[]))
            {
                foreach (ref element; array)
                {
                    // array is a dynamic array of dynamic arrays:
                    // Recurse into subarrays.

                    data = This.dumpArray!(S, i)(element, data);
                }
            }
            else
            {
                // array is a dynamic array of values: Dump array.

                size_t n = array.length * T.sizeof;

                debug (SerializationTrace)
                {
                    Stdout.formatln("  dumping dynamic array ({}), {} bytes",
                        (T[]).stringof, n);
                }

                auto dst = (cast (Unqual!(T)[]) (data[0 .. n]));

                data = data[n .. $];

                dst[] = array[];

                static if (ContainsDynamicArray!(T))
                {
                    // array is an array of structs or static arrays which
                    // contain dynamic arrays: Recurse into array elements.

                    data = This.dumpArrayElements!(S, i)(dst, data);
                }
                else
                {
                    alias ensureValueTypeMember!(S, i, T) evt;
                }
            }
        }

        return data;
    }

    /**************************************************************************

        Serializes the static array, also handles static arrays of static
        arrays and similar recursive cases.

        Template_Params:
            T = array element type

        Params:
            array = slice of static array to serialize
            data = destination buffer

        Returns:
            the tail of data, starting with the next after the last byte that
            was populated.

    **************************************************************************/

    private static void[] dumpStaticArray ( S, size_t i, T ) ( T[] array, void[] data )
    {
        foreach (ref element; array)
        {
            alias Unqual!(typeof(element)) U;

            static if (is(T Element == Element[]))
            {
                // element is a dynamic array
                data = This.dumpArray!(S, i)(element, data);
                *(cast(U*)&element) = null;
            }
            else static if (is(T Element : Element[]))
            {
                // element is a static array
                data = This.dumpStaticArray!(S, i)(element, data);
            }
            else
            {
                // T is expected to contain indirections and is not
                // an array so it must be a struct.
                static assert (
                    is(T == struct),
                    "static array elements expected to have indirections which " ~
                        T.stringof ~ " doesn't have"
                );

                auto ptr = cast(U*) &element;
                data = This.dumpAllArrays(*ptr, data);
            }
        }

        return data;
    }

    /**************************************************************************

        Serializes the dynamic arrays in all elements of array and sets them to
        null.

        Params:
            array = the dynamic arrays of all members of this array will be
                    serialized and reset
            data  = destination buffer

        Returns:
            the tail of data, starting with the next after the last byte that
            was populated.

    ***************************************************************************/

    private static void[] dumpArrayElements ( S, size_t i, T ) ( T[] array,
        void[] data )
    out (result)
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("< dumpArrayElements!({})({}, {}) : {}",
                T.stringof, array.ptr, data.ptr, result.ptr);
        }
    }
    body
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("> dumpArrayElements!({})({}, {})",
                T.stringof, array.ptr, data.ptr);
        }

        // array is a dynamic array of structs or static arrays which
        // contain dynamic arrays.

        static assert (ContainsDynamicArray!(T), "nothing to do for " ~ T.stringof);

        static if (is (T == struct))
        {
            foreach (ref element; cast(Unqual!(T)[])array)
            {
                data = This.dumpAllArrays(element, data);
                This.resetReferences(element);
            }
        }
        else static if (is (T Element : Element[]))
        {
            static assert (!is (Element[] == Unqual!(T)),
               "expected static, not dynamic array of " ~ T.stringof);

            debug (SerializationTrace)
            {
                Stdout.formatln("  dumping static array of type {}", T.stringof);
            }

            foreach (ref element; array)
            {
                data = This.dumpStaticArray!(S, i)(element[], data);
                This.resetArrayReferences(element);
            }
        }
        else
        {
            static assert (false);
        }

        return data;
    }

    /**************************************************************************

        Resets all dynamic arrays in s to null.

        Params:
            s = struct instance to resets all dynamic arrays

        Returns:
            a pointer to s

    ***************************************************************************/

    private static S* resetReferences ( S ) ( ref S s )
    out (result)
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("< resetReferences!({})({}) : {}",
                S.stringof, &s, result);
        }
    }
    body
    {
        static assert (is (S == struct), "struct expected, not " ~ S.stringof);
        static assert (ContainsDynamicArray!(S), "nothing to do for " ~ S.stringof);

        debug (SerializationTrace)
        {
            Stdout.formatln("> resetReferences!({})({})", S.stringof, &s);
        }

        foreach (i, ref field; s.tupleof)
        {
            alias typeof(field) Field;

            static if (is (Field == struct))
            {
                // Recurse into field of struct type if it contains
                // a dynamic array.
                static if (ContainsDynamicArray!(Field))
                {
                    This.resetReferences(field);
                }
            }
            else static if (is (Unqual!(Field) Element == Element[]))
            {
                // Reset field of dynamic array type.

                field = null;
            }
            else static if (is (Field Element : Element[]))
            {
                // Static array

                static if (ContainsDynamicArray!(Element))
                {
                    // Field of static array that contains a dynamic array:
                    // Recurse into field array elements.

                    resetArrayReferences(cast(Unqual!(Element)[])field);
                }
            }
            else
            {
                alias ensureValueTypeMember!(S, i) evt;
            }
        }

        return &s;
    }

    /**************************************************************************

        Resets all dynamic arrays in all elements of array to null.

        Params:
            array = all dynamic arrays in all elements of this array will be
                    reset to to null.

        Returns:
            array

    ***************************************************************************/

    static T[] resetArrayReferences ( T ) ( T[] array )
    out (arr)
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("< resetArrayReferences!({})({}) : {}",
                T.stringof, array.ptr, arr.ptr);
        }
    }
    body
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("> resetArrayReferences!({})({})", T.stringof, array.ptr);
        }

        static if (is (T Element : Element[]))
        {
            static if (is (Element[] == T))
            {
                // Reset elements of dynamic array type.

                array[] = null;
            }
            else foreach (ref element; array)
            {
                // Recurse into static array elements.

                This.resetArrayReferences(element);
            }
        }
        else foreach (ref element; array)
        {
            static assert (is (T == struct), "struct expected, not " ~ T.stringof);

            // Recurse into struct elements.

            This.resetReferences(element);
        }

        return array;
    }
}

unittest
{
    struct Dummy
    {
        int a, b;
        int[] c;
        char[][] d;
    }

    Dummy d; d.a = 42; d.b = 43;
    d.c = [1, 2, 3];
    d.d = ["aaa".dup, "bbb".dup, "ccc".dup];

    void[] target;
    Serializer.serialize(d, target);
    auto ptr = cast(Dummy*) target.ptr;

    test!("==")(ptr.a, 42);
    test!("==")(ptr.b, 43);
    test!("is")(ptr.c.ptr, null);
}

// non-void[] dst
unittest
{
    struct Dummy
    {
        int a, b;
    }

    Dummy d; d.a = 1; d.b = 3;

    ubyte[] target;
    Serializer.serialize(d, target);
    auto ptr = cast(Dummy*) target.ptr;

    test!("==")(ptr.a, 1);
    test!("==")(ptr.b, 3);
}

// Allocation test
unittest
{
    static struct Dummy
    {
        size_t v;
    }

    ubyte[] buffer;
    Dummy d;

    Serializer.serialize(d, buffer);
    test!("==")(buffer.length, d.sizeof);
    buffer.length = 0;
    testNoAlloc(Serializer.serialize(d, buffer));
}
