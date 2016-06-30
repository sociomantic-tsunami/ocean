/******************************************************************************

    Enhancement to VersionDecorator that allows converting through multiple
    struct versions at once. It is kept separate from core implementation
    because additional overhead may be not suitable for real-time apps

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.serialize.contiguous.MultiVersionDecorator;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.stdc.string : memmove;
import ocean.math.Math;

import ocean.core.Enforce,
       ocean.util.container.ConcatBuffer,
       ocean.core.StructConverter : structConvert;

import ocean.util.serialize.Version,
       ocean.util.serialize.model.Traits,
       ocean.util.serialize.model.VersionDecoratorMixins;

import ocean.util.serialize.contiguous.Serializer,
       ocean.util.serialize.contiguous.Deserializer,
       ocean.util.serialize.contiguous.Contiguous,
       ocean.util.serialize.contiguous.model.LoadCopyMixin;

version (UnitTest) import ocean.core.Test;

/*******************************************************************************

    Alternative contiguous version decorator implementation for usage in less
    performance critical applications. Is capable of converting through
    multiple struct versions in one go for added convenience.

    Amount of allowed conversions for single call is set via constructor
    argument, 10 by default

*******************************************************************************/

class VersionDecorator
{
    /***************************************************************************

        Convenience shortcut

    ***************************************************************************/

    public alias VersionDecorator This;

    /**************************************************************************

        NB! This will suppress any compilation errors, comment out during
        development and enable only when commiting.

    **************************************************************************/

    static assert (isDecorator!(This));

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

        Allowed difference between struct versions to be converted in one go

    ***************************************************************************/

    private size_t conversion_limit;

    /***************************************************************************

        Constructor

        Params:
            limit = maximum allowed difference between struct versions
            buffer_size = starting this of convert_buffer, does not really
                matter much in practice because it will quickly grow to the
                maximum required size and stay there

    ***************************************************************************/

    public this (size_t limit = 10, size_t buffer_size = 512)
    {
        this.e = new VersionHandlingException;
        this.conversion_limit =limit;
        this.convert_buffer = new ConcatBuffer!(void)(buffer_size);
    }

    /***************************************************************************

        Common loader implementation mixins

    ***************************************************************************/

    mixin StoreMethod!(Serializer);
    mixin LoadMethod!(Deserializer, This.e);
    mixin LoadCopyMethod!(This.e);
    mixin ConvertMethod!(Serializer, Deserializer);

    /***************************************************************************

        Utility method to convert struct contained in input buffer to needed
        struct version. Converted struct will be stored in the same buffer
        replacing old data.

        You can override this method to change version converting logic.

        Template_Params:
            S = final struct version to get

        Params:
            buffer = input buffer after version bytes have been stripped off,
                will contain resulting struct data after this method exits
            input_version = version that was extracted from buffer

        Returns:
            deserialize() result for the last struct conversion

        Throws:
            VersionHandlingException if can't convert between provided versions

    ***************************************************************************/

    protected Contiguous!(S) handleVersion(S)
        (ref void[] buffer, Version.Type input_version)
    body
    {
        alias Version.Info!(S) VInfo;

        if (abs(input_version - VInfo.number) >= this.conversion_limit)
        {
            this.e.throwCantConvert!(S)(input_version);
        }

        if (input_version == VInfo.number)
        {
            // no conversion is necessary
            return Deserializer.deserialize!(S)(buffer);
        }

        if (input_version > VInfo.number)
        {
            // input is of higher version, need to convert down
            static if (VInfo.next.exists)
            {
                this.handleVersion!(VInfo.next.type)(buffer, input_version);
                return this.convert!(S, VInfo.next.type)(buffer);
            }
            else
            {
                this.e.throwCantConvert!(S)(input_version);
            }
        }

        if (input_version < VInfo.number)
        {
            // input is of lower version, need to convert up
            static if (VInfo.prev.exists)
            {
                this.handleVersion!(VInfo.prev.type)(buffer, input_version);
                return this.convert!(S, VInfo.prev.type)(buffer);
            }
            else
            {
                this.e.throwCantConvert!(S)(input_version);
            }
        }

        assert(0);
    }
}

version(UnitTest)
{
    struct Test1
    {
        struct Version0
        {
            const StructVersion = 0;
            alias Version1 StructNext;

            int a, b;

            mstring[] strarr;
        }

        struct Version1
        {
            const StructVersion = 1;
            alias Version0 StructPrevious;
            alias Version2 StructNext;

            int b, a;

            mstring[] strarr;
        }

        struct Version2
        {
            const StructVersion = 2;
            alias Version1 StructPrevious;

            int a, b, c;

            mstring[] strarr;

            void convert_c(ref Version1 s)
            {
                this.c = s.a + s.b;
            }
        }
    }
}

unittest
{
    // loadCopy

    auto loader = new VersionDecorator();
    auto ver0 = Test1.Version0(42, 43, ["version0".dup]);
    void[] serialized;
    Contiguous!(Test1.Version2) buffer;

    loader.store(ver0, serialized);
    auto ver2 = loader.loadCopy(serialized, buffer);
    
    testNoAlloc({
        auto ver2 = loader.loadCopy(serialized, buffer);
    } ());

    test!("==")(ver2.ptr.a, ver0.a);
    test!("==")(ver2.ptr.b, ver0.b);
    test!("==")(ver2.ptr.c, ver0.a + ver0.b);
    test!("==")(ver2.ptr.strarr, ver0.strarr);
}

unittest
{
    // in-place load

    auto loader = new VersionDecorator();

    auto ver0 = Test1.Version0(42, 43, ["version0".dup]);
    void[] buffer;

    loader.store(ver0, buffer);
    auto ver2 = loader.load!(Test1.Version2)(buffer);

    test!("==")(ver2.ptr.a, ver0.a);
    test!("==")(ver2.ptr.b, ver0.b);
    test!("==")(ver2.ptr.c, ver0.a + ver0.b);
    test!("==")(ver2.ptr.strarr, ver0.strarr);

    void[] buffer2;
    loader.store(*ver2.ptr, buffer2);
    auto ver0_again = loader.load!(Test1.Version0)(buffer2);

}

// error handling

version (UnitTest)
{
    struct Test2
    {
        struct Version3
        {
            int a, b;
            const StructVersion = 3;
        }

        struct VersionHuge
        {
            const StructVersion = 100;
        }
    }
}

unittest
{
    auto loader = new VersionDecorator();

    auto ver0 = Test1.Version0(42, 43, ["version0".dup]);
    void[] buffer;

    // version number difference too big
    loader.store(ver0, buffer);
    testThrown!(VersionHandlingException)(
        loader.load!(Test2.VersionHuge)(buffer)
    );

    // "next" alias is not defined
    loader.store(ver0, buffer);
    testThrown!(VersionHandlingException)(
        loader.load!(Test2.Version3)(buffer)
    );

    // "prev" alias is not defined
    loader.store(Test2.Version3.init, buffer);
    testThrown!(VersionHandlingException)(
        loader.load!(Test1.Version2)(buffer)
    );
}
