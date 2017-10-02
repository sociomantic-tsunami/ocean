/*******************************************************************************

    Copyright:
        Copyright (c) 2009-2016 sociomantic Labs GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

********************************************************************************/

module ocean.text.convert.Float_test;

import ocean.transition;
import ocean.text.convert.Float;
import ocean.core.Test;

unittest
{
    char[64] buff;

    test(format(buff, 1.23f, cstring.init ) == "1.23" );
    test(format(buff, 1.23f, "f" ) == "1.23" );
    test(format(buff, 1.23456789L, "f4") == "1.2346" );
    test(format(buff, 0.0001, "e4") == "1.0000e-04");
    test(format(buff, 0.0001, "e4") == "1.0000e-04");

    // Unlike Layout.floater, 'x' and 'X' aren't handled.
    //test(format(buff, 8400.0, "X") == "0X40C0680000000000");
    test(format(buff, 8400.0, "X") == "8400.00");
}

unittest
{
    char[164] tmp;

    auto f = parse ("nan");
    test(format(tmp, f) == "nan");
    f = parse ("inf");
    test(format(tmp, f) == "inf");
    f = parse ("-nan");
    test(format(tmp, f) == "-nan");
    f = parse (" -inf");
    test(format(tmp, f) == "-inf");

    test(format (tmp, 3.14159, 6) == "3.14159");
    test(format (tmp, 3.14159, 4) == "3.1416");
    test(parse ("3.5") == 3.5);
    test(format(tmp, parse ("3.14159"), 6) == "3.14159");
    test(format(tmp, 0.09999, 2,  0, true) == "1.00e-01");
}
