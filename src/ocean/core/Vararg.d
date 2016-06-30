/**
 * The vararg module is intended to facilitate vararg manipulation in D.
 * It should be interface compatible with the C module "stdarg," and the
 * two modules may share a common implementation if possible (as is done
 * here).
 *
 * Copyright:
 *     Public Domain
 *     Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
 *     All rights reserved.
 *
 * License:
 *     Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
 *     See LICENSE_TANGO.txt for details.
 *
 * Authors: Hauke Duden, Walter Bright
 *
 */
module ocean.core.Vararg;

version (DigitalMars) version (X86_64) version = DigitalMarsX64;
version (X86)
{
    alias void* va_list;

    template va_arg(T)
    {
        T va_arg(ref va_list _argptr)
        {
            T arg = *cast(T*)_argptr;
            _argptr = _argptr + ((T.sizeof + int.sizeof - 1) & ~(int.sizeof - 1));
            return arg;
        }
    }
}
else
{
    public import ocean.stdc.stdarg;
}
