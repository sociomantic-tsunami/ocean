/*******************************************************************************

    Simple serializer for reading / writing generic data from / to IOStreams

    Usage example, writing:

    ---

        import ocean.io.serialize.SimpleSerializer;

        scope file = new File("myfile.dat", File.WriteCreate);

        char[] some_data = "data to be written to the file first";
        char[][] more_data = ["second", "third", "fourth", "etc"];

        SimpleSerializer.write(file, some_data);
        SimpleSerializer.write(file, more_data);

    ---

    Usage example, reading:

    ---

        import ocean.io.serialize.SimpleSerializer;

        scope file = new File("myfile.dat", File.ReadExisting);

        char[] some_data;
        char[][] more_data;

        SimpleSerializer.read(file, some_data);
        SimpleSerializer.read(file, more_data);

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.serialize.SimpleSerializer;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.Enforce: enforce;

import ocean.core.Traits;

import ocean.io.model.IConduit: IOStream, InputStream, OutputStream;


public alias SimpleSerializerT!(true) SimpleSerializerArrays;
public alias SimpleSerializerT!(false) SimpleSerializer;

/*******************************************************************************

    Simple serializer struct - just a namespace, all methods are static.

    Template_Params:
        SerializeDynArrays = true: dynamic arrays in structs will be serialized
                             false: not.

*******************************************************************************/

struct SimpleSerializerT ( bool SerializeDynArrays = true )
{
static:

    /***************************************************************************

        Writes something to an output stream. Single elements are written
        straight to the output stream, while array types have their length
        written, followed by each element.

        If data is a pointer to a struct or union, it is dereferenced
        automatically.

        Template_Params:
            T = type of data to write

        Params:
            output = output stream to write to
            data = data to write

        Returns:
            number of bytes transmitted

        Throws:
            EofException on End Of Flow condition (note that the exception is
            always newed)

    ***************************************************************************/

    public size_t write ( T ) ( OutputStream output, T data )
    {
        return transmit(output, data);
    }

    /***************************************************************************

        Writes data to output, consuming the data buffer content to its
        entirety.

        Params:
            output = stream to write to
            data = pointer to data buffer
            bytes = length of data in bytes

        Returns:
            number of bytes transmitted

        Throws:
            EofException on End Of Flow condition (note that the exception is
            always newed)

    ***************************************************************************/

    public size_t writeData ( OutputStream output, void* data, size_t bytes )
    {
        return transmitData(output, data[0..bytes]);
    }

    /***************************************************************************

        Writes data to output, consuming the data buffer content to its
        entirety.

        Params:
            output = stream to write to
            data = data buffer

        Returns:
            number of bytes transmitted

        Throws:
            EofException on End Of Flow condition (note that the exception is
            always newed)

    ***************************************************************************/

    public size_t writeData ( OutputStream output, void[] data )
    {
        return transmitData(output, data);
    }

    /***************************************************************************

        Reads something from an input stream. Single elements are read straight
        from the input stream, while array types have their length read,
        followed by each element.

        If data is a pointer to a struct or union, it is dereferenced
        automatically.

        Template_Params:
            T = type of data to read

        Params:
            input = input stream to read from
            data = data to read

        Returns:
            number of bytes transmitted

        Throws:
            EofException on End Of Flow condition (note that the exception is
            always newed)

    ***************************************************************************/

    public size_t read ( T ) ( InputStream input, ref T data )
    {
        return transmit(input, data);
    }

    /***************************************************************************

        Reads data from input, populating the data buffer to its entirety.

        Params:
            input = stream to read from
            data = pointer to data buffer
            bytes = length of data in bytes

        Returns:
            number of bytes transmitted

        Throws:
            EofException on End Of Flow condition (note that the exception is
            always newed)

    ***************************************************************************/

    public size_t readData ( InputStream input, void* data, size_t bytes )
    {
        return transmitData(input, data[0..bytes]);
    }

    /***************************************************************************

        Reads data from input, populating the data buffer to its entirety.

        Params:
            input = stream to read from
            data = data buffer

        Returns:
            number of bytes transmitted

        Throws:
            EofException on End Of Flow condition (note that the exception is
            always newed)

    ***************************************************************************/

    public size_t readData ( InputStream input, void[] data )
    {
        return transmitData(input, data);
    }

    /***************************************************************************

        Reads/writes something from/to an io stream. Single elements are
        transmitted straight to the stream, while array types have their length
        transmitted, followed by each element.

        If data is a pointer to a struct or union, it is dereferenced
        automatically.

        Template_Params:
            Stream = type of stream; must be either InputStream or OutputStream
            T = type of data to transmit

        Params:
            stream = stream to read from / write to
            data = data to transmit

        Returns:
            number of bytes transmitted

        Throws:
            EofException on End Of Flow condition (note that the exception is
            always newed)

    ***************************************************************************/

    public size_t transmit ( Stream : IOStream, T ) ( Stream stream, ref T data )
    {
        size_t transmitted = 0;

        static if ( is(T A : A[]) )
        {
            // transmit array length
            static if ( is(Stream : OutputStream) )
            {
                size_t length = data.length;
                transmitted += transmit(stream, length);
            }
            else
            {
                static assert ( is(Stream : InputStream),
                    "stream must be either InputStream or OutputStream, "
                    "not '" ~ Stream.stringof ~ '\'' );

                size_t length;
                transmitted += transmit(stream, length);
                data.length = length;
                enableStomping(data);
            }

            // recursively transmit arrays of arrays
            static if ( is(A B == B[]) )
            {
                foreach ( ref d; data )
                {
                    transmitted += transmit(stream, d);
                }
            }
            else
            {
                transmitted += transmitArrayData(stream, data);
            }
        }
        else static if (is (T A == A*) && (is (A == struct) || is (A == union)))
        {
            transmitted += transmitData(stream, data, A.sizeof);
        }
        // Handle structs with arrays if enabled
        else static if ( is ( T == struct ) && SerializeDynArrays )
        {
            foreach ( i, field; data.tupleof )
            {
                static if ( isStaticArrayType!(typeof(field)) )
                {
                    transmitted += transmitData(stream,
                                                cast(void*)&data.tupleof[i],
                                                typeof(field).sizeof);
                }
                else
                {
                    transmitted += transmit(stream, data.tupleof[i]);
                }
            }
        }
        // handle everything else, including structs if arrays are disabled
        else
        {
            transmitted += transmitData(stream, cast(void*)&data, T.sizeof);
        }

        return transmitted;
    }

    /***************************************************************************

        Reads/writes data from/to an io stream, populating/consuming
        data[0 .. bytes].

        Template_Params:
            Stream = type of stream; must be either InputStream or OutputStream

        Params:
            stream = stream to read from / write to
            data   = pointer to data buffer
            bytes  = data buffer length (bytes)

        Returns:
            number of bytes transmitted

        Throws:
            EofException on End Of Flow condition (note that the exception is
            always newed)

    ***************************************************************************/

    public size_t transmitData ( Stream : IOStream ) ( Stream stream, void* data,
        size_t bytes )
    {
        return transmitData(stream, data[0 .. bytes]);
    }

    /***************************************************************************

        Reads/writes data from/to an io stream, populating/consuming data to its
        entirety.

        Template_Params:
            Stream = type of stream; must be either InputStream or OutputStream

        Params:
            stream = stream to read from / write to
            data = pointer to data buffer

        Returns:
            number of bytes transmitted

        Throws:
            EofException on End Of Flow condition (note that the exception is
            always newed)

    ***************************************************************************/

    public size_t transmitData ( Stream : IOStream ) ( Stream stream, void[] data )
    {
        static assert ( !(is(Stream : InputStream) && is(Stream : OutputStream)),
                        "stream is '" ~ Stream.stringof ~  "; please cast it "
                        "either to InputStream or OutputStream" );

        size_t transmitted = 0;

        while (transmitted < data.length)
        {
            static if ( is(Stream : OutputStream) )
            {
                size_t ret = stream.write(data[transmitted .. $]);

                const act = "writing";
            }
            else
            {
                static assert ( is(Stream : InputStream),
                                "stream must be either InputStream or OutputStream, "
                                "not '" ~ Stream.stringof ~ '\'' );

                size_t ret = stream.read(data[transmitted .. $]);

                const act = "reading";

            }

            enforce!(EofException)(ret != stream.Eof, "end of flow while "
                ~ act ~ " '" ~ stream.conduit.toString() ~ "'");

            transmitted += ret;
        }

        return transmitted;
    }

    /***************************************************************************

        Reads/writes the content of array from/to stream, populating array to
        its entirety.

        Params:
            stream = stream to read from/write to
            array = array to transmit

        Returns:
            number of bytes transmitted

        Throws:
            EofException on End Of Flow condition (note that the exception is
            always newed)

    ***************************************************************************/

    public size_t transmitArrayData ( Stream : IOStream, T = T[] )
        ( Stream stream, T array )
    {
        static if ( is(T U : U[]) )
        {
            return transmitData(stream, cast (void*) array.ptr,
                    array.length * U.sizeof);
        }
        else
        {
            static assert(false,
                "transmitArrayData cannot handle non-array type " ~ T.stringof);
        }
    }
}


/*******************************************************************************

    End Of Flow exception class, thrown when an I/O operation on an IOStream
    results in EOF.

*******************************************************************************/

public class EofException : Exception
{
    import ocean.core.Exception : DefaultExceptionCtor;

    mixin DefaultExceptionCtor;

    version ( UnitTest )
    {
        import ocean.io.device.MemoryDevice;
    }

    /***************************************************************************

        Test that reading from an empty conduit throws an instance of this
        class.

    ***************************************************************************/

    unittest
    {
        auto f = new MemoryDevice;
        int x;
        testThrown!(typeof(this))(SimpleSerializer.read(f, x));
    }
}


version ( UnitTest )
{
    version (UnitTestVerbose) import ocean.io.Stdout;
    import ocean.io.device.MemoryDevice;
    import ocean.core.Test;

    void testSerialization ( T ) ( T write )
    {
        T read;

        scope file = new MemoryDevice;

        SimpleSerializerArrays.write(file, write);
        file.seek(0);

        SimpleSerializerArrays.read(file, read);
        version ( UnitTestVerbose ) Stdout.formatln("Wrote {} to conduit, read {}", write, read);
        test!("==")(read, write, "Error serializing " ~ T.stringof);
    }
}

unittest
{
    version (UnitTestVerbose) Stdout.formatln("Running ocean.io.serialize.SimpleSerializer unittest");

    uint an_int = 23;
    testSerialization(an_int);

    mstring a_string = "hollow world".dup;
    testSerialization(a_string);

    mstring[] a_string_array = ["hollow world".dup, "journey to the centre".dup,
        "of the earth".dup];
    testSerialization(a_string_array);

    // Check structs with arrays
    {
        struct AStruct
        {
            struct Another
            {
                ulong first;
                ushort second;
                char[2] stat;
            }

            Another[] arr;
        }

        auto a_struct =
            AStruct([AStruct.Another(1234,563, "ab"),
                    AStruct.Another(643,53, "ec"),
                    AStruct.Another(567,66, "ef")]);

        AStruct read;

        scope file = new MemoryDevice;

        SimpleSerializerArrays.write(file, a_struct);
        file.seek(0);

        SimpleSerializerArrays.read(file, read);

        test!("==")(a_struct.arr.length, read.arr.length, "Not equal!");
        test!("!=")(a_struct.arr.ptr, read.arr.ptr,
               "Deserialized pointer is the same!");
    }

    version (UnitTestVerbose) Stdout.formatln("done unittest\n");
}
