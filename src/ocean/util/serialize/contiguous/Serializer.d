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

import ocean.util.serialize.model.Traits;
import ocean.util.serialize.contiguous.Contiguous;

import ocean.core.Traits : ContainsDynamicArray;

import ocean.core.Test;

debug(SerializationTrace) import ocean.io.Stdout_tango;

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

    alias typeof(*this) This;

    /**************************************************************************

        NB! This will suppress any compilation errors, comment out during
        development and enable only when commiting.

    **************************************************************************/

    static assert (isSerializer!(This));

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

        S* s_dumped = cast (S*) data[0 .. S.sizeof];

        *s_dumped = src;

        static if (ContainsDynamicArray!(S))
        {
            void[] remaining = This.dumpAllArrays(*s_dumped, data[S.sizeof .. $]);

            return data[0 .. $ - remaining.length];
        }
        else
        {
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
            Stdout.formatln("< countRequiredSize!({})(<input>) : {}", S.stringof, size);
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
                S.stringof, size);
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
                alias typeof (field) T;

                static if (is (T == struct))
                {
                    // Recurse into struct field.

                    len += This.countAllArraySize(field);
                }
                else static if (is (T Base : Base[]))
                {
                    static if (is (Base[] == T))
                    {
                        // Dump dynamic array.

                        len += This.countArraySize(field);
                    }
                    else static if (ContainsDynamicArray!(Base))
                    {
                        // Recurse into static array elements which contain a
                        // dynamic array.

                        foreach (element; s.tupleof[i])
                        {
                            len += This.countArraySize(field);
                        }
                    }
                }
                else static if (is (T == union))
                {
                    static assert (!ContainsDynamicArray!(T),
                                   T.stringof ~ " " ~ s.tupleof[i].stringof ~
                                   " - unions containing dynamic arrays are is not "
                                   "allowed, sorry");
                }
            }
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

    private static size_t countArraySize ( T ) ( T[] array )
    out (size)
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("< countArraySize!({})({}) : {}",
                T.stringof, array.ptr, size);
        }
    }
    body
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("> countArraySize!({})({})", T.stringof, array.ptr);
        }

        size_t len = size_t.sizeof;

        static if (is (T Base == Base[]))
        {
            // array is a dynamic array of dynamic arrays.

            foreach (element; array)
            {
                len += This.countArraySize(element);
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
                    len += This.countElementSize(element);
                }
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

    private static size_t countElementSize ( T ) ( T element )
    out (size)
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("< countElementSize!({})(<element>) : {}",
                T.stringof, size);
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
        else static if (is (T Base : Base[]))
        {
            static assert (!is (Base[] == T),
                           "expected a static, not a dynamic array of " ~ T.stringof);

            size_t len = 0;

            foreach (subelement; element)
            {
                len += This.countElementSize(subelement);
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
            Stdout.formatln("< dumpAllArrays!({})({}, {}) : {}",
                S.stringof, &s, data.ptr, result.ptr);
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
            foreach (i, T; typeof (s.tupleof))
            {
                static if (is (T == struct))
                {
                    // Recurse into struct field.

                    data = This.dumpAllArrays(s.tupleof[i], data);
                }
                else static if (is (T Base : Base[]))
                {
                    static if (is (Base[] == T))
                    {
                        // Dump dynamic array.

                        data = This.dumpArray(s.tupleof[i], data);

                        s.tupleof[i] = null;
                    }
                    else static if (ContainsDynamicArray!(Base))
                    {
                        // Recurse into static array elements which contain a
                        // dynamic array.

                        debug (SerializationTrace)
                        {
                            Stdout.formatln("  iterating static array of length {}",
                                s.tupleof[i].length);
                        }

                        data = This.dumpStaticArray(s.tupleof[i][], data);
                    }
                }
                else static if (is (T == union))
                {
                    static assert (
                        !ContainsDynamicArrays!(T),
                        T.stringof ~ " " ~ s.tupleof[i].stringof ~
                            " - unions containing dynamic arrays are is not " ~
                            "allowed, sorry"
                    );
                }
            }
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

    private static void[] dumpArray ( T ) ( T[] array, void[] data )
    out (result)
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("< dumpArray!({})({}, {}) : {}",
                T.stringof, array.ptr, data.ptr, result.ptr);
        }
    }
    body
    {
        debug (SerializationTrace)
        {
            Stdout.formatln("> dumpArray!({})({}, {})",
                T.stringof, array.ptr, data.ptr);
        }

        *cast (size_t*) data[0 .. size_t.sizeof] = array.length;

        data = data[size_t.sizeof .. $];

        if (array.length)
        {
            static if (is (T Base == Base[]))
            {
                foreach (ref element; array)
                {
                    // array is a dynamic array of dynamic arrays:
                    // Recurse into subarrays.

                    data = This.dumpArray(element, data);
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

                    data = This.dumpArrayElements(dst, data);
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

    private static void[] dumpStaticArray ( T ) ( T[] array, void[] data )
    {
        foreach (ref element; array)
        {
            static if (is(T Base: Base[]))
            {
                // element is a static or dynamic array
                static if (is(T == Base[]))
                {
                    // element is a dynamic array
                    data = This.dumpArray(element, data);
                }
                else
                {
                    // element is a static array
                    data = This.dumpStaticArray(element, data);
                }
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

                data = This.dumpAllArrays(element, data);
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

    private static void[] dumpArrayElements ( T ) ( T[] array, void[] data )
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
            foreach (ref element; array)
            {
                data = This.dumpAllArrays(element, data);
                This.resetReferences(element);
            }
        }
        else static if (is (T Base : Base[]))
        {
            static assert (!is (Base[] == T),
               "expected static, not dynamic array of " ~ T.stringof);

            debug (SerializationTrace)
            {
                Stdout.formatln("  dumping static array of type {}", T.stringof);
            }

            foreach (ref element; array)
            {
                data = This.dumpElement(element, data);
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

        foreach (i, T; typeof (s.tupleof))
        {
            static if (is (T == struct))
            {
                // Recurse into field of struct type if it contains
                // a dynamic array.
                static if (ContainsDynamicArray!(T))
                {
                    This.resetReferences(s.tupleof[i]);
                }
            }
            else static if (is (T Base : Base[]))
            {
                static if (is (Base[] == T))
                {
                    // Reset field of dynamic array type.

                    s.tupleof[i] = null;
                }
                else static if (ContainsDynamicArray!(Base))
                {
                    // Field of static array that contains a dynamic array:
                    // Recurse into field array elements.

                    resetArrayReferences(s.tupleof[i]);
                }
            }
            else static if (is (T == union))
            {
                static assert (
                    !ContainsDynamicArrays!(T),
                    T.stringof ~ " " ~ s.tupleof[i].stringof ~
                        " - unions containing dynamic arrays are is not " ~
                        "allowed, sorry"
                );
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
        static assert (ContainsDynamicArray!(T), "nothing to do for " ~ S.stringof);

        debug (SerializationTrace)
        {
            Stdout.formatln("> resetArrayReferences!({})({})", T.stringof, array.ptr);
        }

        static if (is (T Base : Base[]))
        {
            static if (is (Base[] == T))
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
