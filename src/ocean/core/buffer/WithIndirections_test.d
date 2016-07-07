/*******************************************************************************

    Class-based tests for Buffer for methods that are normally tested
    as part of main Buffer struct. Those can't be tested for any class T
    used with a Buffer because there is no good reliable way to construct
    a valid instance of arbitrary class (mostly because of invariants).

    Copyright:
        Copyright (c) 2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.buffer.WithIndirections_test;

import ocean.core.Buffer;
import ocean.core.Test;

unittest
{
    Buffer!(C) buffer;
}

unittest
{
    Buffer!(C) buffer;
    buffer = [ new C(1), new C(2) ];
    buffer.reset();
    test!("==")(buffer[], (C[]).init);
    test!("!is")(buffer[].ptr, null);
}

unittest
{
    Buffer!(C) buffer;
    buffer = [ new C(1), new C(2), new C(2) ];
    test!("==")(buffer.length, 3);
}

unittest
{
    Buffer!(C) buffer;
    buffer.length = 1;
    test!("==")(buffer.length, 1);
}

unittest
{
    Buffer!(C) buffer;
    buffer.reserve(20);
    auto to_append1 = [ new C(1), new C(2) ];
    auto to_append2 = new C(1);
    testNoAlloc({
        buffer ~= to_append1;
        buffer ~= to_append2;
     } ());
}

unittest
{
    auto buffer = createBuffer([ new C(1), new C(2) ]);
    test!("==")(buffer[0 .. buffer.length],
        [ new C(1), new C(2) ]);
}

unittest
{
    auto buffer = createBuffer([ new C(1), new C(2) ]);
    test!("==")(buffer[],
        [ new C(1), new C(2) ]);
}
