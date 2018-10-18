/*******************************************************************************

        Copyright:
            Copyright (c) 2008. Fawzi Mohamed
            Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: July 2008

        Authors: Fawzi Mohamed

*******************************************************************************/
module ocean.math.random.engines.ArraySource;

import ocean.core.Verify;

/*******************************************************************************

    very simple array based source (use with care, some methods in non uniform
    distributions  expect a random source with correct statistics, and could
    loop forever with such a source)

********************************************************************************/
struct ArraySource{
    uint[] a;
    size_t i;
    enum int canCheckpoint=false; // implement?
    enum int canSeed=false;

    static ArraySource opCall(uint[] a,size_t i=0)
    {
        verify(a.length>0,"array needs at least one element");
        ArraySource res;
        res.a=a;
        res.i=i;
        return res;
    }
    uint next(){
        verify(a.length>i,"error, array out of bounds");
        uint el=a[i];
        i=(i+1)%a.length;
        return el;
    }
    ubyte nextB(){
        return cast(ubyte)(0xFF&next);
    }
    ulong nextL(){
        return ((cast(ulong)next)<<32)+cast(ulong)next;
    }
}
