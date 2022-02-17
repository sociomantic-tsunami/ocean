/*******************************************************************************

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/


module ocean.text.util.ClassName;

import ocean.stdc.gnu.string;
import ocean.meta.types.Qualifiers;

string classname ( const(Object) o )
{
    string mod;

    return classname(o, mod);
}

string classname ( const(Object) o, out string mod )
{
    string str = o.classinfo.name;

    const(void)* result = memrchr(str.ptr, '.', str.length);
    const(char)* lastdot = cast(const(char)*) result;

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
