/******************************************************************************

    Decorator that uses contiguous (de)serializer and enhances those with struct
    versioning capabilities, including automatic struct conversion between
    different versions.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.serialize.contiguous.VersionDecorator;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.Enforce,
       ocean.util.container.ConcatBuffer,
       ocean.core.StructConverter : structConvert;

import ocean.util.serialize.Version,
       ocean.util.serialize.model.Traits,
       ocean.util.serialize.model.VersionDecoratorMixins;

import ocean.util.serialize.contiguous.Deserializer,
       ocean.util.serialize.contiguous.Serializer,
       ocean.util.serialize.contiguous.Contiguous,
       ocean.util.serialize.contiguous.model.LoadCopyMixin;

import ocean.text.convert.Format,
       ocean.stdc.string : memmove;

/*******************************************************************************

    Decorator that wraps contiguous (de)serializer and adds struct versioning
    support on top. Similar to VersionDecoratorExample but also with
    `loadCopy` method tuned for `Contiguous!(S)` return type.

*******************************************************************************/

deprecated("Use MultiVersionDecorator instead")
class VersionDecorator
{
    /***************************************************************************

        Convenience shortcut

    ***************************************************************************/

    public alias VersionDecorator This;


    /***************************************************************************

        Aliases for used Serializer / Deserializer implementations as demanded
        by `isDecorator` trait.

    ***************************************************************************/

    public alias .Serializer  Serializer;

    /***************************************************************************

        ditto

    ***************************************************************************/

    public alias .Deserializer Deserializer;

    /***************************************************************************

        Reused exception instance

    ***************************************************************************/

    protected VersionHandlingException e;

    /***************************************************************************

        Constructor

        Params:
            buffer_size = starting this of convert_buffer, does not really
                matter much in practice because it will quickly grow to the
                maximum required size and stay there

    ***************************************************************************/

    public this (size_t buffer_size = 512)
    {
        this.e = new VersionHandlingException;
        this.convert_buffer = new ConcatBuffer!(void)(buffer_size);
    }

    /***************************************************************************

        Check `ocean.util.serialize.model.VersionDecoratorMixins` for
        generic documentation on following methods.

    ***************************************************************************/

    mixin StoreMethod!(Serializer);
    mixin LoadMethod!(Deserializer, This.e);
    mixin HandleVersionMethod!(Deserializer, This.e);
    mixin ConvertMethod!(Serializer, Deserializer);

    /***************************************************************************

        Check `ocean.util.serialize.model.VersionDecoratorMixins` for
        generic documentation on this method.

    ***************************************************************************/

    mixin LoadCopyMethod!(This.e);
}

/*******************************************************************************

    Testing. Decorator can be defined by a simple alias but its functionality needs
    extensive test coverage.

*******************************************************************************/

version(UnitTest):

import ocean.core.Test;

import ocean.core.Array;
import core.memory;

/*******************************************************************************

    No conversion. More extensively covered by (de)serializer base tests in
    package_test.d

*******************************************************************************/

deprecated unittest
{
    struct S
    {
        const StructVersion = 1;

        int    a = 42;
        double b = 2.0;
    }

    auto loader = new VersionDecorator;

    void[] buffer;
    S t;
    loader.store!(S)(t, buffer);

    Contiguous!(S) dst;
    loader.loadCopy!(S)(buffer, dst);

    test!("==")(dst.ptr.a, t.a);
    test!("==")(dst.ptr.b, t.b);

    dst = loader.load!(S)(buffer);

    test!("==")(dst.ptr.a, t.a);
    test!("==")(dst.ptr.b, t.b);
}

/*******************************************************************************

    No conversion. Check non void[] API.

*******************************************************************************/

deprecated unittest
{
    struct S
    {
        const StructVersion = 1;
        int a = 42;
    }

    auto loader = new VersionDecorator;

    ubyte[] buffer;
    S t;
    loader.store!(S)(t, buffer);

    Contiguous!(S) dst;
    loader.loadCopy!(S)(buffer, dst);

    test!("==")(dst.ptr.a, t.a);
}

/*******************************************************************************

    Error handling

*******************************************************************************/

deprecated unittest
{
    auto loader = new VersionDecorator;
    void[] buffer = null;

    // must not accept non-versioned

    struct NoVersion { }
    static assert (!is(typeof(loader.load!(NoVersion)(buffer))));

    // must detect if input size is too small

    struct Dummy { const StructVersion = 1; }

    testThrown!(VersionHandlingException)(loader.load!(Dummy)(buffer));

    Contiguous!(Dummy) dst;
    testThrown!(VersionHandlingException)(
        loader.loadCopy!(Dummy)(buffer, dst));

    // must detect if conversion is not defined

    struct Dummy2 { const StructVersion = 2; }

    loader.store(Dummy2.init, buffer);
    testThrown!(VersionHandlingException)(loader.load!(Dummy)(buffer));

    loader.store(Dummy.init, buffer);
    testThrown!(VersionHandlingException)(loader.load!(Dummy2)(buffer));
}

/*******************************************************************************

    Conversion from higher version, trivial struct

*******************************************************************************/

struct Test1
{
    struct Version1
    {
        const StructVersion = 1;

        alias Version2 StructNext;

        static void convert_a(ref Version2 src, ref Version1 dst)
        {
            dst.a = src.a + 1;
        }

        int a;
    }

    struct Version2
    {
        const StructVersion = 2;

        int a = 42;
    }
}

deprecated unittest
{
    auto loader = new VersionDecorator;

    with (Test1)
    {
        void[] buffer;
        Version2 t;
        loader.store(t, buffer);

        Contiguous!(Version1) dst;
        loader.loadCopy(buffer, dst);
        test!("==")(dst.ptr.a, t.a + 1);

        auto result = loader.load!(Version1)(buffer);
        test!("==")(result.ptr.a, t.a + 1);
    }
}

/*******************************************************************************

    Conversion from lower version, trivial struct

*******************************************************************************/

struct Test2
{
    struct Version1
    {
        const StructVersion = 1;

        int a;
    }

    struct Version2
    {
        const StructVersion = 2;

        alias Version1 StructPrevious;

        static void convert_a(ref Version1 src, ref Version2 dst)
        {
            dst.a = src.a + 1;
        }

        int a = 42;
    }
}

deprecated unittest
{
    auto loader = new VersionDecorator;

    with (Test2)
    {
        void[] buffer;
        Version1 t;
        loader.store(t, buffer);

        Contiguous!(Version2) dst;
        loader.loadCopy(buffer, dst);
        test!("==")(dst.ptr.a, t.a + 1);

        auto result = loader.load!(Version2)(buffer);
        test!("==")(result.ptr.a, t.a + 1);
    }
}

/*******************************************************************************

    Chained bi-directional conversions

*******************************************************************************/

struct Test3
{
    struct Version0
    {
        const ubyte StructVersion = 0;
        alias Version1 StructNext;

        struct Nested0
        {
            int a;
        }

        int a;
        int b;

        Nested0[] nested_arr;
        char[][]  string_arr;

        static Version0 create ()
        {
            Version0 t;

            t.a = 100;
            t.b = -100;
            t.nested_arr = [ Nested0(42), Nested0(43), Nested0(44) ];
            t.string_arr = [ "This".dup, "Is".dup,
                "A".dup, "Freaking".dup, "String!".dup ];

            return t;
        }

        void compare ( NamedTest t, Version0 other )
        {
            foreach (index, ref element; this.tupleof)
            {
                t.test!("==")(element, other.tupleof[index]);
            }
        }

        void compare ( NamedTest t, Version1 other )
        {
            foreach (index, ref element; this.tupleof)
            {
                const name = this.tupleof[index].stringof[
                    rfind(this.tupleof[index].stringof, "."[]) + 1 .. $
                ];

                static if (name == "nested_arr")
                {
                    foreach (i, elem; this.nested_arr)
                    {
                        t.test!("==")(elem.a, other.nested_arr[i].a);
                    }
                }
                else
                    mixin(`test!("==")(element, other.` ~ name ~ `);`);
            }
        }
    }

    struct Version1
    {
        const ubyte StructVersion = 1;
        alias Version0 StructPrevious;
        alias Version2 StructNext;

        struct Nested1
        {
            int a;
            int b;

            static void convert_b ( ref Version0.Nested0 s, ref Nested1 dst )
            {
                dst.b = s.a + 1;
            }
            static void convert_b ( ref Version2.Nested2 s, ref Nested1 dst )
            {
                dst.b = s.a / 2;
            }
        }

        int a;
        int b;
        int c;

        Nested1[] nested_arr;
        char[][]  string_arr;

        static void convert_c ( ref Version0 s, ref Version1 dst )
        {
            dst.c = s.b - s.a;
        }

        static void convert_c ( ref Version2 s, ref Version1 dst )
        {
            dst.c = s.d;
        }

        void compare ( NamedTest t, Version0 other )
        {
            foreach (index, ref member; this.tupleof)
            {
                const name = this.tupleof[index].stringof[
                    rfind(this.tupleof[index].stringof, "."[]) + 1 .. $
                ];

                static if (name == "nested_arr")
                {
                    foreach (i, ref nested; this.nested_arr)
                    {
                        test!("==")(nested.a, other.nested_arr[i].a);
                        test!("==")(nested.b, other.nested_arr[i].a + 1);
                    }
                }
                else static if (name == "c")
                {
                    test!("==")(this.c, other.b - other.a);
                }
                else
                {
                    mixin(`test!("==")(member, other.` ~ name ~ ");");
                }
            }
        }

        void compare ( NamedTest t, Version1 other )
        {
            foreach (index, ref element; this.tupleof)
            {
                t.test!("==")(element, other.tupleof[index]);
            }
        }

        void compare ( NamedTest t, Version2 other )
        {
            foreach (index, ref member; this.tupleof)
            {
                const name = this.tupleof[index].stringof[
                    rfind(this.tupleof[index].stringof, "."[]) + 1 .. $
                ];

                static if (name == "nested_arr")
                {
                    foreach (i, ref nested; this.nested_arr)
                    {
                        test!("==")(nested.a, other.nested_arr[i].a);
                        test!("==")(nested.b, other.nested_arr[i].a / 2);
                    }
                }
                else static if (name == "c")
                {
                    test!("==")(this.c, other.d);
                }
                else
                {
                    mixin(`test!("==")(member, other.` ~ name ~ ");");
                }
            }
        }
    }

    struct Version2
    {
        const ubyte StructVersion = 2;

        alias Version1 StructPrevious;

        struct Nested2
        {
            int a;

            static void convert_a ( ref Version1.Nested1 s, ref Nested2 dst ) { dst.a = s.b * 2; }
        }

        Nested2[] nested_arr;

        int b;
        int a;
        int d;

        char[][] string_arr;

        static void convert_d ( ref Version1 s, ref Version2 dst ) { dst.d = s.c; }

        void compare ( NamedTest t, ref Version0 other )
        {
            assert (false);
        }

        void compare ( NamedTest t, ref Version1 other )
        {
            foreach (index, ref member; this.tupleof)
            {
                const name = this.tupleof[index].stringof[
                    rfind(this.tupleof[index].stringof, "."[]) + 1 .. $
                ];

                static if (name == "nested_arr")
                {
                    foreach (i, ref nested; this.nested_arr)
                    {
                        test!("==")(nested.a, other.nested_arr[i].b * 2);
                    }
                }
                else static if (name == "d")
                {
                    test!("==")(this.d, other.c);
                }
                else
                {
                    mixin(`test!("==")(member, other.` ~ name ~ ");");
                }
            }
        }

        void compare ( NamedTest t, ref Version2 other )
        {
            foreach (index, member; this.tupleof)
            {
                t.test!("==")(member, other.tupleof[index]);
            }
        }
    }
}

deprecated Dst testConv(Src, Dst)(Src src)
{
    auto test = new NamedTest(Src.stringof ~ " -> " ~ Dst.stringof);

    try
    {
        auto loader = new VersionDecorator;
        void[] buffer;

        loader.store(src, buffer);
        auto dst = loader.load!(Dst)(buffer);
        dst.ptr.compare(test, src);

        return *dst.ptr;
    }
    catch (Exception e)
    {
        if (e.classinfo == TestException.classinfo)
            throw e;

        test.msg = Format(
            "Unhandled exception of type {} from {}:{} - '{}'",
            e.classinfo.name,
            e.file,
            e.line,
            getMsg(e)
        );
        test.file = __FILE__;
        test.line = __LINE__;
        throw test;
    }
}

deprecated unittest
{
    with (Test3)
    {
        // internal sanity : exceptions must propagate as NamedTest exceptions
        testThrown!(NamedTest)(
            testConv!(Version0, Version2)(Version0.create())
        );

        auto ver0 = testConv!(Version0, Version0)(Version0.create());
        auto ver1 = testConv!(Version0, Version1)(ver0);
        auto ver2 = testConv!(Version1, Version2)(ver1);
        auto ver1_r = testConv!(Version2, Version1)(ver2);
        auto ver0_r = testConv!(Version1, Version0)(ver1_r);

        testConv!(Version1, Version1)(ver1);
        testConv!(Version2, Version2)(ver2);
    }
}

deprecated Dst testConvMemory(Src, Dst)(Src src)
{
    auto test = new NamedTest(Src.stringof ~ " -> " ~ Dst.stringof);

    Contiguous!(Dst) result;
    auto loader = new VersionDecorator;
    void[] buffer;

    const iterations = 10_000;

    static void storeThenLoad (ref NamedTest test, ref VersionDecorator loader,
                               ref Src src, ref void[] buffer,
                               ref Contiguous!(Dst) result)
    {
        try
        {
            loader.store(src, buffer);
            result = loader.load!(Dst)(buffer);
            //    result.ptr.compare(test, src);
        }
        catch (Exception e)
        {
            if (e.classinfo == TestException.classinfo)
                throw e;

            test.msg = Format(
                "Unhandled exception of type {} from {}:{} - '{}'",
                e.classinfo.name,
                e.file,
                e.line,
                getMsg(e)
                );
            test.file = __FILE__;
            test.line = __LINE__;
            throw test;
        }
    }

    // After 1% of the iterations, memory usage shouldn't grow anymore
    for ( size_t i = 0; i < (iterations / 100); ++i )
    {
        storeThenLoad(test, loader, src, buffer, result);
    }

    // Do the other 99%
    testNoAlloc(
        {
            for ( size_t i = 0; i < iterations - (iterations / 100); ++i )
            {
                storeThenLoad(test, loader, src, buffer, result);
            }
        }());

    return *result.ptr;
}

deprecated unittest
{
    with (Test3)
    {
        // internal sanity : exceptions must propagate as NamedTest exceptions
        testThrown!(NamedTest)(
            testConvMemory!(Version0, Version2)(Version0.create())
        );

        auto ver0 = testConvMemory!(Version0, Version0)(Version0.create());
        auto ver1 = testConvMemory!(Version0, Version1)(ver0);
        auto ver2 = testConvMemory!(Version1, Version2)(ver1);
        auto ver1_r = testConvMemory!(Version2, Version1)(ver2);
        auto ver0_r = testConvMemory!(Version1, Version0)(ver1_r);

        testConvMemory!(Version1, Version1)(ver1);
        testConvMemory!(Version2, Version2)(ver2);
    }
}

/******************************************************************************

    Conversion which replaces struct fields completely

******************************************************************************/

struct Test4
{
    struct Ver0
    {
        const ubyte StructVersion = 0;
        int a;
    }

    struct Ver1
    {
        const ubyte StructVersion = 1;
        alias Test4.Ver0 StructPrevious;

        long b;
        static void convert_b(ref Ver0 rhs, ref Ver1 dst) { dst.b = 42; }
    }
}

deprecated unittest
{
    auto loader = new VersionDecorator;
    void[] buffer;

    auto src = Test4.Ver0(20);
    loader.store(src, buffer);
    auto dst = loader.load!(Test4.Ver1)(buffer);
    test!("==")(dst.ptr.b, 42);
}
