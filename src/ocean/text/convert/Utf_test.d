/*******************************************************************************

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

********************************************************************************/

module ocean.text.convert.Utf_test;

import ocean.transition;
import ocean.text.convert.Utf;
import ocean.core.Test;

unittest
{
    static immutable istring original = "Hello \u262F \u0842 \uEFFF";
    cstring r;
    toString(original, (cstring x) { r ~= x; return x.length; });
    test(original == r);
}

unittest
{
    static immutable wchar[] original = "Hello \u262F \u1666 \uEFFF"w;
    cstring r;
    toString(original, (cstring x) { r ~= x; return x.length; });
    test("Hello \u262F \u1666 \uEFFF" == r);
}

unittest
{
    static immutable dchar[] original = "Hello \u262F \u0842 \uE420"d;
    cstring r;
    toString(original, (cstring x) { r ~= x; return x.length; });
    test("Hello \u262F \u0842 \uE420" == r);
}

unittest
{
    auto s1 = fromString8!(char)("abc", null);
    auto s2 = fromString8!(wchar)("abc", null);
    auto s3 = fromString8!(dchar)("abc", null);

    char[5] buff;
    auto s4 = fromString8("abc", buff);
}
