/*******************************************************************************

    Serializer, to be used with the StructSerializer, which converts a struct
    so that a php client can read it

    Serializer, to be used with the StructSerializer in
    ocean.io.serialize.StructSerializer, which dumps a struct to a string.

    Usage example (in conjunction with ocean.io.serialize.StructSerializer):

    ---

        // Example struct to serialize
        struct Data
        {
            struct Id
            {
                char[] name;
                hash_t id;
            }

            Id[] ids;
            char[] name;
            uint count;
            float money;
        }

        // Set up some data in a struct
        Data data;
        test.ids = [Data.Id("hi", 23), Data.Id("hello", 17)];

        // Create serializer object
        scope ser = new PHPStructSerializer!(char)();

        // output buffer
        ubyte[] output;

        // Dump struct to buffer via serializer
        ser.serialize(output, data);

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.serialize.PHPSerializer;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.Array;

import ocean.io.serialize.StructSerializer;

import ocean.core.Traits;

import ocean.core.ExceptionDefinitions;

import ocean.math.Math : pow;

version (UnitTestVerbose) import ocean.io.Stdout;

/*******************************************************************************


*******************************************************************************/

public class PHPSerializer
{
    /***************************************************************************

        Convenience method to serialize a struct.

        Template_Params:
            T = type of struct to serialize

        Params:
            output = string to serialize struct data to
            item = struct to serialize

    ***************************************************************************/

    public void serialize ( T ) ( ref ubyte[] output, ref T item )
    {
        StructSerializer!(true).serialize(&item, this, output);
    }


    /***************************************************************************

        Called at the start of struct serialization - outputs the name of the
        top-level object.

        Params:
            output = string to serialize struct data to
            name = name of top-level object

    ***************************************************************************/

    public void open ( ref ubyte[] output, char[] name )
    {

    }


    /***************************************************************************

        Called at the end of struct serialization

        Params:
            output = string to serialize struct data to
            name = name of top-level object

    ***************************************************************************/

    public void close ( ref ubyte[] output, char[] name )
    {
    }


    /***************************************************************************

        Appends a named item to the output buffer.
        Usually item is taken as it is without any conversion.

        Ulongs are converted using the DPD algorithym which is a compression
        algorithym for BCD

        Note: the main method to use from the outside is the first serialize()
        method above. This method is for the use of the StructSerializer.

        Template_Params:
            T = type of item

        Params:
            output = string to serialize struct data to
            item = item to append
            name = name of item

    ***************************************************************************/

    public void serialize ( T ) ( ref ubyte[] output, ref T item, char[] name )
    {
        static assert ( ! is(T == union) );

        static if ( is(T == union) )
        {
            throw new Exception("union unsupported");
        }
        else static if ( is ( T == ulong ) )
        {
            writeBCD(item, output);
        }
        else
        {
            output ~= (cast(ubyte*) &item)[0 .. T.sizeof];
        }
    }

    /***************************************************************************

        Enum that represents the bits as they are described in the DPD paper,
        see http://web.archive.org/web/20070824053303/http://home.hetnet.nl/mr_1/81/jhm.bonten/computers/bitsandbytes/wordsizes/ibmpde.htm#dense

    ***************************************************************************/

    private enum Bits
    {
        a=0,b,c,d,e,f,g,h,i,j,k,m,
        p=0,q,r,s,t,u,v,w,x,y
    }

    /***************************************************************************

        Writes the given number <num> as DPD encoded BCD number to the buffer
        <output>.

        The first 4 bits are used to specify the length of the array in byte.

        Params:
            num = number to encode to DPD
            output = buffer to write encoded number to

    ***************************************************************************/

    private void writeBCD ( ulong num, ref ubyte[] output )
    {
        // starting with 4 bits for the length
        ubyte index = 4;

        ubyte[11] dpd = 0; // we need max 66.666.. bit
        ubyte[3] bcd; // convert three at a time

        void setBit ( Bits offset, ubyte to = true )
        {
            if ( to != 0)
                dpd[(index+offset)/8] |= 1 << 7-((index+offset) % 8);
        }

        ubyte isSet ( ubyte offset )
        {
            // We divide by 4 because BCD only needs 4 bits and it was easier
            // to just use the first 4 bits of each element of a byte array
            // for the BCD encoding before converting it to DPD
            return !!(bcd[offset/4] & (1 << 3-(offset%4)));
        }

        int i = 0;

        do
        {
            bcd[] = 0;
            // convert three digits to BCD
            for ( int c = 2; c >= 0 && num != 0; c--,i++ )
            {
                // get and convert lowest-order number
                bcd[c] = cast(ubyte) ( num % 10 );
                num = num / 10;
            }

            // pack those three digits using dpd
            // see http://web.archive.org/web/20070824053303/http://home.hetnet.nl/mr_1/81/jhm.bonten/computers/bitsandbytes/wordsizes/ibmpde.htm#dense
            with ( Bits )
            {
                setBit(p, (isSet(a) & isSet(f) & isSet(i)) |
                          (isSet(a) & isSet(j)) |
                           isSet(b) );

                setBit(q, (isSet(a) & isSet(g) & isSet(i)) |
                          (isSet(a) & isSet(k)) |
                           isSet(c) );

                setBit(r, isSet(d));

                setBit(s, (~isSet(a) & isSet(e) & isSet(j)) |
                          (isSet(f) & ~isSet(i)) |
                          (~isSet(a) & isSet(f)) |
                          (isSet(e) & isSet(i)) );

                setBit(t, (~isSet(a) & isSet(e) & isSet(k)) |
                          (isSet(a) & isSet(i)) |
                           isSet(g) );

                setBit(u, isSet(h));

                setBit(v, isSet(a) | isSet(e) | isSet(i));

                setBit(w, (~isSet(e) & isSet(j)) |
                          (isSet(e) & isSet(i)) |
                          isSet(a));

                setBit(x, (~isSet(a) & isSet(k)) |
                          (isSet(a) & isSet(i)) |
                          isSet(e));

                setBit(y, isSet(m));
            }

            // 10 more bits used now
            index += 10;
            ++i;
        }
        while (num);

        ubyte len = index/8 + (index % 8 == 0 ? 0 : 1);

        // write length to the first 4 bits
        dpd[0] |= len << 4;

        assert ( len <= 10, "unexpected DPD array length" );

        output ~= dpd[0 .. len];
    }
    unittest
    {
        scope s = new PHPSerializer;
        ubyte[] output;

        ulong fromDPD ( ubyte[] input )
        {
            ubyte decimal_spot;
            ubyte[3] bcd;
            ulong ret = 0;

            short it;

             // length is in the first three bits
            auto len = cast(ubyte) (input[0] & 0b11110000) >> 4;

            ubyte initial = 4;

            ubyte isSet ( Bits offset )
            {
                return !! (input[(it+offset)/8] &
                          (1 << 7-((it+offset)%8)));
            }

            void set ( ubyte offset, ubyte doSet )
            {
              //  version (UnitTestVerbose) Stdout.formatln("Set {}, {}", offset, doSet);
                if ( doSet != 0 ) bcd[offset/4] |= 1<< 3-offset%4;
            }

            for ( it = initial; it+10 <= len*8 ; it+=10 ) with ( Bits )
            {
              //  version (UnitTestVerbose) Stdout.formatln("It: {}", it);
                set(a, (~isSet(s) & isSet(v) & isSet(w)) |
                       (isSet(t) & isSet(v) & isSet(w) & isSet(x)) |
                       (isSet(v) & isSet(w) & ~isSet(x)));

                set(b, (isSet(p) & isSet(s) & isSet(x)) |
                       (isSet(p) & ~isSet(w)) |
                       (isSet(p) & ~isSet(v)));

                set(c, (isSet(q) & isSet(s) & isSet(x)) |
                       (isSet(q) & ~isSet(w)) |
                       (isSet(q) & ~isSet(v)));

                set(d, isSet(r));

                set(e, (isSet(t) & isSet(v) & ~isSet(w) & isSet(x)) |
                       (isSet(s) & isSet(v) & isSet(w) & isSet(x)) |
                       (~isSet(t) & isSet(v) & isSet(x)));

                set(f, (isSet(p) & isSet(t) & isSet(v) & isSet(w) & isSet(x)) |
                       (isSet(s) & ~isSet(x)) |
                       (isSet(s) & ~isSet(v)));

                set(g, (isSet(q) & isSet(t) & isSet(w)) |
                       (isSet(t) & ~isSet(x)) |
                       (isSet(t) & ~isSet(v)));

                set(h, isSet(u));

                set(i, (isSet(t) & isSet(v) & isSet(w) & isSet(x)) |
                       (isSet(s) & isSet(v) & isSet(w) & isSet(x)) |
                       (isSet(v) & ~isSet(w) & ~isSet(x)));

                set(j, (isSet(p) & ~isSet(s) & ~isSet(t) & isSet(w)) |
                       (isSet(s) & isSet(v) & ~isSet(w) & isSet(x)) |
                       (isSet(p) & isSet(w) & ~isSet(x)) |
                       (~isSet(v) & isSet(w)));

                set(k, (isSet(q) & ~isSet(s) & ~isSet(t) & isSet(v) & isSet(w)) |
                       (isSet(q) & isSet(v) & isSet(w) & ~isSet(x)) |
                       (isSet(t) & isSet(v) & ~isSet(w) & isSet(x)) |
                       (~isSet(v) & isSet(x)));

                set(m, isSet(y));

                ret += bcd[2] * pow(10UL, cast(ulong) decimal_spot++) +
                       bcd[1] * pow(10UL, cast(ulong) decimal_spot++) +
                       bcd[0] * pow(10UL, cast(ulong) decimal_spot++);

            version (UnitTestVerbose) Stdout.formatln("Decoded: {:b}, {}", bcd, bcd);
                bcd[] = 0;
            }

          // version (UnitTestVerbose) Stdout.formatln("Ret: {}", ret);

            return ret;
        }

      /*
        // This loop tests a broad range of numbers coming near the max of
        // ulong. Depending on the numbers used, it might take a bit
        // so it is commented.

        ulong last;
        for ( ulong i = 0; i <= ulong.max; i++ )
        {
            //if (i % 10000 == 0)
         //       version (UnitTestVerbose) Stdout.formatln("========== Testing {} (len: {})", i, output.length);

            output.length = 0;
            s.writeBCD(i, output);


            assert ( output.length != 0, "Output array has length 0" );
            assert(fromDPD(output) == i, "De/En coding failed");

            if ( i + i*0.2 > i )
                i+=i*0.2;

            if ( last > i )
                break;
            else
                last = i;
        }


        version (UnitTestVerbose) Stdout.formatln("Decoded: {}", fromDPD([161,201,156,126,149,35,78,177,5,64]));
        version (UnitTestVerbose) Stdout.formatln("Decoded: {}", fromDPD([126, 215, 96, 69, 133, 176, 4]));

        output.length = 0;
        s.writeBCD(1095216660735, output);
        assert(fromDPD(output) == 1095216660735, "De/En coding failed");
*/
    }

    /***************************************************************************

        Called before a sub-struct is serialized.

        Params:
            output = string to serialize struct data to
            name = name of struct item

    ***************************************************************************/

    public void openStruct ( ref ubyte[] output, char[] name )
    {

    }


    /***************************************************************************

        Called after a sub-struct is serialized.

        Params:
            output = string to serialize struct data to
            name = name of struct item

    ***************************************************************************/

    public void closeStruct ( ref ubyte[] output, char[] name )
    {

    }


    /***************************************************************************

        Appends a named array to the output buffer.
        The length of the array is written as uint, so arrays longer
        than uint.max can't be used.
        This is done because php doesn't support ulongs (only longs)

        Template_Params:
            T = base type of array

        Params:
            output = string to serialize struct data to
            array = array to append
            name = name of array item

    ***************************************************************************/

    public void serializeStaticArray ( T ) ( ref ubyte[] output, char[] name, T[] array )
    {
        uint len = cast(uint) array.length;

        output ~= (cast(ubyte*)array.ptr)[0 .. len];
    }


    /***************************************************************************

        Appends a named array to the output buffer.
        The length of the array is written as uint, so arrays longer
        than uint.max can't be used.
        This is done because php doesn't support ulongs (only longs)

        Template_Params:
            T = base type of array

        Params:
            output = string to serialize struct data to
            array = array to append
            name = name of array item

    ***************************************************************************/

    public void serializeArray ( T ) ( ref ubyte[] output, char[] name, T[] array )
    {
        assert ( array.length <= uint.max, "Array length doesn't fit into uint");
        uint len = cast(uint) array.length;

        output ~= (cast(ubyte*)&len)[0 .. uint.sizeof];
        output ~= (cast(ubyte*)array.ptr)[0 .. len];
    }


    /***************************************************************************

        Called before a struct array is serialized.

        Template_Params:
            T = base type of array

        Params:
            output = string to serialize struct data to
            name = name of struct item
            array = array to append

    ***************************************************************************/

    public void openStructArray ( T ) ( ref ubyte[] output, char[] name, T[] array )
    {
        throw new Exception("openStructArray unsupported");
    }


    /***************************************************************************

        Called after a struct array is serialized.

        Template_Params:
            T = base type of array

        Params:
            output = string to serialize struct data to
            name = name of struct item
            array = array to append

    ***************************************************************************/

    public void closeStructArray ( T ) ( ref ubyte[] output, char[] name, T[] array )
    {
        throw new Exception("closeStructArray unsupported");
    }
}

