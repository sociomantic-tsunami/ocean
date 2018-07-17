module ocean.meta.values.Reset_test;

import ocean.meta.values.Reset;
import ocean.core.array.Mutation;
import ocean.core.Test;

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
                    (&this).h = -52;
                    (&this).i.copy("even even more test text");
                    (&this).j.length = 3;
                    (&this).j[0].copy("abc");
                    (&this).j[1].copy("def");
                    (&this).j[2].copy("ghi");
                    foreach ( ref item; (&this).k )
                    {
                        item = 120000;
                    }
                }
            }

            void InitStructure()
            {
                (&this).d = 32;
                (&this).e.copy("even more test text");

                (&this).f.length = 1;
                (&this).f[0].copy("abc");
                foreach ( ref item; (&this).g )
                {
                    item = 32400;
                }
            }

            SubSubStruct[] sub_sub_struct;
            SubSubStruct[1] sub_sub_static_array;
        }

        SubStruct sub_struct;

        SubStruct[] sub_struct_array;
        int[][1] dynamic_static_array;
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
    test_struct.sub_struct.sub_sub_static_array[0] = sub_sub_struct;

    test_struct.dynamic_static_array[0] = [ 1, 2, 3 ];

    reset(test_struct);

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

    foreach (idx, ref field; test_struct.sub_struct.sub_sub_static_array[0].tupleof)
    {
        test!("==")(field, TestStruct.SubStruct.SubSubStruct.init.tupleof[idx]);
    }

    test!("==")(test_struct.sub_struct.sub_sub_struct.length, 0);
    test!("==")(test_struct.dynamic_static_array[0].length, 0);

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

        SubClass[1] s;
    }

    TestClass test_class = new TestClass;
    test_class.s[0] =  test_class.new SubClass;
    test_class.a = 7;
    test_class.b = [];
    test_class.b ~= 't';
    test_class.c[1] = 1;
    test_class.s[0].d = 5;
    test_class.s[0].e = [];
    test_class.s[0].e ~= 'q';

    reset(test_class);
    test!("==")(test_class.a, 0);
    test!("==")(test_class.b.length, 0);
    test!("==")(test_class.c[1], 0);
    test!("!is")(cast(void*)test_class.s, null);
    test!("==")(test_class.s[0].d, 0);
    test!("==")(test_class.s[0].e.length, 0);
}
