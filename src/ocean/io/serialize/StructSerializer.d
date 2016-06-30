/******************************************************************************

    Struct data serialization and deserialization tools

    Used for plugin-based serialization and stream serialization. For binary
    struct serialization use `ocean.util.serialize.contiguous` package.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.io.serialize.StructSerializer;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.io.serialize.SimpleSerializer;

import ocean.core.Exception;

import ocean.io.model.IConduit: IOStream, InputStream, OutputStream;

import ocean.core.Traits;
import ocean.core.Traits;


/*******************************************************************************

    SerializerException

*******************************************************************************/

class SerializerException : Exception
{
    mixin DefaultExceptionCtor;

    /***************************************************************************

        StructSerializer Exception

    ***************************************************************************/

    static class LengthMismatch : SerializerException
    {
        size_t bytes_expected, bytes_got;

        this ( size_t bytes_expected, size_t bytes_got,
               istring msg, istring file, typeof(__LINE__) line )
        {
            super(msg, file, line);

            this.bytes_expected = bytes_expected;
            this.bytes_got      = bytes_got;
        }
    }
}


/*******************************************************************************

    Struct serializer

    Template_Params:
        AllowUnions = if true, unions will be serialized as raw bytes, without
            checking whether the union contains dynamic arrays. Otherwise unions
            cause a compile-time error.

    TODO: proper union support -- must recurse into unions looking for dynamic
    arrays

*******************************************************************************/

struct StructSerializer ( bool AllowUnions = false )
{
    import ocean.core.Traits : ContainsDynamicArray, FieldName, FieldType, GetField;
    import ocean.core.Traits : isAssocArrayType;

    static:

    /**************************************************************************

        Dumps/serializes the content of s and its array members, writing
        serialized data to output.

        Params:
            s      = struct instance (pointer)
            output = output stream to write serialized data to

        Returns:
            number of bytes written

     **************************************************************************/

    size_t dump ( S ) ( S* s, OutputStream output )
    {
        return dump(s, (void[] data) {SimpleSerializer.transmit(output, data);});
    }

    /**************************************************************************

        Dumps/serializes the content of s and its array members.

        send is called repeatedly; on each call, it must store or forward the
        provided data.

        Params:
            s    = struct instance (pointer)
            receive = receiving callback delegate

        Returns:
            number of bytes written

     **************************************************************************/

    size_t dump ( S ) ( S* s, void delegate ( void[] data ) receive )
    in
    {
        assertStructPtr!("dump")(s);
    }
    body
    {
        return transmit!(false)(s, receive);
    }

    /**************************************************************************

        Loads/deserializes the content of s and its array members, reading
        serialized data from input.

        Params:
            s     = struct instance (pointer)
            input = input stream to read data from

        Returns:
            number of bytes read

     **************************************************************************/

    size_t load ( S ) ( S* s, InputStream input )
    {
        return load(s, (void[] data) {SimpleSerializer.transmit(input, data);});
    }

    /**************************************************************************

        Loads/deserializes the content of s and its array members.

        receive is called repeatedly; on each call, it must populate the
        provided data buffer with data previously produced by dump(). Data which
        was populated once should not be populated again. So the delegate must
        behave like a stream receive function.

        Params:
            s       = struct instance (pointer)
            receive = receiving callback delegate

        Returns:
            number of bytes read

     **************************************************************************/

    size_t load ( S ) ( S* s, void delegate ( void[] data ) receive )
    in
    {
        assertStructPtr!("load")(s);
    }
    body
    {
        return transmit!(true)(s, receive);
    }

    /**************************************************************************

        Dumps/serializes or loads/deserializes the content of s and its
        members.

        transmit_data is called repeatedly; on each call,
         - if receive is false, it must it must store or forward the provided
           data;
         - if receive is true, it must populate the provided data buffer with
           data previously produced by dump(). Data which was populated once
           should not be populated again. So the delegate must behave like a
           stream receive function.

        Params:
            s             = struct instance (pointer)
            transmit_data = sending/receiving callback delegate

        Returns:
            number of bytes read or written

     **************************************************************************/

    size_t transmit ( bool receive, S ) ( S* s, void delegate ( void[] data ) transmit_data )
    in
    {
        assert (s, typeof (*this).stringof ~ ".transmit (receive = " ~
                receive.stringof ~ "): source pointer of type '" ~ S.stringof ~
                "*' is null");
    }
    body
    {
        S s_copy = *s;

        S* s_copy_ptr = &s_copy;

        static if (receive)
        {
            transmit_data((cast (void*) s)[0 .. S.sizeof]);

            copyReferences(s_copy_ptr, s);
        }
        else
        {
            resetReferences(s_copy_ptr);

            transmit_data((cast (void*) s_copy_ptr)[0 .. S.sizeof]);
        }

        return S.sizeof + transmitArrays!(receive)(s, transmit_data);
    }


    /**************************************************************************

        Dumps/serializes the content of s and its array members, using the given
        serializer object. The serializer object needs the following methods:

            void open ( D, cstring name );

            void close ( D, cstring name );

            void serialize ( T ) ( D, ref T item, cstring name );

            void openStruct ( D, cstring name );

            void closeStruct ( D, cstring name );

            void serializeArray ( T ) ( D, cstring name, T[] array );

              Optional:

                void serializeStaticArray ( T ) ( D, cstring name, T[] array );

              If this methond doesn't exist, serializeArray will be used.

            void openStructArray ( T ) ( D, cstring name, T[] array );

            void closeStructArray ( T ) ( D, cstring name, T[] array );

        Unfortunately, as some of these methods are templates, it's not
        possible to make an interface for it. But the compiler will let you know
        whether a given serializer object is suitable or not

        See ocean.io.serialize.JsonStructSerializer for an example.

        Template_Params:
            S = type of struct to serialize
            Serializer = type of serializer object
            D = tuple of data parameters passed to the serializer

        Params:
            s    = struct instance (pointer)
            serializer = object to do the serialization
            data = parameters for serializer

     **************************************************************************/

    public void serialize ( S, Serializer, D ... ) ( S* s, Serializer serializer, ref D data )
    {
        serializer.open(data, S.stringof);
        serialize_(s, serializer, data);
        serializer.close(data, S.stringof);
    }


    /**************************************************************************

        Loads/deserializes the content of s and its array members, using the
        given deserializer object. The deserializer object needs the following
        methods:

                void open ( ref Char[] input, cstring name );

                void close ( );

                void deserialize ( T ) ( ref T output, cstring name );

                void deserializeStruct ( ref T output, Char[] name, void delegate ( ) deserialize_struct );

                void deserializeArray ( T ) ( ref T[] output, Char[] name );

                void deserializeStaticArray ( T ) ( T[] output, Char[] name );

                void deserializeStructArray ( T ) ( ref T[] output, Char[] name, void delegate ( ref T ) deserialize_element );

        Unfortunately, as some of these methods are templates, it's not
        possible to make an interface for it. But the compiler will let you know
        whether a given deserializer object is suitable or not

        See ocean.io.serialize.JsonStructDeserializer for an example.

        Params:
            s = struct instance (pointer)
            deserializer = object to do the deserialization
            data = input buffer to read serialized data from

     **************************************************************************/

    public void deserialize ( S, Deserializer, D ) ( S* s, Deserializer deserializer, D[] data )
    {
        deserializer.open(data, S.stringof);
        deserialize_(s, deserializer, data);
        deserializer.close();
    }

    /**************************************************************************

        Resets all references in s to null.

        Params:
            s = struct instance (pointer)

     **************************************************************************/

    S* resetReferences ( S ) ( S* s )
    {
        foreach (i, ref field; s.tupleof)
        {
            alias typeof(field) T;

            static if (is (T == struct))
            {
                resetReferences(&field);                                         // recursive call
            }
            else static if (isReferenceType!(T))
            {
                field = null;
            }
        }

        return s;
    }

    /**************************************************************************

        Copies all references from dst to src.

        Params:
            src = source struct instance (pointer)
            dst = destination struct instance (pointer)

     **************************************************************************/

    S* copyReferences ( S ) ( S* src, S* dst )
    {
        foreach (i, ref src_field; src.tupleof)
        {
            alias typeof(src_field) T;

            T* dst_field = &dst.tupleof[i];

            static if (is (T == struct))
            {
                copyReferences(&src_field, dst_field);                           // recursive call
            }
            else static if (isReferenceType!(T))
            {
                *dst_field = src_field;
            }
        }

        return dst;
    }

    /**************************************************************************

        Transmits (sends or receives) the serialized data of all array fields in
        s.

        Template parameter:
            receive = true: receive array data, false: send array data

        Params:
            s        = struct instance (pointer)
            transmit = sending/receiving callback delegate

        Returns:
            passes through return value of transmit

        FIXME: Does currently not scan static array fields for a struct type
        containing dynamic arrays. Example:

         ---
             struct S1
             {
                 int[] x;
             }

             struct S2
             {

                 S1[7] y;   // elements contain a dynamic array
             }
         ---

     **************************************************************************/

    size_t transmitArrays ( bool receive, S ) ( S* s, void delegate ( void[] array ) transmit )
    {
        size_t bytes = 0;

        foreach (i, ref field; s.tupleof)
        {
            alias typeof(field) T;

            static if (is (T == struct))
            {
                bytes += transmitArrays!(receive)(&field, transmit);             // recursive call
            }
            else static if (is (T U == U[]))
            {
                mixin AssertSupportedArray!(T, U, S, i);

                bytes += transmitArray!(receive)(field, transmit);
            }
            else mixin AssertSupportedType!(T, S, i);
        }

        return bytes;
    }

    /***************************************************************************

        Transmits (sends or receives) the serialized data of array. That is,
        first transmit the array content byte length as size_t value, then the
        array content raw data.

        Template parameter:
            receive = true: receive array data, false: send array data

        Params:
            array    = array to send serialized data of (pointer)
            transmit_dg = sending/receiving callback delegate

        Returns:
            passes through return value of send

        TODO: array needs to be duped

     **************************************************************************/

    size_t transmitArray ( bool receive, T ) ( ref T[] array, void delegate ( void[] data ) transmit_dg )
    {
        size_t len,
               bytes = len.sizeof;

        static if (!receive)
        {
            len = array.length;
        }

        transmit_dg((cast (void*) &len)[0 .. len.sizeof]);

        static if (receive)
        {
            array.length = len;
        }

        static if (is (T == struct))                                            // recurse into substruct
        {                                                                       // if it contains dynamic
            const RecurseIntoStruct = ContainsDynamicArray!(typeof (T.tupleof));// arrays
        }
        else
        {
            const RecurseIntoStruct = false;
        }

        static if (is (T U == U[]))                                             // recurse into subarray
        {
            foreach (ref element; array)
            {
                bytes += transmitArray!(receive)(element, transmit_dg);
            }
        }
        else static if (RecurseIntoStruct)
        {
            debug ( StructSerializer ) pragma (msg, typeof (*this).stringof  ~ ".transmitArray: "
                               "array elements of struct type '" ~ T.stringof ~
                               "' contain subarrays");

            foreach (ref element; array)
            {
                bytes += transmit!(receive)(&element, transmit_dg);
            }
        }
        else
        {
            size_t n = len * T.sizeof;

            transmit_dg((cast (void*) array.ptr)[0 .. n]);

            bytes += n;
        }

        return bytes;
    }

    /**************************************************************************

        Dumps/serializes the content of s and its array members, using the given
        serializer object. See the description of the dump() method above for a
        full description of how the serializer object should behave.

        Template_Params:
            S = type of struct to serialize
            Serializer = type of serializer object
            D = tuple of data parameters passed to the serializer

        Params:
            s = struct instance (pointer)
            serializer = object to do the serialization
            data = parameters for serializer

     **************************************************************************/

    private void serialize_ ( S, Serializer, D ... ) ( S* s, Serializer serializer, ref D data )
    {
        foreach (i, ref field; s.tupleof)
        {
            alias typeof(field) T;
            const field_name = FieldName!(i, S);

            static if ( is(T == struct) )
            {
                serializer.openStruct(data, field_name);
                serialize_(&field, serializer, data);                            // recursive call
                serializer.closeStruct(data, field_name);
            }
            else static if( is(T U : U[]) )
            {
                // slice array (passing a static array as ref is not allowed)
                U[] array = field;

                static if ( is(BaseTypeOfArrays!(U) == struct) )
                {
                    serializeStructArray(array, field_name, serializer, data);
                }
                else static if ( isStaticArrayType!(T) &&
                                 is ( typeof(serializer.serializeStaticArray!(T)) ) )
                {
                    serializer.serializeStaticArray(data, field_name, array);
                }
                else
                {
                    serializer.serializeArray(data, field_name, array);
                }
            }
            else
            {
                mixin AssertSupportedType!(T, S, i);

                static if (isTypedef!(T))
                {
                    mixin(`
                    static if ( is(T B == typedef) )
                    {
                        serializer.serialize(data, cast(B)(field), field_name);
                    }
                    `);
                }
                else static if ( is(T B == enum) )
                {
                    serializer.serialize(data, cast(B)(field), field_name);
                }
                else
                {
                    serializer.serialize(data, field, field_name);
                }
            }
        }
    }

    /**************************************************************************

        Dumps/serializes array which is expected to be a one- or multi-
        dimensional array of structs, using the given serializer object. See the
        description of the dump() method above for a full description of how the
        serializer object should behave.

        Template_Params:
            T = array base type, should be a struct or a (possibly
                multi-dimensional) array of structs
            Serializer = type of serializer object
            D = tuple of data parameters passed to the serializer

        Params:
            array = array to serialize
            field_name = the name of the struct field that contains the array
            serializer = object to do the serialization
            data = parameters for serializer

     **************************************************************************/

    private void serializeStructArray ( T, Serializer, D ... ) ( T[] array,
        cstring field_name, Serializer serializer, ref D data )
    {
        serializer.openStructArray(data, field_name, array);

        foreach ( ref element; array )
        {
            static if ( is(T U : U[]) )
            {
                serializeStructArray(element, field_name, serializer, data);
            }
            else
            {
                static assert(is(T == struct));
                serializer.openStruct(data, T.stringof);
                serialize_(&element, serializer, data);
                serializer.closeStruct(data, T.stringof);
            }
        }

        serializer.closeStructArray(data, field_name, array);
    }

    /**************************************************************************

        Loads/deserializes the content of s and its array members, using the
        given deserializer object. See the description of the load() method
        above for a full description of how the deserializer object should
        behave.

        Params:
            s = struct instance (pointer)
            deserializer = object to do the deserialization
            data = input buffer to read serialized data from

     **************************************************************************/

    private void deserialize_ ( S, Deserializer, D ) ( S* s, Deserializer deserializer, D[] data )
    {
        foreach (i, T; typeof (S.tupleof))
        {
            T*    field      = GetField!(i, T, S)(s);
            const field_name = FieldName!(i, S);

            static if ( is(T == struct) )
            {
                deserializer.openStruct(data, field_name);
                deserialize_(field, serializer, data);                          // recursive call
                deserializer.closeStruct(data, field_name);
            }
            else static if ( is(T U : U[]) )
            {
                static if ( is(U == struct) )
                {
                    deserializer.openStructArray(data, field_name, array);
                    foreach ( element; array )
                    {
                        deserializer.openStruct(data, U.stringof);
                        deserialize_(&element, serializer, data);               // recursive call
                        deserializer.closeStruct(data, U.stringof);
                    }
                    deserializer.closeStructArray(data, field_name, array);
                }
                else
                {
                    static if ( isStaticArrayType!(T) )
                    {
                        deserializer.deserializeStaticArray(*field, field_name);
                    }
                    else
                    {
                        deserializer.deserializeArray(*field, field_name);
                    }
                }
            }
            else
            {
                mixin AssertSupportedType!(T, S, i);

                static if (isTypedef!(T))
                {
                    mixin(`
                    else static if ( is(T B == typedef) )
                    {
                        deserializer.deserialize(cast(B)(*field), field_name);
                    }
                    `);
                }
                else static if ( is(T B == enum) )
                {
                    deserializer.deserialize(cast(B)(*field), field_name);
                }
                else
                {
                    deserializer.deserialize(*field, field_name);
                }
            }
        }
    }

    /**************************************************************************

        Asserts s != null; s is assumed to be the struct source or destination
        pointer. In addition a warning message is printed at compile time if
        S is a pointer to a pointer.
        The s != null checking is done in assert() fashion; that is, it is not
        done in release mode.

        Template_Params:
            func = invoking function (for message generation)

        Params:
            s = pointer to a source or destination struct; shall not be null

        Throws:
            Exception if s is null

     **************************************************************************/

    private void assertStructPtr ( istring func, S ) ( S* s )
    {
        static if (is (S T == T*))
        {
            pragma (msg, typeof (*this).stringof ~ '.' ~ func ~ " - warning: "
                    "passing struct pointer argument of type '" ~ (S*).stringof ~
                    "' (you " "probably want '" ~ (T*).stringof ~ "')");
        }

        assert (s, typeof (*this).stringof ~ '.' ~ func ~ ": "
                "pointer of type '" ~ S.stringof ~ "*' is null");
    }

    /**************************************************************************

        Tells whether T is a reference type. That is

            - pointer, dynamic array, associative array,
            - class, interface
            - delegate, function reference

        Template parameter:
            T = type to check

        Evaluates to:
            true if T is a reference type or false otherwise

     **************************************************************************/

    template isReferenceType ( T )
    {
        static if (is (T U == U[]) || is (T U == U*))                           // dynamic array or pointer
        {
            const isReferenceType = true;
        }
        else
        {
            const isReferenceType = is (T == class)      ||
                                    is (T == interface)  ||
                                    isAssocArrayType!(T) ||
                                    is (T == delegate)   ||
                                    is (T == function);
        }
    }

    /**************************************************************************

        Asserts that T, which is the type of the i-th field of S, is a supported
        field type for struct serialization; typedefs and unions are currently
        not supported.
        Warns if T is an associative array.

        Template parameters:
            T = type to check
            S = struct type (for message generation)
            i = struct field index (for message generation)

     **************************************************************************/

    template AssertSupportedType ( T, S, size_t i )
    {
        static assert (AllowUnions || !is (T == union),
                       typeof (*this).stringof ~ ": unions are not supported, sorry "
                        "(affects " ~ FieldInfo!(T, S, i) ~ ") -- use AllowUnions "
                        "template flag to enable shallow serialization of unions");

        static if (isAssocArrayType!(T)) pragma (msg, typeof (*this).stringof ~
                                             " - Warning: content of associative array will be discarded "
                                             "(affects " ~ FieldInfo!(T, S, i) ~ ')');
    }

    /**************************************************************************

        Asserts that T, which is an array of U and the type of the i-th field of
        S, is a supported array field type for struct serialization;
        multi-dimensional arrays and arrays of reference types or structs are
        currently not supported.

        Template parameter:
            T = type to check
            U = element type of array type T
            S = struct type (for message generation)
            i = struct field index (for message generation)

     **************************************************************************/

    template AssertSupportedArray ( T, U, S, size_t i )
    {
       static if (is (U V == V[]))
       {
           static assert (!isReferenceType!(V), typeof (*this).stringof ~ ": arrays "
                          "of reference types are not supported, sorry "
                          "(affects " ~ FieldInfo!(T, S, i) ~ ')');
       }
       else
       {
           static assert (!isReferenceType!(U), typeof (*this).stringof ~ ": arrays "
                          "of reference types are not supported, sorry "
                          "(affects " ~ FieldInfo!(T, S, i) ~ ')');
       }
    }

    /**************************************************************************

        Generates a struct field information string for messages

     **************************************************************************/

    template FieldInfo ( T, S, size_t i )
    {
        const FieldInfo = '\'' ~ S.tupleof[i].stringof ~ "' of type '" ~ T.stringof ~ '\'';
    }
}


/*******************************************************************************

    Test for plugin serializer

*******************************************************************************/

version ( UnitTest )
{
    import ocean.core.Test;

    struct TestSerializer
    {
        import ocean.text.convert.Format;

        void open ( ref char[] dst, cstring name )
        {
            dst ~= "{";
        }

        void close ( ref char[] dst, cstring name )
        {
            dst ~= "}";
        }

        void serialize ( T ) ( ref char[] dst, ref T item, cstring name )
        {
            Format.format(dst, "{} {}={} ", T.stringof, name, item);
        }

        void openStruct ( ref char[] dst, cstring name )
        {
            dst ~= name ~ "={";
        }

        void closeStruct ( ref char[] dst, cstring name )
        {
            dst ~= "} ";
        }

        void serializeArray ( T ) ( ref char[] dst, cstring name, T[] array )
        {
            static if ( is(T == char) )
            {
                Format.format(dst, "{}[] {}=\"{}\" ", T.stringof, name, array);
            }
            else
            {
                Format.format(dst, "{}[] {}={} ", T.stringof, name, array);
            }
        }

        void serializeStaticArray ( T ) ( ref char[] dst, cstring name, T[] array )
        {
            Format.format(dst, "{}[{}] {}={} ", T.stringof, array.length, name, array);
        }

        void openStructArray ( T ) ( ref char[] dst, cstring name, T[] array )
        {
            dst ~= name ~ "={";
        }

        void closeStructArray ( T ) ( ref char[] dst, cstring name, T[] array )
        {
            dst ~= "} ";
        }
    }
}

unittest
{
    struct TestStruct
    {
        mstring name;
        int[] numbers;
        int x;
        float y;
        struct InnerStruct
        {
            int z;
        }

        int[4] static_array;
        InnerStruct a_struct;
        InnerStruct[] some_structs;
    }

    TestStruct s;
    s.name = "hello".dup;
    s.numbers = [12, 23];
    s.some_structs.length = 2;

    TestSerializer ser;
    char[] dst;
    StructSerializer!().serialize(&s, ser, dst);
    test!("==")(dst, "{char[] name=\"hello\" int[] numbers=[12, 23] int x=0 float y=nan int[4] static_array=[0, 0, 0, 0] a_struct={int z=0 } some_structs={InnerStruct={int z=0 } InnerStruct={int z=0 } } }"[]);
}


/*******************************************************************************

    Unittests

*******************************************************************************/

version (UnitTest)
{

    /***************************************************************************

        Imports

    ***************************************************************************/

    import ocean.core.Traits;
    import ocean.stdc.time;
    import ocean.util.Convert : to;
    import ocean.time.StopWatch;
    import core.memory;
    debug ( OceanPerformanceTest ) import ocean.io.Stdout : Stderr;

    /***************************************************************************

        Provides a growing container. It will overwrite the oldest entries as soon
        as the maxLength is reached.

    ***************************************************************************/

    struct CircularBuffer_ (T)
    {
        /***********************************************************************

            growing array of elements

        ***********************************************************************/

        T[] elements;

        /***********************************************************************

           maximum allowed size of the array

        ***********************************************************************/

        size_t maxLength = 50;

        /***********************************************************************

            current write position

        ***********************************************************************/

        size_t write = 0;

        /***********************************************************************

            Pushes an element on the Cache. If maxLength isn't reached, resizes
            the cache. If it is reached, overwrites the oldest element

            Params:
                element = The element to push into the cache

        ***********************************************************************/

        void push (T element)
        {
            if (this.elements.length == this.write)
            {
                if (this.elements.length < this.maxLength)
                {
                    this.elements.length = this.elements.length + 1;
                }
                else
                {
                    this.write = 0;
                }
            }

            static if (isArrayType!(T))
            {
                this.elements[this.write].length = element.length;
                this.elements[this.write][] = element[];
            }
            else
            {
                this.elements[this.write] = element;
            }

            ++this.write;
        }

        /***********************************************************************

            Returns the offset-newest element. Defaults to 0 (the newest)

            Params:
                offset = the offset-newest element. The higher this number, the
                         older the returned element. Defaults to zero. (the newest
                         element)

        ***********************************************************************/

        T* get (size_t offset=0)
        {
            if (offset < this.elements.length)
            {
                if (cast(int)(this.write - 1 - offset) < 0)
                {
                    return &elements[$ - offset + this.write - 1];
                }

                return &elements[this.write - 1 - offset];
            }

            throw new Exception("Element does not exist");
        }
    }

    alias CircularBuffer_!(char[]) Urls;


    /***************************************************************************

        Retargeting profile

    ***************************************************************************/

    struct RetargetingAction
    {
        hash_t id;
        hash_t adpan_id;
        time_t lastseen;
        ubyte action;


        static RetargetingAction opCall(hash_t id,hash_t adpan_id,time_t lastseen,
                                        ubyte action)
        {

            RetargetingAction a = { id,adpan_id,lastseen,action };

            return a;
        }
    }

    /***************************************************************************

        Retargeting list

    ***************************************************************************/

    alias CircularBuffer_!(RetargetingAction) Retargeting;

    struct MeToo(int deep)
    {
        uint a;
        char[] jo;
        int[2] staticArray;
        static if(deep > 0)
            MeToo!(deep-1) rec;

        static if(deep > 0)
            static MeToo opCall(uint aa, char[] jo, int sta, int stb,MeToo!(deep-1) rec)
            {
                MeToo a = {aa,jo,[sta,stb],rec};
                return a;
            }
        else
            static MeToo!(0) opCall(uint aa, char[] jo, int sta, int stb,)
            {
                MeToo!(0) a = {aa,jo,[sta,stb]};
                return a;
            }
    }
}
