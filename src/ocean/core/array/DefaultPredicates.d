/*******************************************************************************

    Implementation of default predicate function objects used by algorithms
    in `ocean.core.array` package.

    Based on `tango.core.Array` module from Tango library.

    Copyright:
        Copyright (C) 2005-2006 Sean Kelly.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.
    
    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

*******************************************************************************/

module ocean.core.array.DefaultPredicates;

version (UnitTest)
{
    import ocean.core.Test;
    import ocean.transition;
}

struct DefaultPredicates
{
    struct IsEqual ( T )
    {
        static bool opCall( in T p1, in T p2 )
        {
            // FIXME_IN_D2: avoid forcing const methods on objects
            auto _p1 = cast(T) p1;
            auto _p2 = cast(T) p2;

            return !!(_p1 == _p2);
        }
    }


    struct IsLess ( T )
    {
        static bool opCall( in T p1, in T p2 )
        {
            // FIXME_IN_D2: avoid forcing const methods on objects
            auto _p1 = cast(T) p1;
            auto _p2 = cast(T) p2;
            return _p1 < _p2;
        }
    }
}

// Test to enforce that IsEqual work with both
// value and reference types
unittest
{
    class C
    {
        int x;

        mixin (genOpEquals(
        `{
            auto o = cast(typeof(this)) rhs;
            if (o is null) return false;
            return (this.x == o.x);
        }`));
    }

    struct S
    {
        int x;

        mixin (genOpEquals("
        {
            return this.x == rhs.x;
        }
        "));
    }

    auto c1 = new C;
    auto c2 = new C;
    S s1, s2;

    auto r1 = DefaultPredicates.IsEqual!(C)(c1, c2);
    auto r2 = DefaultPredicates.IsEqual!(S)(s1, s2);

    test!("==")(r1, true);
    test!("==")(r2, true);
}
