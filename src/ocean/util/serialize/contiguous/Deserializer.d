/******************************************************************************

    Home for binary contiguous Deserializer and utilities that use it. Check
    documentation of `Deserializer` for more details.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

******************************************************************************/

module ocean.util.serialize.contiguous.Deserializer;


import ocean.meta.types.Qualifiers;
import ocean.core.Verify;

import ocean.util.serialize.contiguous.Contiguous;

import ocean.core.Exception;
import ocean.core.Enforce;
import ocean.core.Buffer;
import ocean.meta.traits.Indirections;

debug (DeserializationTrace) import ocean.io.Stdout;

version (unittest) import ocean.core.Test;

/*******************************************************************************

    Indicates a problem during deserialization process, most often some sort
    of data corruption

*******************************************************************************/

class DeserializationException : Exception
{
    mixin ReusableExceptionImplementation!();

    /**********************************************************************

        Ensures length `len` does not exceed hard size limit `max`

        Params:
            S   = type of the struct which is currently loaded
            len  = length of a dynamic array to deserialize
            max  = allowed maximum dynamic array length
            file = file where size limit is enforced
            line = line where size limit is enforced

        Throws:
            this instance if len is not at most max.

    ***********************************************************************/

    void enforceSizeLimit ( S ) ( size_t len, size_t max,
        istring file = __FILE__, int line = __LINE__ )
    {
        if (len > max)
        {
            throw this
                .set("", file, line)
                .fmtAppend(
                    "Error deserializing '{}' : length {} exceeds limit {}",
                    S.stringof,
                    len,
                    max
                );
        }
    }

    /**********************************************************************

        Throws this instance if len is not at lest required.

        Params:
            S = type of the struct that is currently loaded
            len      = provided number of data bytes
            required = required number of data bytes
            file = file where size limit is enforced
            line = line where size limit is enforced

        Throws:
            this instance if len is not at most max.

    ***********************************************************************/

    void enforceInputSize ( S ) ( size_t len, size_t required,
        istring file = __FILE__, int line = __LINE__ )
    {
        if (len < required)
        {
            throw this
                .set("", file, line)
                .fmtAppend(
                    "Error deserializing '{}' : input data length {} < required {}",
                    S.stringof,
                    len,
                    required
                );
        }
    }

    unittest
    {
        struct S { int i; }

        auto e = new DeserializationException();
        try
        {
            e.enforceSizeLimit!(S)(1,2);
            e.enforceSizeLimit!(S)(2,2);
            e.enforceSizeLimit!(S)(3,2);
            assert(false);
        }
        catch ( DeserializationException e )
        {
            test(e.message() == "Error deserializing 'S' : length 3 exceeds limit 2");
        }
    }
}

/*******************************************************************************

    Binary deserializer that operates on Contiguous structs

    It operates on data buffers generated by calling matching Serializer or ones
    with an identicaly binary layout. Deserialization process is relatively
    simple and requires iteration over the struct and updating array fields
    to point to internal buffer slices.

    The contents of dynamic arrays are stored in the buffer with the array
    length prepended. For dynamic arrays of dynamic arrays that means that only
    one single length field gets stored for each top-level array.
    When such an array is encountered the Deserializer needs to extend the buffer
    and put the expanded array slice (with all ppointers restored) to the end.
    This process is called "array branching".

    All deserialization methods that return a struct instance or a pointer
    use in fact one of the argument data buffers as backing memory storage.
    Modifying those directly will invalidate/corrupt your struct pointer.

    Deserialized structures can be written to, as well as any referenced
    arrays / structures. However, resizing arrays (i.e. appending) will cause
    the buffer to be reallocated, causing the struct to no longer be contiguous.
    As contiguity invariant is disabled by default that may result in undefined
    behaviour.

    For copying structures obtained via deserialization you must use
    the `copy` function defined above in this module.

    Example:
    ---
    struct Test { int a; int[] b; }

    // in-place
    void[] input = getFromExternalSource();
    Contiguous!(Test) s1 = Deserializer.deserialize(input);
    assert(s1.ptr is input.ptr);

    // don't modify original source
    Contiguous!(Test) target;
    Contiguous!(Test) s2 = Deserializer.deserialize(input, target);
    assert(s2.ptr  is target.ptr);
    assert(s2.ptr !is input.ptr);
    ---

*******************************************************************************/

struct Deserializer
{
    /**************************************************************************

        Convenience shortcut

    **************************************************************************/

    alias typeof(this) This;

    /***************************************************************************

        Maximum allowed dynamic array length.
        If any dynamic array is longer than this value, a DeserializationException
        is thrown.

    ***************************************************************************/

    public enum max_length = size_t.max;

    /***************************************************************************

        Reused Exception instance

    ***************************************************************************/

    private static DeserializationException e;

    /**************************************************************************

        Type alias definition

     **************************************************************************/

    alias void[] delegate ( size_t len ) GetBufferDg;

    /**************************************************************************

        Initialization of static member fields

    ***************************************************************************/

    static this()
    {
        This.e = new DeserializationException();
    }

    /***************************************************************************

        Deserializes `src` in-place. If array branching is needed, length of
        src will be increased to be able to store those.

        Params:
            S = struct type expected
            src = data buffer previously created by Serializer

        Returns:
            src wrapped in Contiguous, ready to use data. Must not outlive
            src origin.

    ***************************************************************************/

    public static Contiguous!(S) deserialize ( S ) ( ref Buffer!(void) src )
    out (_s)
    {
        auto s = cast(Contiguous!(S)) _s;

        assert (s.data.ptr is src[].ptr);

        debug (DeserializationTrace)
        {
            Stdout.formatln("< deserialize!({})({}) : {}", S.stringof,
                src[].ptr, s.ptr);
        }
    }
    do
    {
        debug (DeserializationTrace)
        {
            Stdout.formatln("> deserialize!({})({})", S.stringof, src[].ptr);
            nesting = 0;
            scope (exit) nesting = 0;
        }
        size_t slices_len = 0,
               data_len   = This.countRequiredSize!(S)(src[], slices_len);

        debug (DeserializationTrace)
            Stdout.formatln("  data_len = {}, slices_len = {}", data_len, slices_len);

        size_t total_length = data_len + slices_len;

        if (src.length < total_length)
            src.length = total_length;

        verify(src.length >= data_len);

        This.handleBranching!(S)(
            src[0 .. data_len],
            src[data_len .. total_length]
        );

        return Contiguous!(S)(src[]);
    }

    /// ditto
    public static Contiguous!(S) deserialize ( S ) ( ref void[] src )
    {
        return deserialize!(S)(* cast(Buffer!(void)*) &src);
    }

    /***************************************************************************

        Identical to contiguous.Deserializer.deserialize but instead of
        modifying input buffer copies the deserialized data to provided
        Contiguous wrapper.

        Params:
            S = struct type `src` is assumed to contain
            src = buffer previously created by Serializer, unchanged
            dst = buffer to store deserialized data

        Returns:
            dst by value

    ***************************************************************************/

    public static Contiguous!(S) deserialize ( S ) ( in void[] src,
        ref Contiguous!(S) dst )
    out (_s)
    {
        auto s = cast(Contiguous!(S)) _s;

        assert (s.data.ptr is dst.ptr);

        debug (DeserializationTrace)
        {
            Stdout.formatln("< deserialize!({})({}, {}) : {}", S.stringof,
                src.ptr, dst.ptr, s.ptr);
        }
    }
    do
    {
        static assert (is(S == Unqual!(S)),
                       "Cannot deserialize qualified type : " ~ S.stringof);

        debug (DeserializationTrace)
        {
            Stdout.formatln("> deserialize!({})({}, {})", S.stringof,
                src.ptr, dst.ptr);
            nesting = 0;
            scope (exit) nesting = 0;
        }

        This.e.enforceInputSize!(S)(src.length, S.sizeof);

        assumeSafeAppend(dst.data);

        /*
         * Calculate the number of bytes used in src, data_len, and the number
         * of bytes required for branched array instances, slices_len.
         * data_len is at least S.sizeof; src[0 .. S.sizeof] refers to the S
         * instance while src[S.sizeof .. data_len] contains the serialised
         * dynamic arrays.
         * slices_len = 0 indicates that there are no branched arrays at all or
         * none of non-zero size. data_len + slice_len is the minimum required
         * size for dst.
         */

        size_t slices_len = 0,
               data_len   = This.countRequiredSize!(S)(src, slices_len);

        /*
         * Resize dst and copy src[0 .. data_len] to dst[0 .. data_len].
         */
        size_t total_length = data_len + slices_len;

        if (dst.data.length < total_length)
        {
            dst.data.length = total_length;
            assumeSafeAppend(dst.data);
        }

        size_t end_copy = (src.length < total_length) ? src.length : total_length;
        dst.data[0 .. end_copy] = src[0 .. end_copy];
        (cast(ubyte[]) dst.data)[end_copy .. $] = 0;

        verify(dst.data.length >= data_len);

        /*
         * Adjust the dynamic array instances in dst to slice the data in the
         * tail of dst, dst[S.sizeof .. data_len]. If S contains branched
         * arrays of non-zero length, call get_slice_buffer() to obtain memory
         * buffers for the dynamic array instances.
         */

        This.handleBranching!(S)(dst.data[0 .. data_len], dst.data[data_len .. $]);

        return dst;
    }

    /***************************************************************************

        Calculates total amount of bytes needed for an array to store
        deserialized S instance.

        Params:
            S = struct type `instance` is assumed to contain
            instance = serialized struct buffer to calculate data for

        Returns:
            required array size, total

    ***************************************************************************/

    public static size_t countRequiredSize ( S ) ( in void[] instance )
    out(size)
    {
        debug (DeserializationTrace)
        {
            Stdout.formatln("{}< countRequiredSize!({})({}) : {}", tabs,
                S.stringof, instance.ptr, size);
            nesting--;
        }
    }
    do
    {
        debug (DeserializationTrace)
        {
            nesting++;
            Stdout.formatln("{}> countRequiredSize!({})({})", tabs,
                S.stringof, instance.ptr);
        }

        size_t extra;
        size_t base = This.countRequiredSize!(S)(instance, extra);
        return extra + base;
    }

    /***************************************************************************

        Calculates extra amount of bytes needed for a buffer to store
        deserialized branched arrays, as well as amount of bytes used by an
        actual struct instance.

        This is the private version used internally as public one does not
        make that distinction and only return single size.

        Params:
            S = struct type
            data        = struct slice to calculate data for
            extra_bytes = extra space needed for branched arrays, this number
                is consequently accumulated through recursive calls to count*
                methods (which is why it is not `out` parameter)

        Returns:
            sized used by S data (before braching)

    ***************************************************************************/

    private static size_t countRequiredSize ( S ) ( in void[] data,
        ref size_t extra_bytes )
    out (size)
    {
        assert (size >= S.sizeof);

        debug (DeserializationTrace)
        {
            Stdout.formatln("{}< countRequiredSize!({})({}, {}) : {}",
                tabs,
                S.stringof,
                data.ptr,
                extra_bytes,
                cast(size_t)size
            );
            nesting--;
        }
    }
    do
    {
        debug (DeserializationTrace)
        {
            nesting++;
            Stdout.formatln("{}> countRequiredSize!({})({}, {})",
                tabs,
                S.stringof,
                data.ptr,
                extra_bytes
            );
        }

        This.e.enforceInputSize!(S)(data.length, S.sizeof);

        // array data starts immediately after the struct value type
        // members. Calculating size for those is in separate function
        // to make recursive calls possible - first call needs to strip
        // away S.sizeof part

        return countStructArraySizes!(S)( data[S.sizeof .. $], extra_bytes ) + S.sizeof;
    }

    /***************************************************************************

        For a given struct type S calculates buffer size needed to store
        its deserialized arrays including branched arrays. This method can
        be called recursively for any nested struct type, given a proper
        sub-slice

        Params:
            S = struct type
            data = slice of a serialized struct where array dumps are
                stored. This can also be any recursive array dump, not
                just the very first one.
            extra_bytes = extra space needed for branched arrays for these
                arrays and any of member arrays (recursively)

        Returns:
            size used by arrays stored at data[0]

    ***************************************************************************/

    private static size_t countStructArraySizes ( S ) ( in void[] data,
        ref size_t extra_bytes )
    out (size)
    {
        debug (DeserializationTrace)
        {
            Stdout.formatln("{}< countStructArraySizes!({})({}, {}) : {}",
                tabs,
                S.stringof,
                data.ptr,
                extra_bytes,
                cast(size_t)size
            );
            nesting--;
        }
    }
    do
    {
        debug (DeserializationTrace)
        {
            nesting++;
            Stdout.formatln("{}> countStructArraySizes!({})({}, {})",
                tabs,
                S.stringof,
                data.ptr,
                extra_bytes
            );
        }

        size_t pos = 0;

        foreach (i, QualField; typeof (S.tupleof))
        {
            alias StripQualifier!(QualField) Field;

            static if (is (Field == struct))
            {
                This.e.enforceInputSize!(S)(data.length, pos);

                pos += This.countStructArraySizes!(Field)(data[pos .. $], extra_bytes);
            }
            else static if (is (Field QualElement : QualElement[]))
            {
                alias StripQualifier!(QualElement) Element;
                This.e.enforceInputSize!(S)(data.length, pos);

                static if (is (QualElement[] == Field))
                {
                    // dynamic array
                    pos += This.countDynamicArraySize!(Element)(
                        data[pos .. $], extra_bytes);
                }
                else static if (hasIndirections!(Element))
                {
                    // static array with indirections
                    pos += This.countArraySize!(Element)(
                        Field.length, data[pos .. $], extra_bytes);
                }
            }
        }

        return pos;
    }

    /***************************************************************************

        Calculates number of bytes needed to deserialize an array.
        Additionally calculates number of extra bytes needed to store
        deserialized branched arrays (as per `sliceArray()` algorithm).

        Takes into consideration dynamic array serialization format (length
        word stored first)

        If there are no branched arrays available via T, amount of extra
        bytes is always expected to be 0

         Params:
             T = array element type
             data  = slice of serialized buffer where array data starts
             extra_bytes = incremented by the number of bytes required to
                store branched arrays

         Returns:
             number of bytes used in data

    ***************************************************************************/

    private static size_t countDynamicArraySize ( T ) ( in void[] data,
        ref size_t extra_bytes )
    out(size)
    {
        debug (DeserializationTrace)
        {
            Stdout.formatln("{}< countDynamicArraySize!({})({}, {}) : {}", tabs,
                T.stringof, data.ptr, extra_bytes, cast(size_t)size);
            nesting--;
        }
    }
    do
    {
        debug (DeserializationTrace)
        {
            nesting++;
            Stdout.formatln("{}> countDynamicArraySize!({})({}, {})", tabs,
                T.stringof, data.ptr, extra_bytes);
        }

        This.e.enforceInputSize!(T)(data.length, size_t.sizeof);

        /*
         * Obtain the array length from data, calculate the number of bytes of
         * the array and define the reading position in data.
         */

        size_t len   = *cast (size_t*) data[0 .. size_t.sizeof].ptr,
               bytes = len * T.sizeof,
               pos   = len.sizeof;

        debug (DeserializationTrace)
        {
            Stdout.formatln("{}  len = {}, bytes = {}, pos = {}", tabs, len, bytes, pos);
        }

        This.e.enforceSizeLimit!(T[])(len, This.max_length);

        static if (is (StripQualifier!(T) Element == Element[]))
        {
            /*
             * If array is an array of slices (dynamic arrays), obtain a data
             * buffer for these slices.
             */
            debug (DeserializationTrace)
            {
                Stdout.formatln("{}  need {} more bytes for branched arrays", tabs, bytes);
            }

            extra_bytes += bytes;
        }
        else
        {
            /*
             * array is an array of values so the values will follow in data.
             */

            debug (DeserializationTrace)
            {
                Stdout.formatln("{}  pos += {}", tabs, bytes);
            }

            pos += bytes;

            This.e.enforceInputSize!(T[])(data.length, pos);
        }

        static if (!hasIndirections!(T))
        {
            return pos;
        }
        else
        {
            return pos + This.countArraySize!(T)(len,
                data[pos .. $], extra_bytes);
        }
    }

    /***************************************************************************

        Recursively calculates data taken by all arrays available through T,
        applicable both to static and dynamic arrays.

        If no branched arrays are transitively stored in T, `extra_bytes` is not
        supposed to be incremeneted

         Params:
             T = array element type
             len   = array length
             data  = data of top-most array elements
             bytes = incremented by the number of bytes required by
                sliceSubArrays()

         Returns:
             number of bytes used in data

    ***************************************************************************/

    private static size_t countArraySize ( T ) ( size_t len, in void[] data,
        ref size_t extra_bytes )
    out(size)
    {
        debug (DeserializationTrace)
        {
            Stdout.formatln("{}< countArraySize!({})({}, {}, {}) : {}", tabs,
                T.stringof, len, data.ptr, extra_bytes, cast(size_t)size);
            nesting--;
        }
    }
    do
    {
        debug (DeserializationTrace)
        {
            nesting++;
            Stdout.formatln("{}> countArraySize!({})({}, {}, {})", tabs,
                T.stringof, len, data.ptr, extra_bytes);
        }

        size_t pos = 0;

        static if (is (T == struct))
        {
            for (size_t i = 0; i < len; i++)
            {
                This.e.enforceInputSize!(T[])(data.length, pos, __FILE__, __LINE__);

                pos += This.countStructArraySizes!(T)(data[pos .. $], extra_bytes);
            }
        }
        else static if (is (T Element : Element[]))
        {
            for (size_t i = 0; i < len; i++)
            {
                This.e.enforceInputSize!(T[])(data.length, pos);

                static if (is (Element[] == StripQualifier!(T)))
                {
                    pos += This.countDynamicArraySize!(Element)(
                        data[pos .. $], extra_bytes);
                }
                else
                {
                    pos += This.countArraySize!(Element)(
                        T.length, data[pos .. $], extra_bytes);
                }
            }
        }
        else
        {
            pragma (msg, "Warning: type \"", T, "\" contains no array, " ~
                         "ignoring it. This indicates a bug, please report " ~
                         "that this warning was triggered @",
                         __FILE__ , ":", __LINE__);
        }

        return pos;
    }

    /***************************************************************************

        Deserialization implementation that takes care of branched arrays by
        putting those into dedicated memory slice. This target slice is never
        resized so it is legal to use sub-slice of original buffer (unused
        memory part) as `slices_buffer` argument.

        Params:
            S = struct type to deserialize
            src = buffer that is expected to contain serialized S
            slices_buffer = place to store expanded branched array slices

        Returns:
            src slice for deserialized data, branched part not included (as it
            may be in a different memory chunk). Adjust it to also include
            branched array if necessary at the call site

    ***************************************************************************/

    private static void[] handleBranching ( S ) ( void[] src,
        void[] slices_buffer )
    out (data)
    {
        assert (data.ptr    is src.ptr);
        assert (data.length <= src.length);

        debug (DeserializationTrace)
        {
            Stdout.formatln("{}< handleBranching!({})({}, {}) : {}", tabs,
                S.stringof, src.ptr, slices_buffer.ptr, data.ptr);
            nesting--;
        }
    }
    do
    {
        debug (DeserializationTrace)
        {
            nesting++;
            Stdout.formatln("{}> handleBranching!({})({}, {})", tabs,
                S.stringof, src.ptr, slices_buffer.ptr);
        }

        /*
         * Adjust the dynamic array instances in src to slice the data in the
         * tail of src, src[S.sizeof .. $]. If S contains branched
         * arrays of non-zero length, slices_buffer gets used to store that data
         */

        size_t arrays_length = This.sliceArrays(
            *cast (S*) src[0 .. src.length].ptr,
            src[S.sizeof .. $], slices_buffer
        );

        return src[0 .. arrays_length + S.sizeof];
    }

    /***************************************************************************

        Sets all dynamic array members of s to slice the corresponding sections
        of data. data must be a concatenated sequence of chunks generated by
        transmitArray() for each dynamic array member of S.

        Params:
            s             = struct instance to set arrays to slice data
            data          = array data to slice
            slices_buffer = place to put branched array slices

        Returns:
            number of data bytes sliced

        Throws:
            DeserializationException if data is too short

    ***************************************************************************/

    private static size_t sliceArrays ( S ) ( ref S s, void[] data,
        ref void[] slices_buffer )
    out
    {
        debug (DeserializationTrace)
        {
            Stdout.formatln("{}< sliceArrays!({})({}, {}, {}) : {}", tabs,
                S.stringof, &s, data.ptr, slices_buffer.ptr, data.ptr);
            nesting--;
        }
    }
    do
    {
        verify(slices_buffer !is null);

        debug (DeserializationTrace)
        {
            nesting++;
            Stdout.formatln("{}> sliceArrays!({})({}, {}, {})", tabs,
                S.stringof, &s, data.ptr, slices_buffer.ptr);
        }

        size_t pos = 0;

        foreach (i, ref field; s.tupleof)
        {
            alias StripQualifier!(typeof(field)) Field;
            auto pfield = cast(Field*) &field;

            static if (is (Field == struct))
            {
                This.e.enforceInputSize!(S)(data.length, pos);

                pos += This.sliceArrays(*pfield, data[pos .. $], slices_buffer);
            }
            else static if (is (Field Element : Element[]))
            {
                This.e.enforceInputSize!(S)(data.length, pos);

                static if (is (Element[] == Field))
                {
                    auto increment = This.sliceArray(*pfield, data[pos .. $],
                        slices_buffer);

                    // if host struct is Contiguous, internal `data` array
                    // needs to be deserialized as a struct to ensure that
                    // internal pointers are updated and it stays contiguous
                    static if (is(S T == Contiguous!(T)))
                    {
                        static assert (is(Element == void));
                        auto orig_length = field.length;
                        deserialize!(T)(*pfield);
                        verify (orig_length == field.length);
                    }

                    pos += increment;
                }
                else static if (hasIndirections!(Element))
                {
                    pos += This.sliceSubArrays(*pfield, data[pos .. $], slices_buffer);
                }
            }
        }

        return pos;
    }

    /***************************************************************************

        Creates an array slice to data. Data must start with a size_t value
        reflecting the byte length, followed by the array content data.

        Params:
            array         = resulting array
            data          = array data to slice
            slices_buffer = place to store branched array slices if any

        Returns:
            number of data bytes sliced

        Throws:
            DeserializationException if data is too short

    ***************************************************************************/

    private static size_t sliceArray ( T ) ( out T[] array, void[] data,
        ref void[] slices_buffer )
    out(size)
    {
        debug (DeserializationTrace)
        {
            Stdout.formatln("{}< sliceArray!({})({}, {}, {}) : {}", tabs,
                T.stringof, array.ptr, data.ptr, slices_buffer.ptr, cast(size_t)size);
            nesting--;
        }
    }
    do
    {
        verify (slices_buffer !is null);

        debug (DeserializationTrace)
        {
            nesting++;
            Stdout.formatln("{}> sliceArray!({})({}, {}, {})", tabs,
                T.stringof, array.ptr, data.ptr, slices_buffer.ptr);
        }

        This.e.enforceInputSize!(T[])(data.length, size_t.sizeof);

        /*
         * Obtain the array length from data, calculate the number of bytes of
         * the array and define the reading position in data.
         */

        size_t len   = *cast (size_t*) data[0 .. size_t.sizeof].ptr,
               bytes = len * T.sizeof,
               pos   = len.sizeof;

        debug (DeserializationTrace)
        {
            Stdout.formatln("{}  len = {}, bytes = {}, pos = {}", tabs, len, bytes, pos);
        }

        This.e.enforceSizeLimit!(T[])(len, This.max_length);

        static if (is (StripQualifier!(T) Element == Element[]))
        {
            /*
             * If array is an array of slices (dynamic arrays), obtain a data
             * buffer for these slices.
             */

            debug (DeserializationTrace)
            {
                Stdout.formatln("{}  obtaining buffer for branched arrays from slice {}",
                    tabs, slices_buffer.ptr);
            }

            This.e.enforceInputSize!(T[])(slices_buffer.length, bytes);
            array = cast (T[]) slices_buffer[0 .. bytes];
            slices_buffer = slices_buffer[bytes .. $];
        }
        else
        {
            /*
             * array is an array of values so the values will follow in data.
             */

            pos += bytes;

            This.e.enforceInputSize!(T[])(data.length, pos);

            array = cast (T[]) data[len.sizeof .. pos];
        }

        verify (array.length == len);

        static if (!hasIndirections!(T))
        {
            return pos;
        }
        else
        {
            /*
             * If array is an array of a non-primitive type, recurse into the
             * array elements.
             */

            debug (DeserializationTrace)
            {
                Stdout.formatln("{}  writing branched array elements to {}", tabs, array.ptr);
            }

            return pos + This.sliceSubArrays(array, data[pos .. $], slices_buffer);
        }
    }

    /***************************************************************************

        Sets the elements of array to slice the corresponding parts of data if
        T contains a dynamic array.

        Params:
            array         = array to adjust elements
            data          = array data to slice
            slices_buffer = slice to store branched array data to

        Returns:
            number of data bytes sliced

        Throws:
            DeserializationException if data is too short

    ***************************************************************************/

    private static size_t sliceSubArrays ( QualT )
                                  ( QualT[] array, void[] data, ref void[] slices_buffer )
    out(size)
    {
        debug (DeserializationTrace)
        {
            Stdout.formatln("{}< sliceSubArrays!({})({} @{}, {}, {}) : {}", tabs,
                QualT.stringof, array.length, array.ptr, data.ptr,
                slices_buffer.ptr, cast(size_t)size);
            nesting--;
        }
    }
    do
    {
        verify (slices_buffer !is null);

        debug (DeserializationTrace)
        {
            nesting++;
            Stdout.formatln("{}> sliceSubArrays!({})({} @{}, {}, {})", tabs,
                QualT.stringof, array.length, array.ptr, data.ptr, slices_buffer.ptr);
        }

        size_t pos = 0;

        alias StripQualifier!(QualT) T;

        static if (is (T == struct))
        {
            foreach (ref element; array)
            {
                This.e.enforceInputSize!(T[])(data.length, pos);

                pos += This.sliceArrays(element, data[pos .. $], slices_buffer);
            }
        }
        else static if (is (T Element : Element[]))
        {

            foreach (ref element; array)
            {
                This.e.enforceInputSize!(T[])(data.length, pos);
                auto pelement = cast(T*) &element;

                static if (is (Element[] == T))
                {
                    pos += This.sliceArray(*pelement, data[pos .. $], slices_buffer);
                }
                else static if (hasIndirections!(Element))
                {
                    pos += This.sliceSubArrays(*pelement, data[pos .. $], slices_buffer);
                }
            }
        }

        return pos;
    }

    /**************************************************************************

        `static assert`s that `T` has no qualifier.

     **************************************************************************/

    template StripQualifier ( T )
    {
        static assert (!is(T == immutable));
        alias Unqual!(T) StripQualifier;
    }

    /**************************************************************************/

    debug (DeserializationTrace) private static
    {
        char[20] tabs_ = '\t';
        uint nesting = 0;
        cstring tabs ( ) { return tabs_[0 .. nesting]; }
    }
}

unittest
{
    // only instantiation, check package_test.d for actual tests

    struct Trivial
    {
        int a,b;
    }

    void[] buf = cast(void[]) [ 42, 43 ];
    auto r1 = Deserializer.deserialize!(Trivial)(buf);

    Contiguous!(Trivial) copy_dst;
    auto r2 = Deserializer.deserialize(buf, copy_dst);
}
