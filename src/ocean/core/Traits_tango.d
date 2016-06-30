/**
 * The traits module defines tools useful for obtaining detailed compile-time
 * information about a type.  Please note that the mixed naming scheme used in
 * this module is intentional.  Templates which evaluate to a type follow the
 * naming convention used for types, and templates which evaluate to a value
 * follow the naming convention used for functions.
 *
 * Copyright:
 *     Copyright (C) 2005-2006 Sean Kelly.
 *     Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
 *     All rights reserved.
 *
 * License:
 *     Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
 *     See LICENSE_TANGO.txt for details.
 *
 * Authors: Sean Kelly, Fawzi Mohamed, Abscissa
 *
 */
module ocean.core.Traits_tango;

import ocean.core.Tuple;
import ocean.transition;

/**
 * Evaluates to true if T is char[], wchar[], or dchar[].
 */
template isStringType( T )
{
    const bool isStringType = is( T : char[] )  ||
                              is( T : wchar[] ) ||
                              is( T : dchar[] ) ||
                              is( T : istring ) ||
                              is( T : cstring ) ||
                              is( T : mstring );
}

unittest
{
    static assert (isStringType!(dchar[]));
    static assert (isStringType!(istring));
    static assert (isStringType!(cstring));
}

/**
 * Evaluates to true if T is char, wchar, or dchar.
 */
template isCharType( T )
{
    const bool isCharType =
        is( Unqual!(T) == char )
     || is( Unqual!(T) == wchar )
     || is( Unqual!(T) == dchar );
}

unittest
{
    static assert (isCharType!(wchar));
    static assert (isCharType!(Const!(char)));
}


/**
 * Evaluates to true if T is a signed integer type.
 */
template isSignedIntegerType( T )
{
    const bool isSignedIntegerType =
        is( Unqual!(T) == byte )
     || is( Unqual!(T) == short )
     || is( Unqual!(T) == int )
     || is( Unqual!(T) == long );
}

unittest
{
    static assert ( isSignedIntegerType!(int));
    static assert ( isSignedIntegerType!(Const!(long)));
    static assert (!isSignedIntegerType!(ubyte));
}


/**
 * Evaluates to true if T is an unsigned integer type.
 */
template isUnsignedIntegerType( T )
{
    const bool isUnsignedIntegerType =
        is( Unqual!(T) == ubyte )
     || is( Unqual!(T) == ushort )
     || is( Unqual!(T) == uint )
     || is( Unqual!(T) == ulong );
}

unittest
{
    static assert (!isUnsignedIntegerType!(int));
    static assert ( isUnsignedIntegerType!(ubyte));
    static assert ( isUnsignedIntegerType!(Const!(ulong)));
}

/**
 * Evaluates to true if T is a signed or unsigned integer type.
 */
template isIntegerType( T )
{
    const bool isIntegerType = isSignedIntegerType!(T) ||
                               isUnsignedIntegerType!(T);
}

unittest
{
    static assert ( isIntegerType!(long));
    static assert ( isIntegerType!(ubyte));
    static assert (!isIntegerType!(char));
}

/**
 * Evaluates to true if T is a real floating-point type.
 */
template isRealType( T )
{
    const bool isRealType =
        is( Unqual!(T) == float )
     || is( Unqual!(T) == double )
     || is( Unqual!(T) == real );
}

unittest
{
    static assert ( isRealType!(double));
    static assert (!isRealType!(long));
    static assert (!isRealType!(cdouble));
}


/**
 * Evaluates to true if T is a complex floating-point type.
 */
template isComplexType( T )
{
    const bool isComplexType =
        is( Unqual!(T) == cfloat )
     || is( Unqual!(T) == cdouble )
     || is( Unqual!(T) == creal );
}

unittest
{
    static assert ( isComplexType!(cdouble));
    static assert ( isComplexType!(Const!(cdouble)));
    static assert (!isComplexType!(double));
}

/**
 * Evaluates to true if T is an imaginary floating-point type.
 */
template isImaginaryType( T )
{
    const bool isImaginaryType =
        is( Unqual!(T) == ifloat )
     || is( Unqual!(T) == idouble )
     || is( Unqual!(T) == ireal );
}

unittest
{
    static assert ( isImaginaryType!(idouble));
    static assert ( isImaginaryType!(Const!(idouble)));
    static assert (!isImaginaryType!(double));
}

/**
 * Evaluates to true if T is any floating-point type: real, complex, or
 * imaginary.
 */
template isFloatingPointType( T )
{
    const bool isFloatingPointType = isRealType!(T)    ||
                                     isComplexType!(T) ||
                                     isImaginaryType!(T);
}

/**
 * complex type for the given type
 */
template ComplexTypeOf(T){
    static if(is(T==float)||is(T==ifloat)||is(T==cfloat)){
        alias cfloat ComplexTypeOf;
    } else static if(is(T==double)|| is(T==idouble)|| is(T==cdouble)){
        alias cdouble ComplexTypeOf;
    } else static if(is(T==real)|| is(T==ireal)|| is(T==creal)){
        alias creal ComplexTypeOf;
    } else static assert(0,"unsupported type in ComplexTypeOf "~T.stringof);
}

unittest
{
    static assert (is(ComplexTypeOf!(float) == cfloat));
    static assert (is(ComplexTypeOf!(idouble) == cdouble));
    static assert (is(ComplexTypeOf!(creal) == creal));
}

/**
 * real type for the given type
 */
template RealTypeOf(T){
    static if(is(T==float)|| is(T==ifloat)|| is(T==cfloat)){
        alias float RealTypeOf;
    } else static if(is(T==double)|| is(T==idouble)|| is(T==cdouble)){
        alias double RealTypeOf;
    } else static if(is(T==real)|| is(T==ireal)|| is(T==creal)){
        alias real RealTypeOf;
    } else static assert(0,"unsupported type in RealTypeOf "~T.stringof);
}

unittest
{
    static assert (is(RealTypeOf!(float) == float));
    static assert (is(RealTypeOf!(idouble) == double));
    static assert (is(RealTypeOf!(creal) == real));
}

/**
 * imaginary type for the given type
 */
template ImaginaryTypeOf(T){
    static if(is(T==float)|| is(T==ifloat)|| is(T==cfloat)){
        alias ifloat ImaginaryTypeOf;
    } else static if(is(T==double)|| is(T==idouble)|| is(T==cdouble)){
        alias idouble ImaginaryTypeOf;
    } else static if(is(T==real)|| is(T==ireal)|| is(T==creal)){
        alias ireal ImaginaryTypeOf;
    } else static assert(0,"unsupported type in ImaginaryTypeOf "~T.stringof);
}

unittest
{
    static assert (is(ImaginaryTypeOf!(float) == ifloat));
    static assert (is(ImaginaryTypeOf!(idouble) == idouble));
    static assert (is(ImaginaryTypeOf!(creal) == ireal));
}

/// type with maximum precision
template MaxPrecTypeOf(T){
    static if (isComplexType!(T)){
        alias creal MaxPrecTypeOf;
    } else static if (isImaginaryType!(T)){
        alias ireal MaxPrecTypeOf;
    } else {
        alias real MaxPrecTypeOf;
    }
}

unittest
{
    static assert (is(MaxPrecTypeOf!(cfloat) == creal));
    static assert (is(MaxPrecTypeOf!(idouble) == ireal));
    static assert (is(MaxPrecTypeOf!(real) == real));
}

/**
 * Evaluates to true if T is a pointer type.
 */
template isPointerType(T)
{
        const isPointerType = false;
}

template isPointerType(T : T*)
{
        const isPointerType = true;
}

unittest
{
    static assert( isPointerType!(void*) );
    static assert( !isPointerType!(char[]) );
    static assert( isPointerType!(char[]*) );
    static assert( !isPointerType!(char*[]) );
    static assert( isPointerType!(real*) );
    static assert( !isPointerType!(uint) );

    class Ham
    {
        void* a;
    }

    static assert( !isPointerType!(Ham) );

    union Eggs
    {
        void* a;
        uint  b;
    }

    static assert( !isPointerType!(Eggs) );
    static assert( isPointerType!(Eggs*) );

    struct Bacon {}

    static assert( !isPointerType!(Bacon) );
}

/**
 * Evaluates to true if T is a a pointer, class, interface, or delegate.
 */
template isReferenceType( T )
{

    const bool isReferenceType = isPointerType!(T)  ||
                               is( T == class )     ||
                               is( T == interface ) ||
                               is( T == delegate );
}

unittest
{
    class Test1 { }
    static assert (isReferenceType!(Test1));

    interface Test2 { }
    static assert (isReferenceType!(Test2));

    alias void delegate() Test3;
    static assert (isReferenceType!(Test3));
}


/**
 * Evaulates to true if T is a dynamic array type.
 */
template isDynamicArrayType( T )
{
    const bool isDynamicArrayType = is( typeof(T.init[0])[] == T );
}

unittest
{
    static assert ( isDynamicArrayType!(int[]));
    static assert (!isDynamicArrayType!(int[2]));
    static assert (!isDynamicArrayType!(int));

    static assert (!isDynamicArrayType!(char[5][2]));
}

/**
 * Evaluates to true if T is a static array type.
 */
template isStaticArrayType( T : T[U], size_t U )
{
    const bool isStaticArrayType = true;
}

template isStaticArrayType( T )
{
    const bool isStaticArrayType = false;
}

unittest
{
    static assert (!isStaticArrayType!(int[]));
    static assert ( isStaticArrayType!(int[2]));
    static assert (!isStaticArrayType!(int));

    static assert ( isStaticArrayType!(char[5][2]));
}

/// true for array types
template isArrayType(T)
{
    static if (is( T U : U[] ))
        const bool isArrayType=true;
    else
        const bool isArrayType=false;
}

unittest
{
    static assert ( isArrayType!(char[5][2]));
    static assert ( isArrayType!(char[15]));
    static assert ( isArrayType!(char[]));
    static assert (!isArrayType!(char));
}

/**
 * Evaluates to true if T is an associative array type.
 */
template isAssocArrayType( T )
{
    const bool isAssocArrayType = is( typeof(T.init.values[0])[typeof(T.init.keys[0])] == T );
}

unittest
{
    static assert ( isAssocArrayType!(char[][int[]]));
    static assert (!isAssocArrayType!(char[]));
}

/**
 * Evaluates to true if T is a function, function pointer, delegate, or
 * callable object.
 */
template isCallableType( T )
{
    const bool isCallableType = is( T == function )             ||
                                is( typeof(*T) == function )    ||
                                is( T == delegate )             ||
                                is( typeof(T.opCall) == function );
}

unittest
{
    void foo1() { }
    auto foo2 = () { };
    class Test
    {
        void foo3() {}
    }

    static assert (isCallableType!(typeof(&foo1)));
    static assert (isCallableType!(typeof(foo2)));
    static assert (isCallableType!(typeof(&Test.foo3)));
}


/**
 * Evaluates to the return type of Fn.  Fn is required to be a callable type.
 */
template ReturnTypeOf( Fn )
{
    static if (is(Fn Fptr : Fptr*) && is(Fptr == function))
    {
        // anything implicitly convertible to function pointer
        // this also handles new Typedef struct
        alias ReturnTypeOf!(Fptr) ReturnTypeOf;
    }
    else static if( is( Fn Ret == return ) )
        alias Ret ReturnTypeOf;
    else
        static assert( false, "Argument has no return type." );
}

/**
 * Evaluates to the return type of fn.  fn is required to be callable.
 */
template ReturnTypeOf( alias fn )
{
    version(D_Version2)
    {
        alias ReturnTypeOf!(typeof(fn)) ReturnTypeOf;
    }
    else
    {
        mixin("
        static if( is( typeof(fn) Base == typedef ) )
            alias ReturnTypeOf!(Base) ReturnTypeOf;
        else
            alias ReturnTypeOf!(typeof(fn)) ReturnTypeOf;
        ");
    }
}

unittest
{
    int foo1() { return 0; }
    static assert (is(ReturnTypeOf!(foo1) == int));

    mixin (Typedef!(int, "MyType"));
    MyType foo2() { return MyType.init; }
    static assert (is(ReturnTypeOf!(foo2) == MyType));

    mixin (Typedef!(double function(), "MyFuncType"));
    MyFuncType foo3;
    static assert (is(ReturnTypeOf!(foo3) == double));
}

/**
 * Returns the type that a T would evaluate to in an expression.
 * Expr is not required to be a callable type
 */
template ExprTypeOf( Expr )
{
    static if(isCallableType!( Expr ))
        alias ReturnTypeOf!( Expr ) ExprTypeOf;
    else
        alias Expr ExprTypeOf;
}

unittest
{
    static assert (is(ExprTypeOf!(int) == int));
    auto dg = () { return 42; };
    static assert (is(ExprTypeOf!(typeof(dg)) == int));
}

/**
 * Evaluates to a tuple representing the parameters of Fn.  Fn is required to
 * be a callable type.
 */

template ParameterTupleOf( Fn )
{
    static if( is( Fn Params == function ) )
        alias Tuple!(Params) ParameterTupleOf;
    else static if( is( Fn Params == delegate ) )
        alias Tuple!(ParameterTupleOf!(Params)) ParameterTupleOf;
    else static if( is( Fn Params == Params* ) )
        alias Tuple!(ParameterTupleOf!(Params)) ParameterTupleOf;
    else
        static assert( false, "Argument has no parameters." );
}

/**
 * Evaluates to a tuple representing the parameters of fn.  n is required to
 * be callable.
 */
template ParameterTupleOf( alias fn )
{
    version(D_Version2)
    {
        alias ParameterTupleOf!(typeof(fn)) ParameterTupleOf;
    }
    else
    {
        mixin("
        static if( is( typeof(fn) Base == typedef ) )
            alias ParameterTupleOf!(Base) ParameterTupleOf;
        else
            alias ParameterTupleOf!(typeof(fn)) ParameterTupleOf;
        ");
    }
}

unittest
{
    void foo(int x, ref double y, char[] z) {}
    alias ParameterTupleOf!(foo) Params;

    static assert (Params.length == 3);
    static assert (is(Params[0] == int));
    static assert (is(Params[1] == double));
    static assert (is(Params[2] == char[]));
}

unittest
{
    mixin (Typedef!(void function(int, char[]), "MyType"));
    MyType foo;
    alias ParameterTupleOf!(foo) Params;

    static assert (Params.length == 2);
    static assert (is(Params[0] == int));
    static assert (is(Params[1] == char[]));
}

/**
 * Evaluates to a tuple representing the ancestors of T.  T is required to be
 * a class or interface type.
 */
template BaseTypeTupleOf( T )
{
    static if( is( T Base == super ) )
        alias Base BaseTypeTupleOf;
    else
        static assert( false, "Argument is not a class or interface." );
}

unittest
{
    interface A { }
    interface B { }
    class C : A, B { }

    alias BaseTypeTupleOf!(C) Bases;
    static assert (Bases.length == 3);
    static assert (is(Bases[0] == Object));
    static assert (is(Bases[1] == A));
    static assert (is(Bases[2] == B));
}

/**
 * Strips the []'s off of a type.
 */
template BaseTypeOfArrays(T)
{
    static if( is( T S : S[]) ) {
        alias BaseTypeOfArrays!(S)  BaseTypeOfArrays;
    }
    else {
        alias T BaseTypeOfArrays;
    }
}

unittest
{
    static assert( is(BaseTypeOfArrays!(real[][])==real) );
    static assert( is(BaseTypeOfArrays!(real[2][3])==real) );
}

/**
 * strips one [] off a type
 */
template ElementTypeOfArray(T:T[])
{
    alias T ElementTypeOfArray;
}

unittest
{
    static assert( is(ElementTypeOfArray!(real[])==real) );
    static assert( is(ElementTypeOfArray!(real[][])==real[]) );
    static assert( is(ElementTypeOfArray!(real[2][])==real[2]) );
    static assert( is(ElementTypeOfArray!(real[2][2])==real[2]) );
}

/**
 * Count the []'s on an array type
 */
template rankOfArray(T) {
    static if(is(T S : S[])) {
        const uint rankOfArray = 1 + rankOfArray!(S);
    } else {
        const uint rankOfArray = 0;
    }
}

unittest
{
    static assert (rankOfArray!(real[][]) == 2);
    static assert (rankOfArray!(real[2][]) == 2);
}

/// type of the keys of an AA
template KeyTypeOfAA(T){
    alias typeof(T.init.keys[0]) KeyTypeOfAA;
}

unittest
{
    static assert (is(KeyTypeOfAA!(char[int])==int));
    version(D_Version2)
    {
        mixin("static assert(is(KeyTypeOfAA!(char[][int[]])==const(int)[]));");
    }
    else
    {
        static assert (is(KeyTypeOfAA!(char[][int[]])==int[]));
    }
}

/// type of the values of an AA
template ValTypeOfAA(T){
    alias typeof(T.init.values[0]) ValTypeOfAA;
}

unittest
{
    static assert (is(ValTypeOfAA!(char[int])==char));
    static assert (is(ValTypeOfAA!(char[][int])==char[]));
}

/// returns the size of a static array
template staticArraySize(T)
{
    static assert (isStaticArrayType!(T),"staticArraySize needs a static array as type");
    static assert (rankOfArray!(T)==1,"implemented only for 1d arrays...");
    version(D_Version2)
    {
        const size_t staticArraySize=(T).sizeof / typeof(T.init[0]).sizeof;
    }
    else
    {
        const size_t staticArraySize=(T).sizeof / typeof(T.init).sizeof;
    }
}

unittest
{
    static assert (staticArraySize!(char[2]) == 2);
}

/// is T is static array returns a dynamic array, otherwise returns T
template DynamicArrayType(T)
{
    static if( isStaticArrayType!(T) )
    {
        version(D_Version2)
        {
            alias typeof(T.init[]) DynamicArrayType;
        }
        else
        {
            alias typeof(T.init)[] DynamicArrayType;
        }
    }
    else
        alias T DynamicArrayType;
}

unittest
{
    static assert( is(DynamicArrayType!(char[2])==DynamicArrayType!(char[])));
    static assert( is(DynamicArrayType!(char[2])==char[]));
}

// ------- CTFE -------

/// compile time integer to string
istring ctfe_i2a(int i){
    istring digit="0123456789";
    istring res;
    if (i==0){
        return "0";
    }
    bool neg=false;
    if (i<0){
        neg=true;
        i=-i;
    }
    while (i>0) {
        res=digit[i%10]~res;
        i/=10;
    }
    if (neg)
        return "-"~res;
    else
        return res;
}

unittest
{
    static assert (ctfe_i2a(42) == "42");
}

/// ditto
istring ctfe_i2a(long i){
    istring digit="0123456789";
    istring res;
    if (i==0){
        return "0";
    }
    bool neg=false;
    if (i<0){
        neg=true;
        i=-i;
    }
    while (i>0) {
        res=digit[cast(size_t)(i%10)]~res;
        i/=10;
    }
    if (neg)
        return '-'~res;
    else
        return res;
}

unittest
{
    static assert (ctfe_i2a(-42L) == "-42");
}

/// ditto
istring ctfe_i2a(uint i){
    istring digit="0123456789";
    istring res="";
    if (i==0){
        return "0";
    }
    bool neg=false;
    while (i>0) {
        res=digit[i%10]~res;
        i/=10;
    }
    return res;
}

unittest
{
    static assert (ctfe_i2a(42UL) == "42");
}

/// ditto
istring ctfe_i2a(ulong i){
    istring digit="0123456789";
    istring res="";
    if (i==0){
        return "0";
    }
    bool neg=false;
    while (i>0) {
        res=digit[cast(size_t)(i%10)]~res;
        i/=10;
    }
    return res;
}

unittest
{
    static assert( ctfe_i2a(31)=="31" );
    static assert( ctfe_i2a(-31)=="-31" );
    static assert( ctfe_i2a(14u)=="14" );
    static assert( ctfe_i2a(14L)=="14" );
    static assert( ctfe_i2a(14UL)=="14" );
}

/*******************************************************************************

    Checks for presence of method/field with specified name in aggregate.

    In D1 most common idiom is to simply check for `is(typeof(T.something))` but
    in D2 it can backfire because of UFCS as global names are checked too

    Template_Params:
        T = aggregate type to check
        name = method/field name to look for

*******************************************************************************/

public template hasMember(T, istring name)
{
    static assert (
        is(T == interface) ||
        is(T == class)     ||
        is(T == struct)
    );

    version (D_Version2)
    {
        mixin ("enum hasMember = __traits(hasMember, T, name);");
    }
    else
    {
        mixin ("const hasMember = is(typeof(T." ~ name ~ "));");
    }
}

unittest
{
    struct S { void foo() {}; }

    static assert ( hasMember!(S, "foo"));
    static assert (!hasMember!(S, "bar"));
}
