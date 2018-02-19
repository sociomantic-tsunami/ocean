/*******************************************************************************

    Copyright:
        Copyright (c) 2018 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.meta.values.VisitValue_test;

import ocean.meta.values.VisitValue;
import ocean.meta.traits.Basic;
import ocean.meta.types.Typedef;
import ocean.core.Test;

struct SumIntegers
{
    long sum;

    /// Returns: 'true' if recursion shall continue for this type
    bool visit ( T ) ( T* value )
    {
        static if (isIntegerType!(T))
        {
            sum += *value;
        }

        return true;
    }
}

mixin(Typedef!(int, "MyTypedef"));

class A
{
    int a;
}

class B : A
{
    int b;
}

struct Test1
{
    enum Num
    {
        One,
        Two
    }

    struct Nested
    {
        Num x;
    }

    int[2][] arr;
    byte field;
    long* pfield;
    Nested s;
    MyTypedef td;
    B obj;
}

unittest
{
    Test1 instance;
    instance.arr = [ [ 1, 2 ], [ 3, 4 ] ];
    instance.field = 5;
    instance.pfield = new long;
    *instance.pfield = 6;
    instance.s.x = Test1.Num.One;
    instance.td = 7;
    instance.obj = new B;
    instance.obj.a = 8;
    instance.obj.b = 9;

    SumIntegers visitor;
    visitValue(instance, visitor);
    test!("==")(visitor.sum, 45);
}
