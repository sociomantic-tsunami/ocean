/*******************************************************************************

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/


module ocean.text.util.ClassName;

import ocean.transition;

extern (C) private void* memrchr(Const!(void)* s, int c, size_t n);

istring classname ( Const!(Object) o )
{
    istring mod;

    return classname(o, mod);
}

istring classname ( Const!(Object) o, out istring mod )
{
    istring str = o.classinfo.name;

    char* lastdot = cast (char*) memrchr(str.ptr, '.', str.length);

    if (lastdot)
    {
        size_t n = lastdot - str.ptr;

        mod = str[0 .. n];

        return str[n + 1 .. $];
    }
    else
    {
        return str;
    }
}
