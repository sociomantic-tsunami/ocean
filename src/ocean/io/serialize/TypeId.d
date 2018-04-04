/******************************************************************************

    Templates to generate a a hash or a string that describes the binary layout
    of a value type, fully recursing into aggregates.

    The data layout identifier hash is the 64-bit Fnv1a hash value of a string
    that is generated from a struct or union by concatenating the offsets
    and types of each field in order of appearance, recursing into structs,
    unions and function/delegate parameter lists and using the base type of
    enums and typedefs.

    The type identifier of a non-aggregate type is the `.stringof` of that type
    (or its base if it is a `typedef` or `enum`).

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.io.serialize.TypeId;

import ocean.core.Traits;
import ocean.io.digest.Fnv1: StaticFnv1a64, Fnv164Const;
import ocean.transition;

/// Usage example
unittest
{
    static struct S
    {
        mixin(Typedef!(int, `Spam`));

        uint spam;

        static struct T
        {
            enum Eggs : ushort
            {
                Ham = 7
            }

            Eggs eggs;                              // at offset 0
            char[] str;                             // at offset 8
        }

        Spam x;                                     // at offset 0
        T[][5] y;                                   // at offset 8
        Spam delegate ( T ) dg;                     // at offset 88
        T*[float function(Spam, T.Eggs)] a;         // at offset 104
    }

    static immutable id = TypeId!(S);
    static assert(id ==
                  `struct{` ~
                    `0LU` ~ `uint` ~
                    `4LU` ~ `int` ~
                    `8LU` ~ `struct{` ~
                      `0LU` ~ `ushort` ~
                      `8LU` ~ `char[]` ~
                    `}[][5LU]` ~
                    `88LU` ~ `intdelegate(` ~
                      `struct{` ~
                        `0LU` ~ `ushort` ~
                        `8LU` ~ `char[]` ~
                      `}` ~
                    `)` ~
                    `104LU` ~ `struct{` ~
                      `0LU` ~ `ushort` ~
                      `8LU` ~ `char[]` ~
                    `}*[floatfunction(intushort)]` ~
                  `}`);

    static immutable hash = TypeHash!(S);
    static assert(hash == 0x3ff282c0d315761b);
}


/******************************************************************************

    Evaluates to the type identifier of T, fully recursing into structs, unions
    and function/delegate parameter lists. T may be or contain any type except
    a class or interface.

 ******************************************************************************/

template TypeId ( T )
{
    static if (is (T == struct) && !IsTypedef!(T))
    {
        static immutable TypeId = "struct{" ~ AggregateId!(CheckedBaseType!(T)) ~ "}";
    }
    else static if (is (T == union))
    {
        static immutable TypeId = "union{" ~ AggregateId!(CheckedBaseType!(T)) ~ "}";
    }
    else static if (is (T Base : Base[]))
    {
        static if (is (T == Base[]))
        {
            static immutable TypeId = TypeId!(Base) ~ "[]";
        }
        else
        {
            static immutable TypeId = TypeId!(Base) ~ "[" ~ T.length.stringof ~ "]";
        }
    }
    else static if (is (T Base == Base*))
    {
        static if (is (Base Args == function) && is (Base R == return))
        {
            static immutable TypeId = TypeId!(R) ~ "function(" ~ TupleId!(Args) ~ ")";
        }
        else
        {
            static immutable TypeId = TypeId!(Base) ~ "*";
        }
    }
    else static if (is (T    Func == delegate) &&
                    is (Func Args == function) && is (Func R == return))
    {
        static immutable TypeId = TypeId!(R) ~ "delegate(" ~ TupleId!(Args) ~ ")";
    }
    else static if (is (typeof (T.init.values[0]) V) &&
                    is (typeof (T.init.keys[0])   K) &&
                    is (V[K] == T))
    {
        static immutable TypeId = TypeId!(V) ~ "[" ~ TypeId!(K) ~ "]";
    }
    else
    {
        static immutable TypeId = CheckedBaseType!(T).stringof;
    }
}

unittest
{
    static struct Sample
    {
        int[4] arr;
        int a;
        double b;
        char* c;
    }


    static immutable x = TypeId!(Sample);
    static immutable ExpectedSampleStr = `struct{0LUint[4LU]16LUint24LUdouble32LUchar*}`;
    static assert(x == ExpectedSampleStr);

    // This looks like a bug
    mixin(Typedef!(Sample, `NestedTypedef`));
    static assert (TypeId!(NestedTypedef) == `Sample`);

    static struct Bar { NestedTypedef f; }
    static assert(TypeId!(Bar) == `struct{0LUSample}`);

    union Foo { char* ptr; ulong val; }
    static assert(TypeId!(Foo) == `union{0LUchar*0LUulong}`);

    interface IFoo {}
    mixin(Typedef!(IFoo, `DasInterface`));
    static assert (!is(typeof(TypeId!(IFoo))));
    static assert (!is(typeof(TypeId!(DasInterface))));

    mixin(Typedef!(Object, `Klass`));
    static assert (!is(typeof(TypeId!(Object))));
    static assert (!is(typeof(TypeId!(Klass))));
}

/******************************************************************************

    Evaluates to the type hash of T, which is the 64-bit Fnv1a hash of the
    string that would be generated by TypeId!(T).

 ******************************************************************************/

template TypeHash ( T )
{
    static immutable TypeHash = TypeHash!(Fnv164Const.INIT, T);
}

unittest
{
    static struct Sample
    {
        int[4] arr;
        int a;
        double b;
        char* c;
    }

    static immutable hash = TypeHash!(Sample);
    static immutable ExpectedSampleHash = 0x25E3D303374B7838;
    static assert(hash == ExpectedSampleHash);

    // This looks like a bug
    mixin(Typedef!(Sample, `NestedTypedef`));
    static assert (TypeHash!(NestedTypedef) == StaticFnv1a64!(`Sample`));

    static struct Bar { NestedTypedef f; }
    static assert(TypeHash!(Bar) == 0xB3F1A91424ABC725);

    union Foo { char* ptr; ulong val; }
    static assert(TypeHash!(Foo) == 0xC4BD15CE20899C30);

    interface IFoo {}
    mixin(Typedef!(IFoo, `DasInterface`));
    static assert (!is(typeof(TypeHash!(IFoo))));
    static assert (!is(typeof(TypeHash!(DasInterface))));

    mixin(Typedef!(Object, `Klass`));
    static assert (!is(typeof(TypeHash!(Object))));
    static assert (!is(typeof(TypeHash!(Klass))));
}

/******************************************************************************

    Evaluates to the type hash of T, which is the 64-bit Fnv1a hash of the
    string that would be generated by TypeId!(T), using hash as initial hash
    value so that TypeHash!(TypeHash!(A), B) evaluates to the 64-bit Fvn1a hash
    value of TypeId!(A) ~ TypeId!(B).

 ******************************************************************************/

template TypeHash ( ulong hash, T )
{
    static if (is (T == struct) && !IsTypedef!(T))
    {
        static immutable TypeHash = StaticFnv1a64!(AggregateHash!(StaticFnv1a64!(hash, "struct{"), CheckedBaseType!(T)), "}");
    }
    else static if (is (T == union))
    {
        static immutable TypeHash = StaticFnv1a64!(AggregateHash!(StaticFnv1a64!(hash, "union{"), CheckedBaseType!(T)), "}");
    }
    else static if (is (T Base : Base[]))
    {
        static if (is (T == Base[]))
        {
            static immutable TypeHash = StaticFnv1a64!(TypeHash!(hash, Base), "[]");
        }
        else
        {
            static immutable TypeHash = StaticFnv1a64!(TypeHash!(hash, Base), "[" ~ T.length.stringof ~ "]");
        }
    }
    else static if (is (T Base == Base*))
    {
        static if (is (Base Args == function) && is (Base R == return))
        {
            static immutable TypeHash = StaticFnv1a64!(TupleHash!(StaticFnv1a64!(TypeHash!(hash, R), "function("), Args), ")");
        }
        else
        {
            static immutable TypeHash = StaticFnv1a64!(TypeHash!(Base), "*");
        }
    }
    else static if (is (T    Func == delegate) &&
                    is (Func Args == function) && is (Func R == return))
    {
        static immutable TypeHash = StaticFnv1a64!(TupleHash!(StaticFnv1a64!(TypeHash!(hash, R), "delegate("), Args), ")");
    }
    else static if (is (typeof (T.init.values[0]) V) &&
                    is (typeof (T.init.keys[0])   K) &&
                    is (V[K] == T))
    {
        static immutable TypeHash = StaticFnv1a64!(TypeHash!(StaticFnv1a64!(TypeHash!(hash, V), "["), K), "]");
    }
    else
    {
        static immutable TypeHash = StaticFnv1a64!(hash, CheckedBaseType!(T).stringof);
    }
}

/******************************************************************************

    Evaluates to the concatenated type identifiers of the fields of T, starting
    with the n-th field. T must be a struct or union.

 ******************************************************************************/

template AggregateId ( T, size_t n = 0 )
{
    static if (n < T.tupleof.length)
    {
        static immutable AggregateId = T.tupleof[n].offsetof.stringof ~ TypeId!(typeof (T.tupleof[n])) ~ AggregateId!(T, n + 1);
    }
    else
    {
        static immutable AggregateId = "";
    }
}

/******************************************************************************

    Evaluates to the concatenated type identifiers of the elements of T.

 ******************************************************************************/

template TupleId ( T ... )
{
    static if (T.length)
    {
        static immutable TupleId = TypeId!(T[0]) ~ TupleId!(T[1 .. $]);
    }
    else
    {
        static immutable TupleId = "";
    }
}

/******************************************************************************

    Evaluates to the hash value of the type identifiers of the fields of T,
    starting with the n-th field, using hash as initial hash value. T must be a
    struct or union.

 ******************************************************************************/

template AggregateHash ( ulong hash, T, size_t n = 0 )
{
    static if (n < T.tupleof.length)
    {
        static immutable AggregateHash = AggregateHash!(TypeHash!(StaticFnv1a64!(hash, T.tupleof[n].offsetof.stringof), typeof (T.tupleof[n])), T, n + 1);
    }
    else
    {
        static immutable AggregateHash = hash;
    }
}

/******************************************************************************

    Evaluates to the hash value of the concatenated type identifiers of the
    elements of T, using hash as initial hash value.

 ******************************************************************************/

template TupleHash ( ulong hash, T ... )
{
    static if (T.length)
    {
        static immutable TupleHash = TupleHash!(TypeHash!(hash, T[0]), T[1 .. $]);
    }
    else
    {
        static immutable TupleHash = hash;
    }
}

/******************************************************************************

    Aliases the base type of T, if T is a typedef or enum, or T otherwise.
    Recurses into further typedefs/enums if required.
    Veryfies that the aliased type is not a class, pointer, function, delegate
    or associative array (a reference type other than a dynamic array).

 ******************************************************************************/

template CheckedBaseType ( T )
{
    alias BaseType!(T) CheckedBaseType;

    static assert (!(is (CheckedBaseType == class) ||
                     is (CheckedBaseType == interface)), TypeErrorMsg!(T, CheckedBaseType));
}

/******************************************************************************

    Aliases the base type of T, if T is a typedef or enum, or T otherwise.
    Recurses into further typedefs/enums if required.

 ******************************************************************************/

template BaseType ( T )
{
    static if (IsTypedef!(T))
        alias DropTypedef!(T) BaseType;
    else static if (is (T Base == enum))
    {
        alias BaseType!(Base) BaseType;
    }
    else
    {
        alias T BaseType;
    }
}

/******************************************************************************

    Evaluates to an error messsage used by CheckedBaseType.

 ******************************************************************************/

template TypeErrorMsg ( T, Base )
{
    static if (is (T == Base))
    {
        static immutable TypeErrorMsg = Base.stringof ~ " is not supported because it is a class or interface";
    }
    else
    {
        static immutable TypeErrorMsg = T.stringof ~ " is a typedef of " ~ Base.stringof ~ " which is not supported because it is a class or interface";
    }
}


/*******************************************************************************

    Helper template to detect if a given type is a typedef (D1 and D2).

    This bears the same name as the template in `ocean.core.Traits`.
    However, the definition in `Traits` unconditionally returns `false` in D2.
    While it might be suitable for most use cases, here we have to
    explicitly handle `typedef`.

    Params:
        T   = Type to check

*******************************************************************************/

private template IsTypedef (T)
{
    version (D_Version2)
        static immutable IsTypedef = is(T.IsTypedef);
    else
        static immutable IsTypedef = mixin("is(T == typedef)");
}


/*******************************************************************************

   Helper template to get the underlying type of a typedef (D1 and D2).

   This bears the same name as the template in `ocean.core.Traits`.
   However, the definition in `Traits` unconditionally returns `T` in D2.
   While it might be suitable for most use cases, here we have to
   explicitly handle `typedef`.

   Params:
       T   = Typedef for which to get the underlying type

*******************************************************************************/

private template DropTypedef (T)
{
    static assert(IsTypedef!(T),
                  "DropTypedef called on non-typedef type " ~ T.stringof);

    version (D_Version2)
        alias typeof(T.value) DropTypedef;
    else
        mixin("static if (is (T V == typedef))
                alias V DropTypedef;");
}
