/*******************************************************************************

    Basic traits allowing to distinguish various types between each other. Any
    more convoluted traits dedicated to specific type kinds should go in
    dedicated modules.

    Copyright:
        Copyright (C) 2017 Sociomantic Labs GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.meta.traits.Basic;

import ocean.meta.types.Qualifiers;
import ocean.meta.types.Typedef;

/*******************************************************************************

    Primitive types are the types from which one or multiple other types cannot
    be derived from using the ``is()`` expression or corresponding template type
    parameter specialisation. The following types are not primitive:
     - arrays (static, dynamic and associative) and pointers,
     - classes structs and unions,
     - delegates, function pointers and functions (function pointer base types),
     - enums and typedefs.

    All other, including arithmetic and character types are primitive. Each
    primitive type is represented by a D keyword.
    ``void`` is a primitive type. Imaginary and complex numbers are considered
    primitive types, too, which may be subject to discussion.

    Params:
        T = type to check

    Returns:
        `true` if `T` is a primitive type

*******************************************************************************/

public template isPrimitiveType ( T )
{
    static immutable isPrimitiveType =
           is(Unqual!(T) == void)
        || is(Unqual!(T) == bool)
        || isIntegerType!(T)
        || isCharType!(T)
        || isFloatingPointType!(T);
}

///
unittest
{
    static assert ( isPrimitiveType!(int));
    static assert (!isPrimitiveType!(int*));
    struct S { }
    static assert (!isPrimitiveType!(S));
}

/*******************************************************************************

    Params:
        T = type to check

    Returns:
        `true` if `T` is one of supported string element types

*******************************************************************************/

public template isCharType ( T )
{
    static immutable bool isCharType =
           is(Unqual!(T) == char)
        || is(Unqual!(T) == wchar)
        || is(Unqual!(T) == dchar);
}

///
unittest
{
    static assert ( isCharType!(wchar));
    static assert ( isCharType!(Const!(char)));
    static assert (!isCharType!(byte));
}

/*******************************************************************************

    Params:
        T = type to check

    Returns:
        `true` if `T` is a built-in signed integer type

*******************************************************************************/

public template isSignedIntegerType ( T )
{
    static immutable bool isSignedIntegerType =
           is(Unqual!(T) == byte)
        || is(Unqual!(T) == short)
        || is(Unqual!(T) == int)
        || is(Unqual!(T) == long);
}

///
unittest
{
    static assert ( isSignedIntegerType!(int));
    static assert ( isSignedIntegerType!(Const!(long)));
    static assert (!isSignedIntegerType!(ubyte));
}

/*******************************************************************************

    Params:
        T = type to check

    Returns:
        `true` if `T` is a built-in unsigned integer type

*******************************************************************************/

public template isUnsignedIntegerType ( T )
{
    static immutable bool isUnsignedIntegerType =
           is(Unqual!(T) == ubyte)
        || is(Unqual!(T) == ushort)
        || is(Unqual!(T) == uint)
        || is(Unqual!(T) == ulong);
}

///
unittest
{
    static assert (!isUnsignedIntegerType!(int));
    static assert ( isUnsignedIntegerType!(ubyte));
    static assert ( isUnsignedIntegerType!(Const!(ulong)));
}

/*******************************************************************************

    Params:
        T = type to check

    Returns:
        `true` if `T` is a built-in integer type

*******************************************************************************/

public template isIntegerType ( T )
{
    static immutable bool isIntegerType =
           isSignedIntegerType!(T)
        || isUnsignedIntegerType!(T);
}

///
unittest
{
    static assert ( isIntegerType!(long));
    static assert ( isIntegerType!(ubyte));
    static assert (!isIntegerType!(char));
}

/*******************************************************************************

    Params:
        T = type to check

    Returns:
        `true` if `T` is a built-in floating point type, excluding
        complex/imaginary ones

*******************************************************************************/

public template isRealType ( T )
{
    static immutable bool isRealType =
           is( Unqual!(T) == float )
        || is( Unqual!(T) == double )
        || is( Unqual!(T) == real );
}

///
unittest
{
    static assert ( isRealType!(double));
    static assert (!isRealType!(long));
    static assert (!isRealType!(cdouble));
}


/*******************************************************************************

    Params:
        T = type to check

    Returns:
        `true` if `T` is a built-in complex floating point type

*******************************************************************************/

public template isComplexType( T )
{
    static immutable bool isComplexType =
           is( Unqual!(T) == cfloat )
        || is( Unqual!(T) == cdouble )
        || is( Unqual!(T) == creal );
}

///
unittest
{
    static assert ( isComplexType!(cdouble));
    static assert ( isComplexType!(Const!(cdouble)));
    static assert (!isComplexType!(double));
}

/*******************************************************************************

    Params:
        T = type to check

    Returns:
        `true` if `T` is a built-in imaginary floating point type

*******************************************************************************/

public template isImaginaryType( T )
{
    static immutable bool isImaginaryType =
           is( Unqual!(T) == ifloat )
        || is( Unqual!(T) == idouble )
        || is( Unqual!(T) == ireal );
}

///
unittest
{
    static assert ( isImaginaryType!(idouble));
    static assert ( isImaginaryType!(Const!(idouble)));
    static assert (!isImaginaryType!(double));
}

/*******************************************************************************

    Params:
        T = type to check

    Returns:
        `true` if `T` is any built-in floating-point type: real, complex, or
        imaginary.

*******************************************************************************/

public template isFloatingPointType( T )
{
    static immutable bool isFloatingPointType =
           isRealType!(T)
        || isComplexType!(T)
        || isImaginaryType!(T);
}

///
unittest
{
    static assert (isFloatingPointType!(double));
    static assert (isFloatingPointType!(ifloat));
}

/*******************************************************************************

    Used by other traits to distinguish between dynamic and static arrays
    instead of plain `bool` values.

    `ArrayKind.NotArray` is explicitly defined to have value `0` so that it can
    be in regular condition, i.e. `static if (isArrayType!(T))`.

*******************************************************************************/

public enum ArrayKind
{
    NotArray    = 0,
    Static      = 1,
    Dynamic     = 2,
    Associative = 3,
}

/*******************************************************************************

    Check if type is an array type and which kind of array it is

    Params:
        T = type to check

    Returns:
        `ArrayKind` value indicating if `T` is an array and if it is, static or
        dynamic

*******************************************************************************/

public template isArrayType ( T )
{
    static if (is(Unqual!(T) U == U[]))
        static immutable isArrayType = ArrayKind.Dynamic;
    else static if (is(Unqual!(T) U : U[]))
        static immutable isArrayType = ArrayKind.Static;
    else static if (is(typeof(T.init.values[0])[typeof(T.init.keys[0])] ==
            Unqual!(T)))
        static immutable isArrayType = ArrayKind.Associative;
    else
        static immutable isArrayType = ArrayKind.NotArray;
}

///
unittest
{
    static assert ( isArrayType!(char[15]) == ArrayKind.Static);
    static assert ( isArrayType!(char[]) == ArrayKind.Dynamic);
    static assert ( isArrayType!(char[][5]) == ArrayKind.Static);
    static assert ( isArrayType!(char) == ArrayKind.NotArray);
    static assert ( isArrayType!(int[int]) == ArrayKind.Associative);
    static assert ( isArrayType!(Const!(int[int])) == ArrayKind.Associative);
    static assert (!isArrayType!(char));
}

unittest
{
    static struct S { }
    static assert (!isArrayType!(S));
    static assert ( isArrayType!(S[5]));
}

/*******************************************************************************

    Params:
        T = static array type

    Returns:
        for static array T[N] returns N

*******************************************************************************/

public template staticArrayLength ( T : U[Dim], U, size_t Dim )
{
    static immutable staticArrayLength = Dim;
}

unittest
{
    static assert (staticArrayLength!(int[][5]) == 5);
    static assert (staticArrayLength!(char[42]) == 42);
    static assert (staticArrayLength!(Immut!(mstring[2])) == 2);
}

/*******************************************************************************

    Params:
        T = type to check

    Returns:
        `true` if `T` is a pointer type.

*******************************************************************************/

template isPointerType ( T )
{
    static if (is(Unqual!(T) U == U*))
        static immutable isPointerType = true;
    else
        static immutable isPointerType = false;
}

///
unittest
{
    static assert ( isPointerType!(void*));
    static assert (!isPointerType!(char[]));
}

unittest
{
    static assert ( isPointerType!(char[]*));
    static assert (!isPointerType!(char*[]));
    static assert ( isPointerType!(Const!(real)*));
    static assert (!isPointerType!(uint));

    class Ham { void* a; }

    static assert (!isPointerType!(Ham));

    union Eggs
    {
        void* a;
        uint  b;
    }

    static assert (!isPointerType!(Eggs));
    static assert ( isPointerType!(Immut!(Eggs*)));

    struct Bacon { }

    static assert (!isPointerType!(Bacon));

    // function pointer is a pointer, but delegate is not:
    void foo () {}
    static void bar () {}
    static assert (!isPointerType!(typeof(&foo)));
    static assert ( isPointerType!(typeof(&bar)));
}

/*******************************************************************************

    Params:
        T = type to check

    Returns:
        `true` if `T` is a struct, class, interface or union

*******************************************************************************/

template isReferenceType ( T )
{
    static immutable isReferenceType =
           isPointerType!(T)
        || is(T == delegate)
        || isArrayType!(T) == ArrayKind.Dynamic
        || isArrayType!(T) == ArrayKind.Associative
        || is(T == class)
        || is(T == interface);
}

///
unittest
{
    struct S { }
    class C { }
    interface I { }

    static assert (!isReferenceType!(S));
    static assert ( isReferenceType!(S*));
    static assert ( isReferenceType!(S[]));
    static assert ( isReferenceType!(C));
    static assert ( isReferenceType!(I));
    static assert ( isReferenceType!(S[C]));
    static assert ( isReferenceType!(void function(int)));

    static void foo ( ) { }
    static assert (!isReferenceType!(typeof(foo)));
}

/*******************************************************************************

    Params:
        T = type to check

    Returns:
        `true` if `T` is a struct, class, interface or union

*******************************************************************************/

template isAggregateType ( T )
{
    static immutable isAggregateType =
           is(T == class)
        || is(T == interface)
        || is(T == struct)
        || is(T == union);
}

///
unittest
{
    struct S { int x; }
    union U { int x; double y; }

    static assert ( isAggregateType!(S));
    static assert ( isAggregateType!(U));
    static assert (!isAggregateType!(S[2]));
}

/*******************************************************************************

    Params:
        T = type to check

    Returns:
        `true` if T is a function, function pointer or delegate

*******************************************************************************/

template isFunctionType ( T )
{
    static immutable bool isFunctionType =
           is(T == function)
        || is(typeof(*T.init) == function)
        || is(T == delegate);
}

///
unittest
{
    void foo1() { }
    auto foo2 = () { };
    static void foo3() { }

    static assert (isFunctionType!(typeof(&foo1)));
    static assert (isFunctionType!(typeof(foo2)));
    static assert (isFunctionType!(typeof(&foo3)));
    static assert (isFunctionType!(typeof(foo3)));
}

unittest
{
    static real func(ref int) { return 0; }
    void nestedFunc() { }
    class C
    {
        real method(ref int) { return 0; }
    }
    auto c = new C;
    auto fp = &func;
    auto dg = &c.method;
    real val;

    static assert ( isFunctionType!(typeof(func)));
    static assert ( isFunctionType!(typeof(nestedFunc)));
    static assert ( isFunctionType!(typeof(C.method)));
    static assert ( isFunctionType!(typeof(fp)));
    static assert ( isFunctionType!(typeof(dg)));
    static assert ( isFunctionType!(real function(ref int)));
    static assert ( isFunctionType!(real delegate(ref int)));
    static assert ( isFunctionType!(typeof((int a) { return a; })));

    static assert (!isFunctionType!(int));
    static assert (!isFunctionType!(typeof(val)));
}

/*******************************************************************************

    Params:
        T = type to check

    Returns:
        `true` if T is a function, function pointer or delegate or callable
        aggregate

*******************************************************************************/

template isCallableType ( T )
{
    static immutable bool isCallableType =
           isFunctionType!(T)
        || is(typeof(&(T.init.opCall)) == delegate);
}

///
unittest
{
    struct S
    {
        void opCall (int) { }
    }

    static assert (isCallableType!(S));
    static assert (isCallableType!(typeof(S.opCall)));
}

/*******************************************************************************

    Used as result type for `isTypedef` trait.

    `None` value is explicitly set to `0` so that it can be used in condition
    like `if(isTypedef!(T))`.

*******************************************************************************/

public enum TypedefKind
{
    /// Not a typedef
    None = 0,
    /// D1 `typedef` keyword
    Keyword,
    /// Emulated by struct
    Struct
}

/*******************************************************************************

    Determines if T is a typedef of some kind

    Template_Params:
        T = type to check

    Evaluates to:
        `TypedefKind` value which is non-zero is T is some typedef

*******************************************************************************/

public template isTypedef (T)
{
    version (D_Version2)
    {
        static if (is(T.IsTypedef))
            static immutable isTypedef = TypedefKind.Struct;
        else
            static immutable isTypedef = TypedefKind.None;
    }
    else
    {
        // use mixin to avoid typedef keyword error from DMD2 when
        // lexing/parsing
        mixin("
        static if (is(T _ == typedef))
            const isTypedef = TypedefKind.Keyword;
        else
            const isTypedef = TypedefKind.None;
        ");
    }
}

unittest
{
    mixin(Typedef!(double, "RealNum"));

    static assert(!isTypedef!(int));
    static assert(!isTypedef!(double));
    static assert( isTypedef!(RealNum));

    version (D_Version2)
        static assert(isTypedef!(RealNum) == TypedefKind.Struct);
    else
        static assert(isTypedef!(RealNum) == TypedefKind.Keyword);
}
