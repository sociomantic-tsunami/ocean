/*******************************************************************************

    Functions to help with type conversion.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.TypeConvert;



import ocean.meta.traits.Indirections;
import ocean.meta.types.Qualifiers;
import ocean.meta.types.Function;
import ocean.meta.types.Typedef;

version ( UnitTest ) import ocean.core.Test;


/*******************************************************************************

    Trivial wrapper for a cast from any array to an array of immutable elements
    (e.g. from any string to an immutable string), to make code more readable.
    Its use is only legal if no one else has a reference to the contents of the
    `input` array.  Cf. `std.exception.assumeUnique` in Phobos.

    Params:
        input = slice whose contents to cast to immutable; this reference
            will be nullified to prevent any further access from this
            mutable handle

    Returns:
        slice of immutable elements corresponding to the same segment of
        memory referred to by `input`

    Note:
        D1 does not allow overloading on rvalue vs lvalue, nor does it have
        anything similar to D2's `auto ref` feature.  At the same time, to
        match Phobos semantics we need to nullify the slice that gets cast
        to immutable.  Because of this in D1 `assumeUnique` accepts only
        rvalues: use temporary local variables to assign lvalues if any
        need to be used with `assumeUnique`.

        D2 programs can use lvalues as well as rvalues.

    Credits:
        This function is copied from phobos `std.exception.assumeUnique`
        ((c) Andrei Alexandrescu, Boost license) with minor modifications.

*******************************************************************************/

version (D_Version2) public Immut!(T)[] assumeUnique (T) (T[] input)
{
    return .assumeUnique(input);
}

version (D_Version2) unittest
{
    auto s = assumeUnique("1234".dup);
    static assert(is(typeof(s) == istring));
    test!("==")(s, "1234");
}

public Immut!(T)[] assumeUnique (T) (ref T[] input)
{
    auto tmp = input;
    input = null;
    return cast(Immut!(T)[]) tmp;
}

unittest
{
    auto s1 = "aaa".dup;
    auto s2 = assumeUnique(s1);
    test!("==")(s2, "aaa");
    test!("is")(s1, mstring.init);
}


/*******************************************************************************

    Casts an object of one class to another class. Using this function is safer
    than a plain cast, as it also statically ensures that the variable being
    cast from is a class or an interface.

    Params:
        To = type to cast to (must be a class)
        From = type to cast from (must be a class or interface)
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

    Params:
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

        Params:
            From = type to cast from
            To = type to cast to
            T = type of value being cast (statically checked to be == From)
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

    Params:
        T = type of element of new array
        original = original elements of a type that can be cast to T safely

/******************************************************************************/

template arrayOf (T)
{
    T[] arrayOf (U...) (U original)
    {
        static assert (U.length > 0);
        static assert (!hasIndirections!(U[0]));
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
    static immutable _arrayOf_global_scope = arrayOf!(byte)(1, 2, 3);
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
    static immutable manifest = arrayOf!(long)(42, 44, 46);
    static assert (manifest.length == 3);
    static assert (manifest[0] == 42L);
    static assert (manifest[1] == 44L);
    static assert (manifest[2] == 46L);

    // reject stuff with indirections
    static assert (!is(typeof(arrayOf!(int*)(1000))));
    static assert (!is(typeof(arrayOf!(int)((int[]).init))));
}


/*******************************************************************************

    Generates delegate that stores specified `context` as a delegate context
    pointer and, when called, forwards it to function `F` as a regular argument.

    Intended to be used as a performance optimization hack to create
    no-allocation closures that only need to capture one pointer size argument.

    Params:
        F = function to call when delegate is called, must take exactly one
            void* argument which is the passed context
        context = context pointer to forward to F when resulting delegate is
            called

    Returns:
        forged delegate that can be passed to any API expecting regular `T
        delegate()` where T is the return type of F

*******************************************************************************/

ReturnTypeOf!(F) delegate() toContextDg ( alias F ) ( void* context )
{
    static assert (is(typeof({ F((void*).init); })));

    // This code makes use of two facts:
    //    1) The D ABI allows aggregate methods to be converted to delegates,
    //       such that the delegate context pointer becomes the `this` pointer
    //       of the aggregate
    //    2) The compiler supports explicit modification of the .ptr member of a
    //       delegate, without modifying the existing .functptr.

    static struct Fake
    {
        ReturnTypeOf!(F) method ( )
        {
            void* context = cast(void*) (&this);

            // do real work via provided F function:
            return F(context);
        }
    }

    auto dg = &Fake.init.method;
    dg.ptr = context;
    return dg;
}

///
unittest
{
    static bool done = false;

    static void handler ( void* context )
    {
        test!("==")(cast(size_t) context, 42);
        done = true;
    }

    void delegate() dg = toContextDg!(handler)(cast(void*) 42);
    test!("==")(cast(size_t) dg.ptr, 42);
    dg();
    test(done);
}
