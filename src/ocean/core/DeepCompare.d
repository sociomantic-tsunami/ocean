/*******************************************************************************

    Value comparison for structs and arbitrary types.

    Does a deep equality comparison of one type to another.

    'Deep' meaning:
        * The _contents_ of dynamic arrays are compared
        * Types are recursed, allowing multi-dimensional arrays to be compared
        * All members of structs are compared (recursively, if needed).

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.DeepCompare;


/***************************************************************************

    Imports

***************************************************************************/

import ocean.transition;


/***************************************************************************

    Given a type T, returns true if the type contains a struct or
    a floating-point type.

***************************************************************************/

private template needsSpecialCompare(T)
{
    static if ( is(T V : V[]) )
    {
        // T is an array. Strip off all of the [] to get
        // the ultimate element type.

        enum
        {
            needsSpecialCompare = needsSpecialCompare!(V)
        };
    }
    else
    {
        // It's special if it has NaN, or is a struct
        enum
        {
            needsSpecialCompare = is ( typeof (T.nan) )  ||
                                  is ( T == struct )
        };
    }
}

/***************************************************************************

    Compares two values and returns true if they are equal.

    This differs from built-in == in two respects.

        1. Dynamic arrays are compared by value, even when they are struct members.

        2. Floating point numbers which are NaN are considered equal.
           This preserves the important property that deepEquals(x, x) is true
           for all x.

    Classes are compared in the normal way, using opEquals.

    Params:
        a    = Struct to be compared with b
        b    = Struct to be compared with a

    Returns:
        true if equal

***************************************************************************/


public bool deepEquals(T)(T a, T b)
{
    static if ( is (typeof(T.nan)) )
    {
        //pragma(msg, "Comparing float: " ~ T.stringof);

        // Deal with NaN.
        // If x is NaN, then x == x is false
        // So we return true if both a and b are NaN.
        // (In D2, we'd just use "return a is b").

        return a == b  || ( a != a && b != b);
    }
    else static if ( is ( T == struct) )
    {
        //pragma(msg, "Comparing struct: " ~ T.stringof);

        foreach(i, U; typeof(a.tupleof) )
        {
            static if ( needsSpecialCompare!(U) )
            {
                //pragma(msg, "Comparing special element " ~ U.stringof );

                // It is a special type (struct or float),
                // or an array of special types

                if ( !deepEquals(a.tupleof[i], b.tupleof[i]) )
                {
                    return false;
                }
            }
            else
            {
                //pragma(msg, "\t not a special case: " ~ typeof(a.tupleof[i]).stringof);

                if ( a.tupleof[i] != b.tupleof[i] )
                {
                    return false;
                }
            }
        }
        return true;
    }
    else static if ( is(T V : V[]) )
    {
        // T is an array.
        // If it is one of the special cases, we need to
        // do an element-by-element compare.

        static if ( needsSpecialCompare!(V) )
        {
            //pragma(msg, "Comparing element-by-element of array " ~ T.stringof);

            // Compare element-by-element.

            if (a.length != b.length)
            {
                return false;
            }

            foreach ( j, m; a )
            {
                if ( !deepEquals(m, b[j]) )
                    return false;
            }

            return true;
        }
        else
        {
            //pragma(msg, "Simple array compare " ~ T.stringof);

            // Not a special case, we can just use the builtin ==.
            // Note that this works even for the multidimensional case.

            return a == b;
        }
    }
    else
    {
        //pragma(msg, "\t not a special case" ~ T.stringof);
        return a == b;
    }
}


unittest
{
    struct S0
    {
    }

    struct S1
    {
        int [] x;
    }

    struct S2
    {
        S1 [] y;
    }

    struct S3
    {
        S1 [][] z;
    }

    struct S4
    {
       double x;
    }

    struct S5
    {
       double[] x;
    }

    S0 a, b;
    assert(deepEquals(a, b));
    S1 a1, b1;
    a1.x = [ 1, 2, 3];
    b1.x = [ 1, 2, 3];
    assert(a1 !is b1);
    assert(deepEquals(a1, b1));
    assert(a1.x == b1.x);
    S2 a2, b2;
    a2.y = [a1];
    b2.y = [b1];
    assert(deepEquals(a2, b2));
    S3 a3, b3;
    a3.z = [a2.y];
    b3.z = [b2.y];
    assert(deepEquals(a3, b3));
    b3.z = [null];
    assert(!deepEquals(a3, b3));
    S4 a4;
    a4.x = double.nan;
    assert(deepEquals(a4, a4));
    S5 a5;
    a5.x ~= double.nan;
    assert(deepEquals(a5, a5));
}
