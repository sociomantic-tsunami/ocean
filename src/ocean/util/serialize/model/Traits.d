/******************************************************************************

    Collection of compile-time traits for serializer/decorator static asserts

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.serialize.model.Traits;

/*******************************************************************************

    Trivial struct used inside trait delegates to check if creation of
    (de)serializer instances is possible and that those have expected API

*******************************************************************************/

private struct _Dummy
{
    const StructVersion = 0;

    int a, b, c;
}

/*******************************************************************************

    Checks if given type statically conforms to the serialization API.

    Any serializer must:

        1. define static `serialize` method that takes two arguemnts : any struct
            and output void[] buffer. It must return the very same buffer slice
            after writing serialized data to it.

        2. define static `countRequiredSize` method that estimates needed size of
            destination buffer for serialization

    Template_Params:
        T = type to check

*******************************************************************************/

template isSerializer(T)
{
    public const isSerializer =
        is(typeof({
            _Dummy input;
            void[] buffer;

            buffer = T.serialize(input, buffer);
            size_t size = T.countRequiredSize(input);
        }));
}

unittest
{
    static assert( isSerializer!(DummySerializer));
    static assert(!isSerializer!(_Dummy));
}

version(UnitTest)
{
    struct DummySerializer
    {
        static void[] serialize(S)(S input, ref void[] buffer)
        {
            return buffer;
        }

        static size_t countRequiredSize(S)(S input)
        {
            return 0;
        }
    }
}

/*******************************************************************************

    Checks if given type statically conforms to the deserialization API.

    Any deserializer must:

        1. define two static `deserialize` methods. One takes single void[]
            argument and deserialized it in-place. Another takes additional
            argument of the same type as return type and uses it tp copy
            deserialized data to.
            Exact return types are implementation-defined but expected to be
            buffer wrappers f some sort.

        2. define static `countRequiredSize` method that calculates size of the
            buffer needed to store deserialized struct instance

    Template_Params:
        T = type to check

*******************************************************************************/

template isDeserializer(T)
{
    public const isDeserializer =
        is(typeof({
            _Dummy input;
            void[] buffer;

            auto a1 = T.deserialize!(_Dummy)(buffer);
            auto a2 = T.deserialize!(_Dummy)(buffer, a1);

            static assert (is(typeof(a1) == typeof(a2)));

            size_t count = T.countRequiredSize!(_Dummy)(buffer);
        }));
}

unittest
{
    static assert( isDeserializer!(DummyDeserializer));
    static assert(!isDeserializer!(_Dummy));
}

version(UnitTest)
{
    struct DummyDeserializer
    {
        static S deserialize(S)(ref void[] buffer)
        {
            return S.init;
        }

        static S deserialize(S)(void[] buffer, ref S copy_buffer)
        {
            return S.init;
        }

        static size_t countRequiredSize(S)(void[] buffer)
        {
            return 0;
        }
    }
}

/*******************************************************************************

    Checks if given type statically conforms to the decorator API.

    "decorator" term is used for an entity that takes care of data exchange
    with external sources (versioning, transport layer etc) while using
    existing (de)serializer for processing the payload.

    It is an abstraction to separate serialization algorithms from any
    additiona storage-related details.

    Any decorator must:

        1. define `Serializer` and `Deserializer` aliases that it uses internally

        2. define `store` method that mirrors Serializer.serialize method
            signature

        3. define two `load` methods that mirror Deserializer.deserialize method
            signatures

    Template_Params:
        T = type to check

*******************************************************************************/

template isDecorator(T)
{
    static if (
           is(typeof({ alias T.Serializer Alias; }))
        && is(typeof({ alias T.Deserializer Alias; }))
    )
    {
        public const isDecorator =
               isSerializer!(T.Serializer)
            && isDeserializer!(T.Deserializer)
            && is(typeof({
                   _Dummy input;
                   void[] buffer;
                   auto decorator = T.init;

                   buffer = decorator.store(input, buffer);

                   auto a1 = decorator.load!(_Dummy)(buffer);
                   auto a2 = decorator.loadCopy!(_Dummy)(buffer, a1);

                   static assert (is(typeof(a1) == typeof(a2)));
               }));
    }
    else
    {
        public const isDecorator = false;
    }
}

unittest
{
    static assert( isDecorator!(DummyDecorator));
    static assert(!isDecorator!(_Dummy));
}

version(UnitTest)
{
    class DummyDecorator
    {
        alias DummySerializer Serializer;
        alias DummyDeserializer Deserializer;

        void[] store(S)(S input, ref void[] buffer)
        {
            return buffer;
        }

        S load(S)(ref void[] buffer)
        {
            return S.init;
        }

        S loadCopy(S)(void[] buffer, ref S copy_buffer)
        {
            return S.init;
        }
    }
}

/*******************************************************************************

    Simple helper to propagate return types of deserializers to derivatiive
    implementations like Decorator. Because return type may depend on input struct
    type such relation can't be expressed via trivial typeof one-liner

    Template_Params:
        D = Deserializer type
        S = deserialized struct type

    Returns:
        alias for the type D will return when deserialiazing S instance

*******************************************************************************/

template DeserializerReturnType(D, S)
{
    static assert (isDeserializer!(D));

    alias
        typeof({
            S input;
            void[] buffer;

            return D.deserialize!(S)(buffer);

        }())
        DeserializerReturnType;
}

unittest
{
    static assert (is(DeserializerReturnType!(DummyDeserializer, _Dummy) == _Dummy));
}
