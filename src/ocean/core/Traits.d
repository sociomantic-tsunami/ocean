/*******************************************************************************

    Useful functions & templates.

    More of the kind of thing you'd find in ocean.core.Traits...

    Copyright:
        Copyright (C) 2005-2006 Sean Kelly.
        Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
       Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
       See LICENSE_TANGO.txt for details.

    Authors: Sean Kelly, Fawzi Mohamed, Abscissa

*******************************************************************************/

module ocean.core.Traits;


import ocean.transition;

import ocean.core.Tuple: Tuple;

/*******************************************************************************

    If T is enum, aliases to its base type. Otherwise aliases to T.

    Params:
        T = any type

*******************************************************************************/

deprecated("Use ocean.meta.types.Enum.EnumBaseType")
public template StripEnum(T)
{
    static if (is(T U == enum))
    {
        alias U StripEnum;
    }
    else
    {
        alias T StripEnum;
    }
}

/*******************************************************************************

    Evaluates to true if T is a primitive type or false otherwise. Primitive
    types are the types from which one or multiple other types cannot be
    derived from using the ``is()`` expression or corresponding template
    type parameter specialisation. The following types are not primitive:
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

*******************************************************************************/

deprecated("Use ocean.meta.traits.Basic.isPrimitiveType")
public template isPrimitiveType ( T )
{
    static immutable isPrimitiveType =
        is(Unqual!(T) == void)
     || is(Unqual!(T) == bool)
     || isIntegerType!(T)
     || isCharType!(T)
     || isFloatingPointType!(T);
}

/*******************************************************************************

    Evaluates to true if a variable of any type in T is a reference type or has
    members or elements of reference types. References are
     - dynamic and associative arrays,
     - pointers (including function pointers) and delegates,
     - classes.

    Types that are not suitable to declare a variable, i.e. ``void`` and
    function types (the base types of function pointers) are not references.

    If T is empty then the result is false.

    Params:
        T = types to check (with no type the result is false)

*******************************************************************************/

deprecated("Use ocean.meta.traits.Indirections.hasIndirections")
public template hasIndirections ( T... )
{
    static immutable hasIndirections = hasIndirectionsImpl!(T)();
}

private bool hasIndirectionsImpl ( T... )()
{
    static if ( T.length == 0 )
    {
        return false;
    }
    else
    {
        alias StripEnum!(StripTypedef!(Unqual!(T[0]))) Type;

        static if ( isPrimitiveType!(Type) || is(Type == function) )
        {
            return hasIndirections!(T[1..$]);
        }
        else static if ( isStaticArrayType!(Type) )
        {
            return hasIndirections!(ElementTypeOfArray!(Type)) ||
                   hasIndirections!(T[1..$]);
        }
        else static if ( is ( T[0] == struct ) || is ( T[0] == union ) )
        {
            static if ( TypeTuple!(Type).length == 0 )
            {
                return hasIndirections!(T[1..$]);
            }
            else static if ( TypeTuple!(Type).length == 1 )
            {
                return hasIndirections!(TypeTuple!(Type)) ||
                       hasIndirections!(T[1..$]);
            }
            else
            {
                return hasIndirections!(TypeTuple!(Type)[0]) ||
                       hasIndirections!(TypeTuple!(Type)[1..$]) ||
                       hasIndirections!(T[1..$]);
            }
        }
        else
        {
            return true;
        }
    }

    assert(false);
}

deprecated("Use ocean.meta.traits.containsMultiDimensionalDynamicArrays")
public template hasMultiDimensionalDynamicArrays ( T )
{
    /*
     * typeof(hasMultiDimensionalDynamicArraysImpl!(T)()) is bool. Its purpose
     * is to instantiate the hasMultiDimensionalDynamicArraysImpl!(T) function
     * template before calling the function (at compile time) to work around a
     * DMD1 bug if T contains itself like "struct T {T[] t;}".
     */

    static immutable typeof(hasMultiDimensionalDynamicArraysImpl!(T)()) hasMultiDimensionalDynamicArrays = hasMultiDimensionalDynamicArraysImpl!(T)();
}

private bool hasMultiDimensionalDynamicArraysImpl ( T ) ()
{
    alias StripEnum!(StripTypedef!(T)) Type;

    static if (is(Type Element: Element[])) // dynamic or static array of Element
    {
        static if (is(Type == Element[])) // dynamic array of Element
        {
            static if (isDynamicArrayType!(Element))
            {
                return true;
            }
            else
            {
                return hasMultiDimensionalDynamicArraysImpl!(Element);
            }
        }
        else  // static array of Element
        {
            return hasMultiDimensionalDynamicArraysImpl!(Element);
        }
    }
    else static if (is(Type == struct) || is(Type == union))
    {
        bool result = false;

        foreach (Field; typeof(Type.tupleof))
        {
            static if (hasMultiDimensionalDynamicArraysImpl!(Field)())
            {
                result = true;
            }
        }

        return result;
    }
    else
    {
        static assert(isPrimitiveType!(Type),
                      "T expected to be atomic, array, struct or union, not \""
                      ~ T.stringof ~ "\"");

        return false;
    }
}

deprecated("Use ocean.meta.traits.Basic.isAggregateType")
public template isCompoundType ( T )
{
    static if ( is(T == struct) || is(T == class) || is(T== union) )
    {
        static immutable isCompoundType = true;
    }
    else
    {
        static immutable isCompoundType = false;
    }
}

deprecated("Use typeof(T.tupleof)")
public template TypeTuple ( T )
{
    static if ( !isCompoundType!(T) )
    {
        static assert(false, "TypeTuple!(" ~ T.stringof ~ "): type is not a struct / class / union");
    }

    alias typeof(T.tupleof) TypeTuple;
}

deprecated("Use T.tupleof[i]")
public template FieldType ( T, size_t i )
{
    static if ( !isCompoundType!(T) )
    {
        static assert(false, "FieldType!(" ~ T.stringof ~ "): type is not a struct / class");
    }

    alias typeof (T.tupleof)[i] FieldType;
}

/*******************************************************************************

    Gets a pointer to the ith member of a struct/class.

    Params:
        i = index of member to get
        T = type of compound to get member from

    Params:
        t = pointer to compound to get member from

    Returns:
        pointer to ith member

*******************************************************************************/

deprecated("Use &t.tupleof[i]")
public FieldType!(T, i)* GetField ( size_t i, T ) ( T* t )
{
    return GetField!(i, FieldType!(T, i), T)(t);
}

/*******************************************************************************

    Gets a pointer to the ith member of a struct/class.

    Params:
        i = index of member to get
        M = type of member
        T = type of compound to get member from

    Params:
        t = pointer to compound to get member from

    Returns:
        pointer to ith member

*******************************************************************************/

deprecated("Use &t.tupleof[i]")
public M* GetField ( size_t i, M, T ) ( T* t )
{
    static if ( !isCompoundType!(T) )
    {
        static assert(false, "GetField!(" ~ T.stringof ~ "): type is not a struct / class");
    }

    return cast(M*)((cast(void*)t) + T.tupleof[i].offsetof);
}

/*******************************************************************************

    Template to get the name of the ith member of a struct / class.

    Template parameter:
        i = index of member to get
        T = type of compound to get member name from

    Evaluates to:
        name of the ith member

*******************************************************************************/

deprecated("Use ocean.meta.codegen.Identifier.identifier!(T.tupleof[i])")
public template FieldName ( size_t i, T )
{
    static if ( !isCompoundType!(T) )
    {
        static assert(false, "FieldName!(" ~ T.stringof ~ "): type is not a struct / class");
    }

    static immutable FieldName = StripFieldName!(T.tupleof[i].stringof);
}

private template StripFieldName ( istring name, size_t n = size_t.max )
{
    static if ( n >= name.length )
    {
        static immutable StripFieldName = StripFieldName!(name, name.length - 1);
    }
    else static if ( name[n] == '.' )
    {
        static immutable StripFieldName = name[n + 1 .. $];
    }
    else static if ( n )
    {
        static immutable StripFieldName = StripFieldName!(name, n - 1);
    }
    else
    {
        static immutable StripFieldName = name;
    }
}

deprecated("Use ocean.meta.traits.Aggregates.totalMemberSize")
public template SizeofTuple ( Tuple ... )
{
    static if ( Tuple.length > 0 )
    {
        static immutable size_t SizeofTuple = Tuple[0].sizeof + SizeofTuple!(Tuple[1..$]);
    }
    else
    {
        static immutable size_t SizeofTuple = 0;
    }
}

deprecated("Use `dst.tupleof[] = src.tupleof[]`")
public void copyFields ( T ) ( ref T dst, ref T src )
{
    foreach ( i, t; typeof(dst.tupleof) )
    {
        dst.tupleof[i] = src.tupleof[i];
    }
}

deprecated("Use `dst.tupleof[] = src.tupleof[]`")
public void copyClassFields ( T ) ( T dst, T src )
{
    static assert (is(T == class));

    foreach ( i, t; typeof(dst.tupleof) )
    {
        dst.tupleof[i] = src.tupleof[i];
    }
}

deprecated("Either use ocean.meta.traits.Typedef or remove the check")
public template isTypedef (T)
{
    static immutable bool isTypedef = false;
}

deprecated("Either use ocean.meta.traits.Typedef or remove the check")
public template StripTypedef (T)
{
    alias T StripTypedef;
}

deprecated("Use ocean.meta.traits.Indirections.containsDynamicArray")
template ContainsDynamicArray ( T ... )
{
    static if (T.length)
    {
        static if (isTypedef!(T[0]))
        {
            mixin(`
            static if (is (T[0] Base == typedef))
            {
                // Recurse into typedef.

                const ContainsDynamicArray = ContainsDynamicArray!(Base, T[1 .. $]);
            }
            `);
        }
        else static if (is (T[0] == struct) || is (T[0] == union))
        {
            // Recurse into struct/union members.

            static immutable ContainsDynamicArray = ContainsDynamicArray!(typeof (T[0].tupleof)) ||
                                         ContainsDynamicArray!(T[1 .. $]);
        }
        else
        {
            static if (is (T[0] Element : Element[])) // array
            {
                static if (is (Element[] == Unqual!(T[0])))
                {
                    static immutable ContainsDynamicArray = true;
                }
                else
                {
                    // Static array, recurse into base type.

                    static immutable ContainsDynamicArray = ContainsDynamicArray!(Element) ||
                                                 ContainsDynamicArray!(T[1 .. $]);
                }
            }
            else
            {
                // Skip non-dynamic or static array type.

                static immutable ContainsDynamicArray = ContainsDynamicArray!(T[1 .. $]);
            }
        }
    }
    else
    {
        static immutable ContainsDynamicArray = false;
    }
}

/*******************************************************************************

    Evaluates, if T is callable (function, delegate, a class/interface/struct/
    union implementing opCall() as a member or static method or a typedef of
    these), to a type tuple with the return type as the first element, followed
    by the argument types.
    Evaluates to an empty tuple if T is not callable.

    Template parameter:
        T = Type to, if callable, get the return and argument types

    Evaluates to:
        a type tuple containing the return and argument types or an empty tuple
        if T is not callable.

*******************************************************************************/

deprecated("Use ocean.meta.types.Function.ParametersOf and ReturnTypeOf")
template ReturnAndArgumentTypesOf ( T )
{
    static if (isTypedef!(T))
    {
        mixin(`
        static if (is(T F == typedef))
            alias ReturnAndArgumentTypesOf!(F) ReturnAndArgumentTypesOf;
        `);
    }
    else static if (is(T Args == function) && is(T Return == return))
    {
        alias Tuple!(Return, Args) ReturnAndArgumentTypesOf;
    }
    else static if (is(T F == delegate) || is(T F == F*) ||
                    is(typeof(&(T.init.opCall)) F))
    {
        alias ReturnAndArgumentTypesOf!(F) ReturnAndArgumentTypesOf;
    }
    else
    {
        alias Tuple!() ReturnAndArgumentTypesOf;
    }
}

import ocean.core.TypeConvert;
deprecated("Use ocean.core.TypeConvert.toDg")
public alias toDg = ocean.core.TypeConvert.toDg;

deprecated("Use ocean.meta.traits.Aggregates.hasMethod")
template hasMethod ( T, istring name, Dg )
{
    static assert(is(T == struct) || is(T == class) || is(T == union) ||
        is(T == interface));
    static assert(is(Dg == delegate));

    static if ( is(typeof( { Dg dg = mixin("&T.init." ~ name); } )) )
    {
        static immutable bool hasMethod = true;
    }
    else
    {
        static immutable bool hasMethod = false;
    }
}

deprecated("Use ocean.meta.codegen.Identifier.identifier")
public template identifier(alias Sym)
{
    static immutable identifier = _identifier!(Sym)();
}

private istring _identifier(alias Sym)()
{
    static if (is(typeof(Sym) == function))
    {
        // Sym.stringof is treated as Sym().stringof
        // ugly workaround:
        ParameterTupleOf!(Sym) args;
        auto name = Sym(args).stringof[];
        size_t bracketIndex = 0;
        while (name[bracketIndex] != '(' && bracketIndex < name.length)
            ++bracketIndex;
        return name[0 .. bracketIndex];
    }
    else
    {
        return Sym.stringof;
    }
}

deprecated("Use ocean.meta.types.Arrays.ElementTypeOf")
public template AAType (T : V[K], V, K)
{
    public alias K Key;
    public alias V Value;
}

deprecated("Use ocean.meta.traits.Templates.TemplateInstanceArgs")
public template TemplateInstanceArgs (alias Template, Type : Template!(TA), TA...)
{
    public alias TA TemplateInstanceArgs;
}

deprecated("Use ocean.meta.traits.Arrays.isUTF8StringType")
template isStringType( T )
{
    static immutable bool isStringType = is( T : char[] )  ||
                              is( T : wchar[] ) ||
                              is( T : dchar[] ) ||
                              is( T : istring ) ||
                              is( T : cstring ) ||
                              is( T : mstring );
}

deprecated("Use ocean.meta.traits.Basic.isCharType")
template isCharType( T )
{
    static immutable bool isCharType =
        is( Unqual!(T) == char )
     || is( Unqual!(T) == wchar )
     || is( Unqual!(T) == dchar );
}

deprecated("Use ocean.meta.traits.Basic.isSignedIntegerType")
template isSignedIntegerType( T )
{
    static immutable bool isSignedIntegerType =
        is( Unqual!(T) == byte )
     || is( Unqual!(T) == short )
     || is( Unqual!(T) == int )
     || is( Unqual!(T) == long );
}

deprecated("Use ocean.meta.traits.Basic.isUnsignedIntegerType")
template isUnsignedIntegerType( T )
{
    static immutable bool isUnsignedIntegerType =
        is( Unqual!(T) == ubyte )
     || is( Unqual!(T) == ushort )
     || is( Unqual!(T) == uint )
     || is( Unqual!(T) == ulong );
}

deprecated("Use ocean.meta.traits.Basic.isIntegerType")
template isIntegerType( T )
{
    static immutable bool isIntegerType = isSignedIntegerType!(T) ||
                               isUnsignedIntegerType!(T);
}

deprecated("Use ocean.meta.traits.Basic.isRealType")
template isRealType( T )
{
    static immutable bool isRealType =
        is( Unqual!(T) == float )
     || is( Unqual!(T) == double )
     || is( Unqual!(T) == real );
}

deprecated("Use ocean.meta.traits.Basic.isComplexType")
template isComplexType( T )
{
    static immutable bool isComplexType =
        is( Unqual!(T) == cfloat )
     || is( Unqual!(T) == cdouble )
     || is( Unqual!(T) == creal );
}

deprecated("Use ocean.meta.traits.Basic.isImaginaryType")
template isImaginaryType( T )
{
    static immutable bool isImaginaryType =
        is( Unqual!(T) == ifloat )
     || is( Unqual!(T) == idouble )
     || is( Unqual!(T) == ireal );
}

deprecated("Use ocean.meta.traits.Basic.isFloatingPointType")
template isFloatingPointType( T )
{
    static immutable bool isFloatingPointType = isRealType!(T)    ||
                                     isComplexType!(T) ||
                                     isImaginaryType!(T);
}

deprecated("Use ocean.meta.traits.Basic.isPointerType")
template isPointerType(T)
{
        static immutable isPointerType = false;
}

deprecated("Use ocean.meta.traits.Basic.isPointerType")
template isPointerType(T : T*)
{
        static immutable isPointerType = true;
}

deprecated("Use ocean.meta.traits.Basic.isReferenceType")
template isReferenceType( T )
{

    static immutable bool isReferenceType = isPointerType!(T)  ||
                               is( T == class )     ||
                               is( T == interface ) ||
                               is( T == delegate );
}

deprecated("Use ocean.meta.traits.Basic.isArrayType")
template isDynamicArrayType( T )
{
    static immutable bool isDynamicArrayType = is( typeof(T.init[0])[] == T );
}

deprecated("Use ocean.meta.traits.Basic.isArrayType")
template isStaticArrayType( T : T[U], size_t U )
{
    static immutable bool isStaticArrayType = true;
}

deprecated("Use ocean.meta.traits.Basic.isArrayType")
template isStaticArrayType( T )
{
    static immutable bool isStaticArrayType = false;
}

deprecated("Use ocean.meta.traits.Basic.isArrayType")
template isArrayType(T)
{
    static if (is( T U : U[] ))
        static immutable bool isArrayType=true;
    else
        static immutable bool isArrayType=false;
}

deprecated("Use ocean.meta.traits.Basic.isArrayType")
template isAssocArrayType( T )
{
    static immutable bool isAssocArrayType = is( typeof(T.init.values[0])[typeof(T.init.keys[0])] == T );
}

deprecated("Use ocean.meta.traits.Basic.isCallableType")
template isCallableType( T )
{
    static immutable bool isCallableType = is( T == function )             ||
                                is( typeof(*T) == function )    ||
                                is( T == delegate )             ||
                                is( typeof(T.opCall) == function );
}

deprecated("Use ocean.meta.types.Function.ReturnTypeOf")
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

deprecated("Use ocean.meta.types.Function.ReturnTypeOf")
template ReturnTypeOf( alias fn )
{
    alias ReturnTypeOf!(typeof(fn)) ReturnTypeOf;
}

deprecated("Use ocean.meta.types.Function.ParametersOf")
template ParameterTupleOf( Fn )
{
    static if( is( Fn Params == function ) )
        alias Tuple!(Params) ParameterTupleOf;
    else static if( is( Fn Params == delegate ) )
        alias Tuple!(ParameterTupleOf!(Params)) ParameterTupleOf;
    else static if( is( Fn Params : Params* ) )
        alias Tuple!(ParameterTupleOf!(Params)) ParameterTupleOf;
    else
        static assert( false, "Argument has no parameters." );
}

deprecated("Use ocean.meta.types.Function.ParametersOf")
template ParameterTupleOf( alias fn )
{
    alias ParameterTupleOf!(typeof(fn)) ParameterTupleOf;
}

deprecated("Use ocean.meta.types.Arrays.StripAllArrays")
template BaseTypeOfArrays(T)
{
    static if( is( T S : S[]) ) {
        alias BaseTypeOfArrays!(S)  BaseTypeOfArrays;
    }
    else {
        alias T BaseTypeOfArrays;
    }
}

deprecated("Use ocean.meta.types.Arrays.ElementTypeOf")
template ElementTypeOfArray(T:T[])
{
    alias T ElementTypeOfArray;
}

deprecated("Use ocean.meta.traits.Arrays.rankOfArray")
template rankOfArray(T) {
    static if(is(T S : S[])) {
        static immutable uint rankOfArray = 1 + rankOfArray!(S);
    } else {
        static immutable uint rankOfArray = 0;
    }
}

deprecated("Use ocean.meta.codegen.CTFE.toString")
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

deprecated("Use ocean.meta.codegen.CTFE.toString")
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

deprecated("Use ocean.meta.codegen.CTFE.toString")
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

deprecated("Use ocean.meta.codegen.CTFE.toString")
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

deprecated("Use ocean.meta.traits.Aggregates.hasMember")
public template hasMember(T, istring name)
{
    static assert (
        is(T == interface) ||
        is(T == class)     ||
        is(T == struct)
    );

    enum hasMember = __traits(hasMember, T, name);
}
