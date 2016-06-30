/*******************************************************************************

    Functions to help with type conversion.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.TypeConvert;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;
version ( UnitTest ) import ocean.core.Test;

import ocean.core.Tuple;
import ocean.core.Traits;

/*******************************************************************************

    Casts an object of one class to another class. Using this function is safer
    than a plain cast, as it also statically ensures that the variable being
    cast from is a class or an interface.

    Template_Params:
        To = type to cast to (must be a class)
        From = type to cast from (must be a class or interface)

    Params:
        value = object to be cast to type To

    Returns:
        input parameter cast to type To. The returned object may be null if the
        From cannot be downcast to To

*******************************************************************************/

public To downcast ( To, From ) ( From value )
{
    static assert(is(To == class));
    static assert(is(From == class) || is(From == interface));

    return cast(To)value;
}

version ( UnitTest )
{
    class A { }
    class B : A { }
    interface I { }
    class C : I { }
}

unittest
{
    // Basic type does not compile
    static assert(!is(typeof({ int i; downcast!(Object)(i); })));

    // Pointer to object does not compile
    static assert(!is(typeof({ Object* o; downcast!(Object)(o); })));

    // Object compiles
    static assert(is(typeof({ Object o; downcast!(Object)(o); })));

    // Interface compiles
    static assert(is(typeof({ I i; downcast!(Object)(i); })));

    // Downcast succeeds for derived class
    {
        A a = new B;
        B b = downcast!(B)(a);
        test!("!is")(cast(void*)b, null);
    }

    // Downcast succeeds for derived interface
    {
        I i = new C;
        C c = downcast!(C)(i);
        test!("!is")(cast(void*)c, null);
    }

    // Downcast fails for non-derived class
    {
        A a = new B;
        C c = downcast!(C)(a);
        test!("is")(cast(void*)c, null);
    }

    // Downcast fails for non-derived interface
    {
        I i = new C;
        B b = downcast!(B)(i);
        test!("is")(cast(void*)b, null);
    }
}


/*******************************************************************************

    Explicit cast function -- both from and to types must be specified by the
    user and are statically ensured to be correct. This extra security can help
    prevent refactoring errors.

    Usage:
    ---
        int i;
        float f = castFrom!(int).to!(float)(i);
    ---

    Template_Params:
        From = type to cast from

******************************************************************************/

template castFrom ( From )
{

    /*************************************************************************

        Explicit cast function -- both from and to types must be specified by
        the user and are statically ensured to be correct. This extra security
        can help prevent refactoring errors.

        Usage:
        ---
            int i;
            float f = castFrom!(int).to!(float)(i);
        ---

        Template_Params:
            From = type to cast from
            To = type to cast to
            T = type of value being cast (statically checked to be == From)

        Params:
            value = value to be cast to type To

        Returns:
            input parameter cast to type To

    **************************************************************************/

    To to ( To, T ) ( T value )
    {
        static assert(
            is(From == T),
            "the value to cast is not of specified type '" ~ From.stringof ~
            "', it is of type '" ~ T.stringof ~ "'"
        );

        static assert(
            is(typeof(cast(To)value)),
            "can't cast from '" ~ From.stringof ~ "' to '" ~ To.stringof ~ "'"
        );

        return cast(To)value;
    }
}

unittest
{
    // Mismatched From does not compile
    static assert(!is(typeof({ int x; castFrom!(float).to!(char)(x); })));

    // Mismatched but implicitly castable From does not compile
    static assert(!is(typeof({ double x; castFrom!(float).to!(char)(x); })));

    // Illegal cast does not compile
    static assert(!is(typeof({ void* p; castFrom!(void*).to!(int[30])(p); })));

    // Valid case compiles
    static assert(is(typeof({ int x; castFrom!(int).to!(float)(x); })));
}


/*******************************************************************************

    Creates a new array from the elements supplied as function arguments,
    casting each of them to T.

    Template_Params:
        T = type of element of new array

    Params:
        original = original elements of a type that can be cast to T safely

/******************************************************************************/

template arrayOf (T)
{
    T[] arrayOf (U...) (U original)
    {
        static assert (U.length > 0);
        static assert (!hasIndirections!(U));
        static assert (!hasIndirections!(T));

        // workaround for dmd1 semantic analysis bug
        auto unused = original[0];

        static istring generateCast ( )
        {
            istring result = "[ ";

            foreach (i, _; U)
            {
                result ~= "cast(T) original[" ~ i.stringof ~ "]";
                if (i + 1 < U.length)
                    result ~= ", ";
            }

            return result ~ " ]";
        }

        return mixin(generateCast());
    }
}

version (UnitTest)
{
    const _arrayOf_global_scope = arrayOf!(byte)(1, 2, 3);
}

///
unittest
{
    auto arr = arrayOf!(hash_t)(1, 2, 3);
    test!("==")(arr, [ cast(hash_t) 1, 2, 3 ][]); 
}

unittest
{
    // ensure it works with Typedef structs in D2
    mixin (Typedef!(hash_t, "Hash"));
    auto arr = arrayOf!(Hash)(1, 2, 3);

    // ensure it works in CTFE
    const manifest = arrayOf!(long)(42, 44, 46);
    static assert (manifest.length == 3);
    static assert (manifest[0] == 42L);
    static assert (manifest[1] == 44L);
    static assert (manifest[2] == 46L);

    // reject stuff with indirections
    static assert (!is(typeof(arrayOf!(int*)(1000))));
    static assert (!is(typeof(arrayOf!(int)((int[]).init))));
}
