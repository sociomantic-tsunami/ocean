/*******************************************************************************

    Unit tests for ocean.core.Buffer

    Each test block covers all `Buffer` method and is supposed to be copied and
    adapted for each new element type to test.

    Copyright:
        Copyright (c) 2016-2017 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.Buffer_test;

import ocean.core.Buffer;
import ocean.core.Test;
import ocean.core.TypeConvert : arrayOf;

unittest
{
    // char buffers

    auto buffer = createBuffer("abcd");
    test!("==")(buffer.length, 4);

    buffer.length = 1;
    test!("==")(buffer[], "a");

    buffer.reset();
    test!("==")(buffer[], "");
    test!("!is")(buffer[].ptr, null);

    buffer.reserve(20);
    testNoAlloc({
        buffer ~= 'a';
        buffer ~= "abc";
    } ());
    test!("==")(buffer[], "aabc");

    test!("==")(buffer[1 .. buffer.length], "abc");

    auto old_ptr = buffer[].ptr;
    buffer = "xyz";
    test!("==")(buffer[], "xyz");
    test!("is")(buffer[].ptr, old_ptr);

    buffer[1] = 'b';
    test!("==")(buffer[], "xbz");

    buffer[1 .. 2] = "a";
    test!("==")(buffer[], "xaz");

    buffer = "abcd";
    size_t sum = 0;
    foreach (val; buffer)
    {
        if (val == 'c')
            break;
        sum += cast(int) val;
    }
    test!("==")(sum, 195);

    sum = 0;
    foreach (index, val; buffer)
    {
        if (val == 'c')
            break;
        sum += index;
    }
    test!("==")(sum, 1);
}

unittest
{
    // classes

    static class C
    {
        int x;

        this ( int x )
        {
            this.x = x;
        }

        override int opCmp ( Object _rhs )
        {
            auto rhs = cast(C) _rhs;
            return this.x < rhs.x ? 1
                : this.x > rhs.x ? -1 : 0;
        }

        override equals_t opEquals ( Object rhs )
        {
            return this.opCmp(rhs) == 0;
        }
    }

    static C[] createObjects(int[] arr...)
    {
        C[] result;
        foreach (elem; arr)
            result ~= new C(elem);
        return result;
    }

    auto buffer = createBuffer(createObjects(1, 2, 3));
    test!("==")(buffer.length, 3);

    buffer.length = 1;
    test!("==")(buffer[], createObjects(1));

    buffer.reset();
    test!("==")(buffer[], (C[]).init);
    test!("!is")(buffer[].ptr, null);

    buffer.reserve(20);
    auto c1 = new C(1);
    auto c23 = createObjects(2, 3);
    testNoAlloc({
        buffer ~= c1;
        buffer ~= c23;
    } ());
    test!("==")(buffer[], createObjects(1, 2, 3));

    test!("==")(buffer[1 .. buffer.length], createObjects(2, 3));

    auto old_ptr = buffer[].ptr;
    buffer = createObjects(1, 2, 4);
    test!("==")(buffer[], createObjects(1, 2, 4));
    test!("is")(buffer[].ptr, old_ptr);

    buffer[1] = new C(3);
    test!("==")(buffer[], createObjects(1, 3, 4));

    buffer[1 .. 2] = createObjects(2);
    test!("==")(buffer[], createObjects(1, 2, 4));

    buffer = createObjects(1, 2, 3, 4);
    size_t sum = 0;
    foreach (val; buffer)
    {
        if (val.x == 3)
            break;
        sum += val.x;
    }
    test!("==")(sum, 3);

    sum = 0;
    foreach (index, val; buffer)
    {
        if (val.x == 3)
            break;
        sum += index;
    }
    test!("==")(sum, 1);
}

unittest
{
    // void buffer

    Buffer!(void) buffer;
    buffer = arrayOf!(ubyte)(1, 2, 3, 4);
    test!("==")(buffer.length, 4);

    buffer.length = 1;
    test!("==")(buffer[], arrayOf!(ubyte)(1));

    buffer.reset();
    test!("==")(buffer[], (void[]).init);
    test!("!is")(buffer[].ptr, null);

    buffer.reserve(20);
    auto arr = arrayOf!(ubyte)(1, 2, 3);
    testNoAlloc({
        buffer ~= 42;
        buffer ~= arr;
    } ());
    test!("==")(buffer[], arrayOf!(ubyte)(42, 1, 2, 3));

    test!("==")(buffer[1 .. buffer.length], arrayOf!(ubyte)(1, 2, 3));

    auto old_ptr = buffer[].ptr;
    buffer = arrayOf!(ubyte)(1, 2, 3);
    test!("==")(buffer[], arrayOf!(ubyte)(1, 2, 3));
    test!("is")(buffer[].ptr, old_ptr);

    buffer[1] = 42;
    test!("==")(buffer[], arrayOf!(ubyte)(1, 42, 3));

    buffer[1 .. 2] = arrayOf!(ubyte)(2);
    test!("==")(buffer[], arrayOf!(ubyte)(1, 2, 3));

    buffer = arrayOf!(ubyte)(1, 2, 3, 4);
    size_t sum = 0;
    foreach (val; buffer)
    {
        if (val == 3)
            break;
        sum += val;
    }
    test!("==")(sum, 3);

    sum = 0;
    foreach (index, val; buffer)
    {
        if (val == 3)
            break;
        sum += index;
    }
    test!("==")(sum, 1);
}

