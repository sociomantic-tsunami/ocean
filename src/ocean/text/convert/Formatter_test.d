/*******************************************************************************

    Test module for ocean.text.convert.Formatter

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.convert.Formatter_test;

import ocean.core.Test;
import ocean.core.Buffer;
import ocean.text.convert.Formatter;
import ocean.transition;

/// Tests for #120
unittest
{
    static struct Foo
    {
        int i = 0x2A;
        void toString (scope size_t delegate (cstring) sink)
        {
            sink("Hello size_t");
        }
    }

    Foo f;
    test!("==")(format("{}", f), "Hello size_t");

    static struct Bar
    {
        int i = 0x2A;
         void toString (scope size_t delegate (cstring) sink)
        {
            sink("Hello size_t");
        }
        // This one takes precedence
        void toString (scope void delegate (cstring) sink)
        {
            sink("Hello void");
        }
    }

    Bar b;
    test!("==")(format("{}", b), "Hello void");
}

/// Test for Buffer overloads
unittest
{
    Buffer!(char) buff;
    sformat(buff, "{}", 42);
    test!("==")(buff[], "42");
    snformat(buff, "{}", 1000);
    test!("==")(buff[], "10");
}
