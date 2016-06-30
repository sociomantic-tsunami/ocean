/*******************************************************************************

    Utility to recursively reset fields of struct to their .init value while
    preserving array pointers (their length is set to 0 but memory is kept
    available for further reusage)

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.DeepReset;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.Array;
import ocean.core.Traits;
version(UnitTest) import ocean.core.Test;

/*******************************************************************************

    Template to determine the correct DeepReset function to call dependent on
    the type given.

    Template_Params:
        T = type to deep reset

    Evaluates to:
        aliases function appropriate to T

*******************************************************************************/

public template DeepReset ( T )
{
    static if ( is(T == class) )
    {
        alias ClassDeepReset DeepReset;
    }
    else static if ( is(T == struct) )
    {
        alias StructDeepReset DeepReset;
    }
    else static if ( isAssocArrayType!(T) )
    {
        // TODO: reset associative arrays
        pragma(msg, "Warning: deep reset of associative arrays not yet implemented");
        alias nothing DeepReset;
    }
    else static if ( is(T S : S[]) && is(T S == S[]) )
    {
        alias DynamicArrayDeepReset DeepReset;
    }
    else static if ( is(T S : S[]) && !is(T S == S[]) )
    {
        alias StaticArrayDeepReset DeepReset;
    }
    else
    {
        pragma(msg, "Warning: DeepReset template could not expand for type " ~ T.stringof);
        alias nothing DeepReset;
    }
}



/*******************************************************************************

    Deep reset function for dynamic arrays. To reset a dynamic array set the
    length to 0.

    Params:
        dst = destination array

    Template_Params:
        T = type of array to deep copy

*******************************************************************************/

public void DynamicArrayDeepReset ( T ) ( ref T[] dst )
{
    ArrayDeepReset(dst);
    dst.length = 0;
}



/*******************************************************************************

    Deep reset function for static arrays. To reset a static array go through
    the whole array and set the items to the init values for the type of the
    array.

    Params:
        dst = destination array

    Template_Params:
        T = type of array to deep copy

*******************************************************************************/

public void StaticArrayDeepReset ( T ) ( T[] dst )
{
    ArrayDeepReset(dst);
}



/*******************************************************************************

    Deep reset function for arrays.

    Params:
        dst = destination array

    Template_Params:
        T = type of array to deep copy

*******************************************************************************/

private void ArrayDeepReset ( T ) ( ref T[] dst )
{
    static if ( isAssocArrayType!(T) )
    {
        // TODO: copy associative arrays
        pragma(msg, "Warning: deep reset of associative arrays not yet implemented");
    }
    else static if ( is(T S : S[]) )
    {
        foreach ( i, e; dst )
        {
            static if ( is(T U == U[]) ) // dynamic array
            {
                DynamicArrayDeepReset(dst[i]);
            }
            else // static array
            {
                StaticArrayDeepReset(dst[i]);
            }
        }
    }
    else static if ( is(T == struct) )
    {
        foreach ( i, e; dst )
        {
            StructDeepReset(dst[i]);
        }
    }
    else static if ( is(T == class) )
    {
        foreach ( i, e; dst )
        {
            ClassDeepReset(dst[i]);
        }
    }
    else
    {
        // TODO this probably does not need to be done for a dynamic array
        foreach ( ref item; dst )
        {
            item = item.init;
        }
    }
}



/*******************************************************************************

    Deep reset function for structs.

    Params:
        dst = destination struct

    Template_Params:
        T = type of struct to deep copy

*******************************************************************************/

// TODO: struct & class both share basically the same body, could be shared?

public void StructDeepReset ( T ) ( ref T dst )
{
    static if ( !is(T == struct) )
    {
        static assert(false, "StructDeepReset: " ~ T.stringof ~ " is not a struct");
    }

    foreach ( i, member; dst.tupleof )
    {
        static if ( isAssocArrayType!(typeof(member)) )
        {
            // TODO: copy associative arrays
            pragma(msg, "Warning: deep reset of associative arrays not yet implemented");
        }
        else static if ( is(typeof(member) S : S[]) )
        {
            static if ( is(typeof(member) U == S[]) ) // dynamic array
            {
                DynamicArrayDeepReset(dst.tupleof[i]);
            }
            else // static array
            {
                StaticArrayDeepReset(dst.tupleof[i]);
            }
        }
        else static if ( is(typeof(member) == class) )
        {
            ClassDeepReset(dst.tupleof[i]);
        }
        else static if ( is(typeof(member) == struct) )
        {
            StructDeepReset(dst.tupleof[i]);
        }
        else
        {
            dst.tupleof[i] = dst.tupleof[i].init;
        }
    }
}



/*******************************************************************************

    Deep reset function for dynamic class instances.

    Params:
        dst = destination instance

    Template_Params:
        T = type of class to deep copy

*******************************************************************************/

public void ClassDeepReset ( T ) ( ref T dst )
{
    static if ( !is(T == class) )
    {
        static assert(false, "ClassDeepReset: " ~ T.stringof ~ " is not a class");
    }

    foreach ( i, member; dst.tupleof )
    {
        static if ( isAssocArrayType!(typeof(member)) )
        {
            // TODO: copy associative arrays
            pragma(msg, "Warning: deep reset of associative arrays not yet implemented");
        }
        else static if ( is(typeof(member) S : S[]) )
        {
            static if ( is(typeof(member) U == U[]) ) // dynamic array
            {
                DynamicArrayDeepReset(dst.tupleof[i]);
            }
            else // static array
            {
                StaticArrayDeepReset(dst.tupleof[i]);
            }
        }
        else static if ( is(typeof(member) == class) )
        {
            ClassDeepReset(dst.tupleof[i]);
        }
        else static if ( is(typeof(member) == struct) )
        {
            StructDeepReset(dst.tupleof[i]);
        }
        else
        {
            dst.tupleof[i] = dst.tupleof[i].init;
        }
    }

    // Recurse into super any classes
    static if ( is(T S == super ) )
    {
        foreach ( V; S )
        {
            static if ( !is(V == Object) )
            {
                ClassDeepReset(cast(V)dst);
            }
        }
    }
}



/*******************************************************************************

    unit test for the DeepReset method. Makes a test structure and fills it
    with data before calling reset and making sure it is cleared.

    We first build a basic struct that has both a single sub struct and a
    dynamic array of sub structs. Both of these are then filled along with
    the fursther sub sub struct.

    The DeepReset method is then called. The struct is then confirmed to
    have had it's members reset to the correct values

    TODO Adjust the unit test so it also deals with struct being
    re-initialised to make sure they are not full of old data (~=)

*******************************************************************************/


unittest
{
    struct TestStruct
    {
        int a;
        char[] b;
        int[7] c;

        public struct SubStruct
        {
            int d;
            char[] e;
            char[][] f;
            int[7] g;

            public struct SubSubStruct
            {
                int h;
                char[] i;
                char[][] j;
                int[7] k;

                void InitStructure()
                {
                    this.h = -52;
                    this.i.copy("even even more test text");
                    this.j.length = 3;
                    this.j[0].copy("abc");
                    this.j[1].copy("def");
                    this.j[2].copy("ghi");
                    foreach ( ref item; this.k )
                    {
                        item = 120000;
                    }
                }
            }

            void InitStructure()
            {
                this.d = 32;
                this.e.copy("even more test text");

                this.f.length = 1;
                this.f[0].copy("abc");
                foreach ( ref item; this.g )
                {
                    item = 32400;
                }
            }

            SubSubStruct[] sub_sub_struct;
        }

        SubStruct sub_struct;

        SubStruct[] sub_struct_array;
    }

    TestStruct test_struct;
    test_struct.a = 7;
    test_struct.b.copy("some test");
    foreach ( i, ref item; test_struct.c )
    {
        item = 64800;
    }

    TestStruct.SubStruct sub_struct;
    sub_struct.InitStructure;
    test_struct.sub_struct = sub_struct;
    test_struct.sub_struct_array ~= sub_struct;
    test_struct.sub_struct_array ~= sub_struct;


    TestStruct.SubStruct.SubSubStruct sub_sub_struct;
    sub_sub_struct.InitStructure;
    test_struct.sub_struct_array[0].sub_sub_struct ~= sub_sub_struct;
    test_struct.sub_struct_array[1].sub_sub_struct ~= sub_sub_struct;
    test_struct.sub_struct_array[1].sub_sub_struct ~= sub_sub_struct;
    test_struct.sub_struct.sub_sub_struct ~= sub_sub_struct;
    test_struct.sub_struct.sub_sub_struct ~= sub_sub_struct;

    DeepReset!(TestStruct)(test_struct);

    test!("==")(test_struct.a, 0);
    test!("==")(test_struct.b, ""[]);
    foreach ( item; test_struct.c )
    {
        test!("==")(item, 0);
    }

    test!("==")(test_struct.sub_struct_array.length, 0);

    test!("==")(test_struct.sub_struct.d, 0);
    test!("==")(test_struct.sub_struct.e, ""[]);
    test!("==")(test_struct.sub_struct.f.length, 0);
    foreach ( item; test_struct.sub_struct.g )
    {
        test!("==")(item, 0);
    }

    test!("==")(test_struct.sub_struct.sub_sub_struct.length, 0);

    //Test nested classes.
    class TestClass
    {
        int a;
        char[] b;
        int[2] c;

        public class SubClass
        {
            int d;
            char[] e;
        }

        SubClass s;
    }

    TestClass test_class = new TestClass;
    test_class.s =  test_class.new SubClass;
    test_class.a = 7;
    test_class.b = [];
    test_class.b ~= 't';
    test_class.c[1] = 1;
    test_class.s.d = 5;
    test_class.s.e = [];
    test_class.s.e ~= 'q';

    DeepReset!(TestClass)(test_class);
    test!("==")(test_class.a, 0);
    test!("==")(test_class.b.length, 0);
    test!("==")(test_class.c[1], 0);
    test!("!is")(cast(void*)test_class.s, null);
    test!("==")(test_class.s.d, 0);
    test!("==")(test_class.s.e.length, 0);
}
