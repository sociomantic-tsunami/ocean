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
import ocean.transition;

istring classname ( Const!(Object) o )
{
    istring mod;

    return classname(o, mod);
}

istring classname ( Const!(Object) o, out istring mod )
{
    istring str = o.classinfo.name;

    Const!(void)* result = memrchr(str.ptr, '.', str.length);
    Const!(char)* lastdot = cast(Const!(char)*) result;

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
