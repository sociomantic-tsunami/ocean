/*******************************************************************************

    Format Explained
    ----------------

    This package implements a binary serialization format useful for efficient
    struct representation in monomorphic environment. All servers are expected to
    have similar enough h/w architecture and software to have identical in-memory
    representation of D structures. It doesn't work as a generic cross-platform
    serialization format.

    Essential idea here is storing all struct instance data (including all data
    transitively accessible via arrays / pointers) in a single contiguous memory
    buffer. Which is exactly the reason why the package is named like that. That
    way deserialization is very fast and doesn't need any memory allocation for
    simple cases - all the deserializer needs to do is to iterate through the
    memory chunk and update internal pointers.

    ``contiguous.Deserializer`` returns a memory buffer wrapped in
    ``Contiguous!(S)`` struct. Such wrapper is guaranteed to conform to the
    contiguity expectation explained above. It is recommended to use it in your
    application instead of plain ``void[]`` for added type safety.

    There are certain practical complications with it that are explained as part of
    ``contiguous.Serializer`` and ``contiguous.Deserializer`` API docs. Those should
    not concern most applications and won't be mentioned in the overview.

    Available Decorators
    --------------------

    ``contiguous.VersionDecorator`` adds struct versioning information to the basic
    binary serialization format. It expects struct definitions with additional
    meta-information available at compile-time and prepends a version number byte
    before the actual data buffer. Upon loading the serialized data, the stored
    version number is compared against the expected one and automatic struct
    conversion is done if needed. It only allows conversion through one version
    increment/decrement at a time.

    ``contiguous.MultiVersionDecorator`` is almost identical to
    plain ``VersionDecorator`` but allows the version increment range to be defined
    in the constructor. Distinct classes are used so that, if incoming data
    accidentally is too old, performance-critical applications will emit an error
    rather than wasting CPU cycles converting through multiple versions.
    For other aplications multi-version implementation should be more convenient.

    API
    ---

    All methods that do deserialization of data (``Deserializer.deserialize``,
    ``VersionDecorator.load``, ``VersionDecorator.loadCopy``) return
    ``Contiguous!(S)`` struct. Lifetime of such struct is identical to lifetime
    of buffer used for deserialization. For 1-argument methods it is that argument,
    for 2-argument ones it is the destination argument.

    To get a detailed overview of serializer API check the modules:

    ``ocean.util.serialize.contiguous.Serializer``
    ``ocean.util.serialize.contiguous.Deserializer``

    To get a detailed overview of decorator API check the mixins used for its
    generation:

    ``ocean.util.serialize.model.VersionDecoratorMixins``
    ``ocean.util.serialize.contiguous.model.LoadCopyMixin``

    Serializer methods are static because they work only with argument state.
    Decorators need to be created as persistent objects because they need an
    intermediate state for version conversions.

    If a method refers to ``DeserializerReturnType!(Deserializer, S)`` as return
    type, you can substitute it with ``Contiguous!(S)`` as it is the return type
    used by existing contiguous deserializer.

    There is also the ``ocean.util.serialize.contiguous.Util`` module which provides
    higher level ``copy`` functions for optimized deep copying of data between
    contiguous structs as well as from normal structs to contiguous ones.

    Recommended Usage
    -----------------

    The contiguous serialization format and the version decorator are primarily
    designed as a way to interchange D structs between different applications
    that may expect different versions of those struct layout.
    It is recommended to completely strip the version information with the help
    of the decorator upon initially reading a record, and to use the resulting
    raw contiguous buffer internally in the application (i.e. in a cache). That
    way you can use any of the serialization/deserialization utilities in the
    application without thinking about the version meta-data

    Typical code pattern for a cache:

        1. Define a ``Cache`` of ``Contiguous!(S)`` elements.

        2. When receiving external data we do
        ``version_decorator.loadCopy!(S)(dht_data, cache_element)``

        3. Use ``contiguous.Util.copy(cache_element, contiguous_instance)`` for
        copying the struct instance if needed

        4. Use ``contiguous_instance.ptr`` to work with deserialized data as if
        it was ``S*``

    It is likely that you will need to change the code to use strongly-typed
    ``Contiguous!(S)`` persistent buffer instead of raw ``void[]`` buffer.
    Possibly multiple such buffers if the old one was reused for different
    struct types. This may result in small memory footprint increase at the
    benefit of better type safety and optimized copy operations.

    You can completely abandon the resulting the ``Contiguous!(S)`` instance and
    use/store the plain ``S*`` instead (retrieved via .ptr getter) which will
    work as long as underlying buffer persists. This is however slightly
    discouraged because if you will need to copy the data later, it
    will be impossible to use optimized version without unsafe explicit casts.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

*******************************************************************************/

module ocean.util.serialize.contiguous.package_;

/******************************************************************************

    Public imports

******************************************************************************/

public import ocean.util.serialize.contiguous.Contiguous,
              ocean.util.serialize.contiguous.Deserializer,
              ocean.util.serialize.contiguous.Serializer,
              ocean.util.serialize.contiguous.Util;

version(UnitTest):

/******************************************************************************

    Test imports

******************************************************************************/

import ocean.transition;
import ocean.core.Test;
import ocean.core.Verify;
import ocean.core.StructConverter;
import ocean.core.DeepCompare;
import ocean.core.Buffer;

/******************************************************************************

    Complex data structure used in most tests

    Some test define more specialized structures as nested types for debugging
    simplicity

******************************************************************************/

struct S
{
    struct S_1
    {
        int a;
        double b;
    }

    struct S_2
    {
        int[]   a;
        int[][] b;
    }

    struct S_3
    {
        float[][2] a;
    }

    struct S_4
    {
        char[][] a;
    }

    S_1 s1;

    S_2 s2;
    S_2[1] s2_static_array;

    S_3 s3;

    S_4[] s4_dynamic_array;

    char[][3] static_of_dynamic;

    char[][2][3][] dynamic_of_static_of_static_of_dynamic;

    union
    {
        int union_a;
        int union_b;
    }

    mixin TypeofThis!();

    /***************************************************************************

        Ensure all dynamic array references in this instance are `null`, which
        they should be if this instance references the output data of
        `Serializer.serialize`.

    ***************************************************************************/

    void testNullReferences ( ) const
    {
        foreach (s2_static_array_element; (&this).s2_static_array)
        {
            testArray!("is")(s2_static_array_element.a, null);
            testArray!("is")(s2_static_array_element.b, null);
        }

        foreach (s3_a_element; (&this).s3.a)
            testArray!("is")(s3_a_element, null);

        testArray!("is")((&this).s4_dynamic_array, null);

        foreach (static_of_dynamic_element; (&this).static_of_dynamic)
            testArray!("is")(static_of_dynamic_element, null);
    }

    /***************************************************************************

        Convenience alias, this template instantiation is used a lot in tests.

    ***************************************************************************/

    alias .trivialDeserialize!(This) trivialDeserialize;

    /***************************************************************************

        Returns the number of bytes the `Serializer` should use to serialise
        this instance.

    ***************************************************************************/

    size_t serialized_length ( ) const
    {
        static size_t s2_length ( ref Const!(S_2) s2 )
        {
            return serialArrayLength(s2.a) + serialArrayLength(s2.b);
        }

        size_t n = This.sizeof;

        n += s2_length((&this).s2);

        foreach (s2_static_array_element; (&this).s2_static_array)
            n += s2_length(s2_static_array_element);

        foreach (s3_a_element; (&this).s3.a)
            n += serialArrayLength(s3_a_element);

        n += serialArrayLength((&this).s4_dynamic_array);
        foreach (s4_dynamic_array_element; (&this).s4_dynamic_array)
            n += serialArrayLength(s4_dynamic_array_element.a);

        foreach (static_of_dynamic_element; (&this).static_of_dynamic)
            n += serialArrayLength(static_of_dynamic_element);

        n += serialArrayLength((&this).dynamic_of_static_of_static_of_dynamic);
        foreach (dynamic_element; (&this).dynamic_of_static_of_static_of_dynamic)
            foreach (static_element; dynamic_element)
                foreach (static_element2; static_element)
                    n += serialArrayLength(static_element2);

        return n;
    }
}

/******************************************************************************

    Returns:
        S instance with fields set to some meaningful values

******************************************************************************/

S defaultS()
{
    S s;

    s.s1.a = 42;
    s.s1.b = 42.42;

    s.s2.a = [ 1, 2, 3, 4 ];
    s.s2.b = [ [ 0 ], [ 20, 21 ], [ 22 ] ];

    structConvert(s.s2, s.s2_static_array[0]);

    s.s3.a[0] = [ 1.0, 2.0 ];
    s.s3.a[1] = [ 100.1, 200.2 ];

    s.s4_dynamic_array = [
        S.S_4([ "aaa".dup, "bbb".dup, "ccc".dup ]),
        S.S_4([ "a".dup, "bb".dup, "ccc".dup, "dddd".dup ]),
        S.S_4([ "".dup ])
    ];

    s.static_of_dynamic[] = [ "a".dup, "b".dup, "c".dup ];

    s.dynamic_of_static_of_static_of_dynamic = [
        [["Die".dup, "Katze".dup], ["tritt".dup, "die".dup], ["Treppe".dup, "krumm.".dup]],
        [["abc".dup, "def".dup], ["ghi".dup, "jkl".dup], ["mno".dup, "pqr".dup]]
    ];

    s.union_a = 42;

    return s;
}

/******************************************************************************

    Does series of tests on `checked` to verify that it is equal to struct
    returned by `defaultS()`


    Params:
        checked = S instance to check for equality
        t = test to check

******************************************************************************/

void testS(NamedTest t, ref S checked)
{
    with (t)
    {
        test!("==")(checked.s1, defaultS().s1);
        test!("==")(checked.s2.a, defaultS().s2.a);
        test!("==")(checked.s2.b, defaultS().s2.b);

        foreach (index, elem; checked.s2_static_array)
        {
            test!("==")(elem.a, defaultS().s2_static_array[index].a);
        }

        foreach (index, elem; checked.s3.a)
        {
            test!("==")(elem, defaultS().s3.a[index]);
        }

        foreach (index, elem; checked.s4_dynamic_array)
        {
            test!("==")(elem.a, defaultS().s4_dynamic_array[index].a);
        }

        test!("==")(checked.static_of_dynamic[],
                    defaultS().static_of_dynamic[]);

        test!("==")(checked.dynamic_of_static_of_static_of_dynamic,
                    defaultS().dynamic_of_static_of_static_of_dynamic);

        test!("==")(checked.union_a, defaultS().union_b);
    }
}

/******************************************************************************

    Sanity test for helper functions

******************************************************************************/

unittest
{
    auto t = new NamedTest("Sanity");
    auto s = defaultS();
    testS(t, s);
}

/******************************************************************************

    Standard workflow

******************************************************************************/

unittest
{
    auto t = new NamedTest("Basic");
    auto s = defaultS();
    void[] buffer;

    Serializer.serialize(s, buffer);
    test!("==")(buffer.length, s.serialized_length);
    S.trivialDeserialize(buffer).testNullReferences();
    auto cont_S = Deserializer.deserialize!(S)(buffer);
    cont_S.enforceIntegrity();
    testS(t, *cont_S.ptr);
}

/******************************************************************************

    Standard workflow, copy version

******************************************************************************/

unittest
{
    auto t = new NamedTest("Basic + Copy");
    auto s = defaultS();
    void[] buffer;

    Serializer.serialize(s, buffer);
    test!("==")(buffer.length, s.serialized_length);
    S.trivialDeserialize(buffer).testNullReferences();
    Contiguous!(S) destination;
    auto cont_S = Deserializer.deserialize(buffer, destination);
    cont_S.enforceIntegrity();

    t.test(cont_S.ptr is destination.ptr);
    testS(t, *cont_S.ptr);
}

/******************************************************************************

    Serialize in-place

******************************************************************************/

unittest
{
    auto t = new NamedTest("In-place serialization");
    auto s = defaultS();
    void[] buffer;

    // create Contiguous!(S) instance first
    Serializer.serialize(s, buffer);
    test!("==")(buffer.length, s.serialized_length);
    S.trivialDeserialize(buffer).testNullReferences();
    auto cont_S = Deserializer.deserialize!(S)(buffer);

    // check that serializations nulls pointers
    auto serialized = Serializer.serialize(cont_S);
    test!("is")(serialized.ptr, cont_S.ptr);
    test!("is")(cont_S.ptr.s4_dynamic_array.ptr, null);
    test!("is")(cont_S.ptr.s2.a.ptr, null);
    test!("is")(cont_S.ptr.s2.b.ptr, null);
}

/******************************************************************************

    Extra unused bytes in source

******************************************************************************/

unittest
{
    auto t = new NamedTest("Basic + Copy");
    auto s = defaultS();
    void[] buffer;

    Serializer.serialize(s, buffer);
    test!("==")(buffer.length, s.serialized_length);
    S.trivialDeserialize(buffer).testNullReferences();

    // emulate left-over bytes from previous deserializations
    buffer.length = buffer.length * 2;

    Contiguous!(S) destination;
    auto cont_S = Deserializer.deserialize(buffer, destination);
    cont_S.enforceIntegrity();

    t.test(cont_S.ptr is destination.ptr);
    testS(t, *cont_S.ptr);
}

/******************************************************************************

    Some arrays set to null

******************************************************************************/

unittest
{
    auto t = new NamedTest("Null Arrays");
    auto s = defaultS();
    s.s2.a = null;
    void[] buffer;

    Serializer.serialize(s, buffer);
    test!("==")(buffer.length, s.serialized_length);
    S.trivialDeserialize(buffer).testNullReferences();
    auto cont_S = Deserializer.deserialize!(S)(buffer);
    cont_S.enforceIntegrity();

    t.test!("==")(cont_S.ptr.s2.a.length, 0);
    auto s_ = cont_S.ptr;      // hijack the invariant
    s_.s2.a = defaultS().s2.a; // revert the difference
    testS(t, *s_);             // check the rest
}

/******************************************************************************

    Nested arrays set to null

******************************************************************************/

unittest
{
    auto t = new NamedTest("Nested Null Arrays");
    auto s = defaultS();
    s.s2.b[0] = null;
    void[] buffer;

    Serializer.serialize(s, buffer);
    test!("==")(buffer.length, s.serialized_length);
    S.trivialDeserialize(buffer).testNullReferences();
    auto cont_S = Deserializer.deserialize!(S)(buffer);
    cont_S.enforceIntegrity();

    t.test!("==")(cont_S.ptr.s2.b[0].length, 0);
    auto s_ = cont_S.ptr;            // hijack the invariant
    s_.s2.b[0] = defaultS().s2.b[0]; // revert the difference
    testS(t, *s_);                   // check the rest
}

/******************************************************************************

    Recursie static arrays

******************************************************************************/

unittest
{
    auto t = new NamedTest("Recursive static");

    struct Outer
    {
        struct Inner
        {
            char[][] a;
        }

        Inner[2][1][1] a;
    }

    Outer s;
    s.a[0][0][0].a = [ "1".dup, "2".dup, "3".dup ];
    s.a[0][0][1].a = [ "1".dup, "2".dup ];

    void[] buffer;
    Serializer.serialize(s, buffer);

    size_t expected_length = s.sizeof;
    foreach (a1; s.a)
        foreach (a2; a1)
            foreach (a3; a2)
                expected_length += serialArrayLength(a3.a);
    test!("==")(buffer.length, expected_length);

    with (*trivialDeserialize!(Outer)(buffer))
        foreach (a1; a)
            foreach (a2; a1)
                foreach (a3; a2)
                    testArray!("is")(a3.a, null);

    auto cont = Deserializer.deserialize!(Outer)(buffer);

    test!("==")(cont.ptr.a[0][0][0].a, s.a[0][0][0].a);
    test!("==")(cont.ptr.a[0][0][1].a, s.a[0][0][1].a);
}

/******************************************************************************

    Partial loading of extended struct

    Ensures that if struct definition has been extended incrementaly one can
    still load old definition from the serialized buffer

******************************************************************************/

unittest
{
    struct Old
    {
        int one;
    }

    struct New
    {
        int one;
        int two;
    }

    auto input = New(32, 42);
    void[] buffer;
    Serializer.serialize(input, buffer);
    auto output = Deserializer.deserialize!(Old)(buffer);

    test!("==")(input.one, output.ptr.one);
}

/******************************************************************************

    Serialization of unions of structs with no dynamic arrays

******************************************************************************/

unittest
{
    struct A { int x; }
    struct B { int[3] arr; }

    struct S
    {
        union
        {
            A a;
            B b;
        };
    }

    void[] buffer;
    auto input = S(A(42));
    Serializer.serialize(input, buffer);
    auto output = Deserializer.deserialize!(S)(buffer);

    test!("==")(output.ptr.a, A(42));

    input.b.arr[] = [0, 1, 2];
    Serializer.serialize(input, buffer);
    output = Deserializer.deserialize!(S)(buffer);

    test!("==")(output.ptr.b.arr[], [0, 1, 2][]);
}

/******************************************************************************

    Serialization of unions of structs with dynamic arrays (fails)

******************************************************************************/

unittest
{
    struct A { int x; }
    struct B { int[] arr; }

    struct S
    {
        union XX
        {
            A a;
            B b;
        };

        XX field;
    }

    void[] buffer;
    S input;

    static assert (!is(typeof(Serializer.serialize(input, buffer))));
}

/******************************************************************************

    Allocation Control

******************************************************************************/

unittest
{
    auto t = new NamedTest("Memory Usage");
    auto s = defaultS();
    void[] buffer;

    Serializer.serialize(s, buffer);
    S.trivialDeserialize(buffer).testNullReferences();
    testNoAlloc(Serializer.serialize(s, buffer));
    auto cont_s = Deserializer.deserialize!(S)(buffer);
    testNoAlloc(Deserializer.deserialize!(S)(buffer));
    buffer = buffer.dup;
    testNoAlloc(Deserializer.deserialize(buffer, cont_s));
}


/******************************************************************************

    Array of const elements

******************************************************************************/

unittest
{
    static struct CS
    {
        cstring s;
    }

    auto cs = CS("Hello world");
    void[] buffer;

    Serializer.serialize(cs, buffer);
    test!("==")(buffer.length, cs.sizeof + serialArrayLength(cs.s));
    with (*trivialDeserialize!(CS)(buffer))
        testArray!("is")(s, null);
    auto new_s = Deserializer.deserialize!(CS)(buffer);
    test!("==")(cs.s, new_s.ptr.s);
}


/******************************************************************************

    Ensure that immutable elements are rejected

******************************************************************************/

version (D_Version2) unittest
{
    static struct IS
    {
        istring s;
    }

    static struct II
    {
        Immut!(int) s;
    }

    IS s1 = IS("Hello world");
    II s2 = II(42);
    void[] buffer1, buffer2;

    /*
     * There is no check for the serializer because it is "okay" to
     * serialize immutable data.
     * Obviously they won't be deserializable but that is where
     * we could break the type system.
     */

    // Uncomment to check error message
    //Deserializer.deserialize!(IS)(buffer1);
    //Deserializer.deserialize!(II)(buffer2);

    static assert(!is(typeof({Deserializer.deserialize!(IS)(buffer1);})),
        "Serializer should reject a struct with 'istring'");
    static assert(!is(typeof({Deserializer.deserialize!(II)(buffer2);})),
        "Deserializer should reject a struct with 'immutable' element");
}

/******************************************************************************

    Ensure that full-const struct can be serialized

******************************************************************************/

unittest
{
    static struct S1
    {
        mstring s;
    }

    static struct S2
    {
        S1[] nested;
    }

    auto s = Const!(S2)([ Const!(S1)("Hello world") ]);
    void[] buffer;

    Serializer.serialize(s, buffer);

    size_t expected_length = s.sizeof + serialArrayLength(s.nested);
    foreach (nested_element; s.nested)
        expected_length += serialArrayLength(nested_element.s);
    test!("==")(buffer.length, expected_length);

    with (*trivialDeserialize!(S2)(buffer))
        testArray!("is")(nested, null);

    auto d = Deserializer.deserialize!(S2)(buffer);
    test(deepEquals(*d.ptr, s));
}

/******************************************************************************

    Const arrays of arrays

******************************************************************************/

struct ConstS
{
    Const!(int) n = 3;
    Const!(char[][]) a = ["Hello", "World"];
    Const!(char[])[2][3] b = [
        ["Die", "Katze"], ["tritt", "die"], ["Treppe", "krumm."]
    ];
}

unittest
{
    void[] buffer;

    ConstS s;

    Serializer.serialize(s, buffer);

    size_t expected_length = s.sizeof + serialArrayLength(s.a);
    foreach (b1; s.b)
        foreach (b2; b1)
            expected_length += serialArrayLength(b2);
    test!("==")(buffer.length, expected_length);

    with (*trivialDeserialize!(ConstS)(buffer))
    {
        testArray!("is")(a, null);
        foreach (b1; b)
            foreach (b2; b1)
                testArray!("is")(b2, null);
    }

    auto cont_S = Deserializer.deserialize!(ConstS)(buffer);
    cont_S.enforceIntegrity();

    test!("==")(cont_S.ptr.n, 3);
    test!("==")(cont_S.ptr.a, ["Hello", "World"]);

    cstring[2][3] b = [
        ["Die", "Katze"], ["tritt", "die"], ["Treppe", "krumm."]
    ];
    test!("==")(cont_S.ptr.b, b);
}

unittest
{
    static struct Inner
    {
        mstring s;
    }

    static struct Outer
    {
        Contiguous!(Inner) inner;
    }

    auto s1 = Inner("abcd".dup);
    Outer s2;
    copy(s1, s2.inner);

    Contiguous!(Outer) s3;
    copy(s2, s3);

    s3.ptr.inner.enforceIntegrity();
    test!("==")(s3.ptr.inner.ptr.s, "abcd");
}

unittest
{
    static struct S
    {
        mstring s;
    }

    auto s = S("abcd".dup);

    Buffer!(void) src;
    Contiguous!(S) dst;

    Serializer.serialize(s, src);
    Deserializer.deserialize(src[], dst);

    test!("==")(dst.ptr.s, "abcd");
}

/*******************************************************************************

    Deserialise `serializer_output` in the trivial way to verify all dynamic
    array slices are `null`.

*******************************************************************************/

static Const!(Struct)* trivialDeserialize ( Struct )
    ( Const!(void)[] serializer_output )
{
    verify(serializer_output.length >= Struct.sizeof);
    return cast(Const!(Struct)*)serializer_output.ptr;
}

/*******************************************************************************

    Returns the number of bytes used to serialise `array`, recursing into the
    elements of `array` if `Element` is a dynamic array type. No recursion is
    done if `Element` is a value type containing dynamic arrays.

*******************************************************************************/

static size_t serialArrayLength ( T : Element[], Element ) ( T array )
{
    size_t n = array.length.sizeof;

    static if (is(Unqual!(Element) Sub == Sub[]))
    {
        foreach (element; array)
            n += serialArrayLength(element);
    }
    else
        n += (array.length * array[0].sizeof);

    return n;
}

/*******************************************************************************

    `testArray!(op)(a, b)` is equivalent to
    `testArray!(op)(cast(Const!(void)[])a, cast(Const!(void)[])b)`, which allows
    for `testArray!(op)(a, null)` avoiding D2 trouble with `typeof(null)`.

*******************************************************************************/

template testArray ( istring op )
{
    alias test!(op, Const!(void)[], Const!(void)[]) testArray;
}
