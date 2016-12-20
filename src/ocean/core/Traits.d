/*******************************************************************************

    Useful functions & templates.

    More of the kind of thing you'd find in ocean.core.Traits...

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.Traits;

/*******************************************************************************

    Imports.

*******************************************************************************/

import ocean.transition;

import ocean.core.Tuple: Tuple;

public import ocean.core.Traits_tango;

version (UnitTest)
{
    import ocean.core.Test;

    /***************************************************************************

        Used as aggregate type argument in all tests

    ***************************************************************************/

    struct TestStruct
    {
        int a;
        int b = 42;
        double c;
    }
}

/*******************************************************************************

    Tells whether the passed string is a D 1.0 keyword.

    This function is designed to be used at compile time.

    Note that any string identifier beginning with __ is also reserved by D 1.0.
    This function does not check for this case.

    Params:
        str = string to check

    Returns:
        true if the string is a D 1.0 keyword

*******************************************************************************/

public bool isKeyword ( cstring str )
{
    const istring[] keywords = [
        "abstract",     "alias",        "align",        "asm",
        "assert",       "auto",         "body",         "bool",
        "break",        "byte",         "case",         "cast",
        "catch",        "cdouble",      "cent",         "cfloat",
        "char",         "class",        "const",        "continue",
        "creal",        "dchar",        "debug",        "default",
        "delegate",     "delete",       "deprecated",   "do",
        "double",       "else",         "enum",         "export",
        "extern",       "false",        "final",        "finally",
        "float",        "for",          "foreach",      "foreach_reverse",
        "function",     "goto",         "idouble",      "if",
        "ifloat",       "import",       "in",           "inout",
        "int",          "interface",    "invariant",    "ireal",
        "is",           "lazy",         "long",         "macro",
        "mixin",        "module",       "new",          "null",
        "out",          "override",     "package",      "pragma",
        "private",      "protected",    "public",       "real",
        "ref",          "return",       "scope",        "short",
        "static",       "struct",       "super",        "switch",
        "synchronized", "template",     "this",         "throw",
        "true",         "try",          "typedef",      "typeid",
        "typeof",       "ubyte",        "ucent",        "uint",
        "ulong",        "union",        "unittest",     "ushort",
        "version",      "void",         "volatile",     "wchar",
        "while",        "with"
    ];

    for ( int i; i < keywords.length; i++ )
    {
        if ( str == keywords[i] ) return true;
    }
    return false;
}



/*******************************************************************************

    Tells whether the passed string is a valid D 1.0 identifier.

    This function is designed to be used at compile time.

    Note that this function does not check whether the passed string is a D
    keyword (see isKeyword(), above) -- all keywords are also identifiers.

    Params:
        input = string to check

    Returns:
        true if the string is a valid D 1.0 identifier

*******************************************************************************/

public bool isIdentifier ( cstring input )
{
    bool alphaUnderscore ( char c )
    {
        return c == '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
    }

    bool validChar ( char c )
    {
        return alphaUnderscore(c) || (c >= '0' && c <= '9');
    }

    // Identifiers must have a length
    if ( input.length == 0 ) return false;

    // Identifiers must begin with an alphabetic or underscore character
    if ( !alphaUnderscore(input[0]) ) return false;

    // Strings beginning with "__" are reserved (not identifiers)
    if ( input.length > 1 && input[0] == '_' && input[1] == '_' ) return false;

    // All characters after the first must be alphanumerics or underscores
    for ( int i = 1; i < input.length; i++ )
    {
        if ( !validChar(input[i]) ) return false;
    }

    return true;
}

/*******************************************************************************

    If T is enum, aliases to its base type. Otherwise aliases to T.

    Template_Params
        T = any type

*******************************************************************************/

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

unittest
{
    enum Test : int
    {
        field = 42
    }

    static assert (is(StripEnum!(typeof(Test.field)) == int));
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

    Template_Params:
        T = type to check

*******************************************************************************/

public template isPrimitiveType ( T )
{
    const isPrimitiveType =
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

    Template_Params:
        T = types to check (with no type the result is false)

*******************************************************************************/

public template hasIndirections ( T... )
{
    const hasIndirections = hasIndirectionsImpl!(T)();
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

unittest
{
    static assert (hasIndirections!(int) == false);
    static assert (hasIndirections!(int[int]) == true);
    static assert (!hasIndirections!(void));
    static if (is(int function() F == F*))
    {
        static assert (!hasIndirections!(F));
    }
    else
    {
        static assert(false, "function pointer base type derivation failed");
    }
}


/*******************************************************************************

    Checks if T or any of its subtypes is a multi-dimensional dynamic array.

    T and all of its subtypes, if any, are expected to be
      - an atomic type or
      - a dynamic or static array or
      - a struct or a union.

    Template_Params:
        T = type to check

    Returns:
        true if T or any of its subtypes is a multi-dimensional dynamic array or
        false otherwise.

*******************************************************************************/

public template hasMultiDimensionalDynamicArrays ( T )
{
    /*
     * typeof(hasMultiDimensionalDynamicArraysImpl!(T)()) is bool. Its purpose
     * is to instantiate the hasMultiDimensionalDynamicArraysImpl!(T) function
     * template before calling the function (at compile time) to work around a
     * DMD1 bug if T contains itself like "struct T {T[] t;}".
     */

    const typeof(hasMultiDimensionalDynamicArraysImpl!(T)()) hasMultiDimensionalDynamicArrays = hasMultiDimensionalDynamicArraysImpl!(T)();
}

/*
 * This is a CTFE function rather than a template to allow for 'foreach' over
 * a type tuple and prevent the Type alias from interfering.
 */

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

unittest
{
    static assert(!hasMultiDimensionalDynamicArrays!(int));
    static assert(!hasMultiDimensionalDynamicArrays!(int[ ]));
    static assert(!hasMultiDimensionalDynamicArrays!(int[3]));

    static assert( hasMultiDimensionalDynamicArrays!(int[ ][ ]));
    static assert(!hasMultiDimensionalDynamicArrays!(int[3][ ]));
    static assert(!hasMultiDimensionalDynamicArrays!(int[ ][3]));
    static assert(!hasMultiDimensionalDynamicArrays!(int[3][3]));

    static assert( hasMultiDimensionalDynamicArrays!(int[ ][ ][ ]));
    static assert( hasMultiDimensionalDynamicArrays!(int[3][ ][ ]));
    static assert(!hasMultiDimensionalDynamicArrays!(int[ ][3][ ]));
    static assert(!hasMultiDimensionalDynamicArrays!(int[3][3][ ]));
    static assert( hasMultiDimensionalDynamicArrays!(int[ ][ ][3]));
    static assert(!hasMultiDimensionalDynamicArrays!(int[3][ ][3]));
    static assert(!hasMultiDimensionalDynamicArrays!(int[ ][3][3]));
    static assert(!hasMultiDimensionalDynamicArrays!(int[3][3][3]));

    static assert(!hasMultiDimensionalDynamicArrays!(void));
    static assert(!hasMultiDimensionalDynamicArrays!(void[]));
    static assert( hasMultiDimensionalDynamicArrays!(void[][]));
    static assert(!hasMultiDimensionalDynamicArrays!(void[][3]));

    struct A
    {
        int x;
        char[] y;
        float[][][3][] z;
    }

    struct B
    {
        A[] a;
    }

    static assert(hasMultiDimensionalDynamicArrays!(A));

    struct C
    {
        int x;
        float[][3][] y;
        char[] z;
    }

    static assert(!hasMultiDimensionalDynamicArrays!(C));
}

/*******************************************************************************

    Template which evaluates to true if the specified type is a compound type
    (ie a class, struct or union).

    Template_Params:
        T = type to check

    Evaluates to:
        true if T is a compound type, false otherwise

*******************************************************************************/

public template isCompoundType ( T )
{
    static if ( is(T == struct) || is(T == class) || is(T== union) )
    {
        const isCompoundType = true;
    }
    else
    {
        const isCompoundType = false;
    }
}

unittest
{
    static assert (!isCompoundType!(int));
    static assert ( isCompoundType!(TestStruct));
}


/*******************************************************************************

    Template to get the type tuple of compound type T.

    Template_Params:
        T = type to get type tuple of

    Evaluates to:
        type tuple of T's members

*******************************************************************************/

public template TypeTuple ( T )
{
    static if ( !isCompoundType!(T) )
    {
        static assert(false, "TypeTuple!(" ~ T.stringof ~ "): type is not a struct / class / union");
    }

    alias typeof(T.tupleof) TypeTuple;
}

unittest
{
    static assert (is(TypeTuple!(TestStruct)[0] == int));
}


/*******************************************************************************

    Template to get the type of the ith data member struct/class T.

    Template_Params:
        T = type to get field of

    Evaluates to:
        type of ith member of T

*******************************************************************************/

public template FieldType ( T, size_t i )
{
    static if ( !isCompoundType!(T) )
    {
        static assert(false, "FieldType!(" ~ T.stringof ~ "): type is not a struct / class");
    }

    alias typeof (T.tupleof)[i] FieldType;
}

unittest
{
    static assert (is(FieldType!(TestStruct, 0) == int));
}


/*******************************************************************************

    Gets a pointer to the ith member of a struct/class.

    Template_Params:
        i = index of member to get
        T = type of compound to get member from

    Params:
        t = pointer to compound to get member from

    Returns:
        pointer to ith member

*******************************************************************************/

public FieldType!(T, i)* GetField ( size_t i, T ) ( T* t )
{
    return GetField!(i, FieldType!(T, i), T)(t);
}

unittest
{
    TestStruct s;
    auto x = GetField!(1)(&s);
    test(*x == 42);
}


/*******************************************************************************

    Gets a pointer to the ith member of a struct/class.

    Template_Params:
        i = index of member to get
        M = type of member
        T = type of compound to get member from

    Params:
        t = pointer to compound to get member from

    Returns:
        pointer to ith member

*******************************************************************************/

public M* GetField ( size_t i, M, T ) ( T* t )
{
    static if ( !isCompoundType!(T) )
    {
        static assert(false, "GetField!(" ~ T.stringof ~ "): type is not a struct / class");
    }

    return cast(M*)((cast(void*)t) + T.tupleof[i].offsetof);
}

unittest
{
    TestStruct s;
    auto x = GetField!(1, int)(&s);
    test(*x == 42);
}

/*******************************************************************************

    Template to get the name of the ith member of a struct / class.

    Template parameter:
        i = index of member to get
        T = type of compound to get member name from

    Evaluates to:
        name of the ith member

*******************************************************************************/

public template FieldName ( size_t i, T )
{
    static if ( !isCompoundType!(T) )
    {
        static assert(false, "FieldName!(" ~ T.stringof ~ "): type is not a struct / class");
    }

    const FieldName = StripFieldName!(T.tupleof[i].stringof);
}

unittest
{
    static assert (FieldName!(0, TestStruct) == "a");
}

/*******************************************************************************

    Template to strip the part after the '.' in a string.

    Template parameter:
        name = string to scan
        n = scanning index

    Evaluates to:
        tail of name after the last '.' character

*******************************************************************************/

private template StripFieldName ( istring name, size_t n = size_t.max )
{
    static if ( n >= name.length )
    {
        const StripFieldName = StripFieldName!(name, name.length - 1);
    }
    else static if ( name[n] == '.' )
    {
        const StripFieldName = name[n + 1 .. $];
    }
    else static if ( n )
    {
        const StripFieldName = StripFieldName!(name, n - 1);
    }
    else
    {
        const StripFieldName = name;
    }
}



/*******************************************************************************

    Template to get the size in bytes of the passed type tuple.

    Template parameter:
        Tuple = variadic type tuple

    Evaluates to:
        size_t constant equal to the sizeof each type in the tuple

*******************************************************************************/

public template SizeofTuple ( Tuple ... )
{
    static if ( Tuple.length > 0 )
    {
        const size_t SizeofTuple = Tuple[0].sizeof + SizeofTuple!(Tuple[1..$]);
    }
    else
    {
        const size_t SizeofTuple = 0;
    }
}

unittest
{
    static assert (SizeofTuple!(Tuple!(byte, byte, byte)) == 3);
}

/*******************************************************************************

    Function which iterates over the type tuple of T and copies all fields from
    one instance to another. Note that, for classes, according to:

        http://digitalmars.com/d/1.0/class.html

    "The .tupleof property returns an ExpressionTuple of all the fields in the
    class, excluding the hidden fields and the fields in the base class."

    (This is not actually true with current versions of the compiler, but
    anyway.)

    Template_Params:
        T = type of instances to copy fields from and to

    Params:
        dst = instance of type T to be copied into
        src = instance of type T to be copied from

*******************************************************************************/

public void copyFields ( T ) ( ref T dst, ref T src )
{
    foreach ( i, t; typeof(dst.tupleof) )
    {
        dst.tupleof[i] = src.tupleof[i];
    }
}

///
unittest
{
    TestStruct a, b;
    copyFields(a, b);
}

/*******************************************************************************

    Version of `copyFields` with modified declaration so that it doesn't
    accept class reference by ref. Doing so with plain `copyFields` caused
    deprecation warning in D2 otherwise, "Deprecation: this is not an lvalue".

*******************************************************************************/

public void copyClassFields ( T ) ( T dst, T src )
{
    static assert (is(T == class));

    foreach ( i, t; typeof(dst.tupleof) )
    {
        dst.tupleof[i] = src.tupleof[i];
    }
}

///
unittest
{
    static class C
    {
        int x;

        void copy ( )
        {
            C c = new C;
            copyClassFields(this, c);
        }
    }
}

/*******************************************************************************

    Function which iterates over the type tuple of T and sets all fields of the
    provided instance to their default (.init) values. Note that, for classes,
    according to:

        http://digitalmars.com/d/1.0/class.html

    "The .tupleof property returns an ExpressionTuple of all the fields in the
    class, excluding the hidden fields and the fields in the base class."

    (This is not actually true with current versions of the compiler, but
    anyway.)

    Template_Params:
        T = type of instances to initialise

    Params:
        o = instance of type T to be initialised

*******************************************************************************/

public void initFields ( T ) ( ref T o )
{
    foreach ( i, t; typeof(o.tupleof) )
    {
        o.tupleof[i] = o.tupleof[i].init;
    }
}

unittest
{
    auto s = TestStruct(10, 10, 10.0);
    initFields(s);
    // test(s.b == 42); // DMD1 BUG!
    test(s.b == 0);
}


/*******************************************************************************

    Template to determine if a type tuple is composed of unique types, with no
    duplicates.

    Template parameter:
        Tuple = variadic type tuple

    Evaluates to:
        true if no duplicate types exist in Tuple

    TODO: could be re-phrased in terms of ocean.core.Tuple : Unique

*******************************************************************************/

public template isUniqueTypesInTuple ( Tuple ... )
{
    static if ( Tuple.length > 1 )
    {
        const bool isUniqueTypesInTuple = (CountTypesInTuple!(Tuple[0], Tuple) == 1) && isUniqueTypesInTuple!(Tuple[1..$]);
    }
    else
    {
        const bool isUniqueTypesInTuple = true;
    }
}

unittest
{
    static assert ( isUniqueTypesInTuple!(Tuple!(int, double, float)));
    static assert (!isUniqueTypesInTuple!(Tuple!(int, int, float)));
}


/*******************************************************************************

    Template to count the number of times a specific type appears in a tuple.

    Template parameter:
        Type = type to count
        Tuple = variadic type tuple

    Evaluates to:
        number of times Type appears in Tuple

    TODO: could be re-phrased in terms of ocean.core.Tuple : Unique

*******************************************************************************/

public template CountTypesInTuple ( Type, Tuple ... )
{
    static if ( Tuple.length > 0 )
    {
        const uint CountTypesInTuple = is(Type == Tuple[0]) + CountTypesInTuple!(Type, Tuple[1..$]);
    }
    else
    {
        const uint CountTypesInTuple = 0;
    }
}

unittest
{
    static assert (CountTypesInTuple!(int, Tuple!(int, double, int)) == 2);
}

/*******************************************************************************

    Determines if T is a typedef.

    Typedef has been removed in D2 and this template will always evaluate to
    false if compiled with version = D_Version2.

    Template_Params:
        T = type to check

    Evaluates to:
        true if T is a typedef, false otherwise

*******************************************************************************/

version (D_Version2)
{
    public template isTypedef (T)
    {
        const bool isTypedef = false;
    }
}
else
{
    mixin("
    public template isTypedef (T)
    {
        static if (is(T Orig == typedef))
        {
            const bool isTypedef = true;
        }
        else
        {
            const bool isTypedef = false;
        }
    }

    unittest
    {
        typedef double RealNum;

        static assert(!isTypedef!(int));
        static assert(!isTypedef!(double));
        static assert(isTypedef!(RealNum));
    }");
}

unittest
{
    mixin(Typedef!(int, "MyInt"));

    version (D_Version2)
    {
        static assert (!isTypedef!(MyInt)); // just a struct
    }
    else
    {
        static assert ( isTypedef!(MyInt));
    }
}

/*******************************************************************************

    Strips the typedef off T.

    Typedef has been removed in D2 and this template is a no-op if compiled
    with version = D_Version2.

    Template_Params:
        T = type to strip of typedef

    Evaluates to:
        alias to either T (if T is not typedeffed) or the base class of T

*******************************************************************************/

version (D_Version2)
{
    public template StripTypedef (T)
    {
        alias T StripTypedef;
    }
}
else
{
    mixin("
    public template StripTypedef ( T )
    {
        static if ( is ( T Orig == typedef ) )
        {
            alias StripTypedef!(Orig) StripTypedef;
        }
        else
        {
            alias T StripTypedef;
        }
    }

    unittest
    {
        typedef int Foo;
        typedef Foo Bar;
        typedef Bar Goo;

        static assert(is(StripTypedef!(Goo) == int));
    }");
}

unittest
{
    mixin(Typedef!(int, "MyInt"));

    version (D_Version2)
    {
        static assert (is(StripTypedef!(MyInt) == MyInt));
    }
    else
    {
        static assert (is(StripTypedef!(MyInt) == int));
    }
}

/******************************************************************************

    Tells whether the types in T are or contain dynamic arrays, recursing into
    the member types of structs and union, the element types of dynamic and
    static arrays and typedefs.

    Reference types other than dynamic arrays (classes, pointers, functions,
    delegates and associative arrays) are ignored and not recursed into.

    Template parameter:
        T = types to check

    Evaluates to:
        true if any type in T is a or contains dynamic arrays or false if not
        or T is empty.

 ******************************************************************************/

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

            const ContainsDynamicArray = ContainsDynamicArray!(typeof (T[0].tupleof)) ||
                                         ContainsDynamicArray!(T[1 .. $]);
        }
        else
        {
            static if (is (T[0] Element == Element[])) // array
            {
                const ContainsDynamicArray = true;
            }
            else static if (is (T[0] Element : Element[]))
            {
                // Static array, recurse into base type.

                const ContainsDynamicArray = ContainsDynamicArray!(Element) ||
                                             ContainsDynamicArray!(T[1 .. $]);
            }
            else
            {
                // Skip non-dynamic or static array type.

                const ContainsDynamicArray = ContainsDynamicArray!(T[1 .. $]);
            }
        }
    }
    else
    {
        const ContainsDynamicArray = false;
    }
}

unittest
{
    static assert (!ContainsDynamicArray!(TestStruct));
    mixin (Typedef!(int[], "MyInt"));
    static assert ( ContainsDynamicArray!(MyInt));

    static struct S
    {
        mstring s;
    }

    static assert ( ContainsDynamicArray!(Const!(S)));
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

/******************************************************************************/

unittest
{
    static assert(is(ReturnAndArgumentTypesOf!(void) == Tuple!()));
    static assert(is(ReturnAndArgumentTypesOf!(int) == Tuple!()));
    static assert(is(ReturnAndArgumentTypesOf!(void function()) == Tuple!(void)));
    static assert(is(ReturnAndArgumentTypesOf!(int function(char)) == Tuple!(int, char)));
    static if (is(int function(char) T: T*))
    {
        static assert(is(ReturnAndArgumentTypesOf!(T) == Tuple!(int, char)));
    }
    static assert(is(ReturnAndArgumentTypesOf!(int delegate(char)) == Tuple!(int, char)));

    class C {int opCall(char){return 0;}}
    class D {static int opCall(char){return 0;}}
    class E {int opCall;}
    interface I {int opCall(char);}
    struct S {int opCall(char){return 0;}}
    union U {int opCall(char){return 0;}}

    static assert(is(ReturnAndArgumentTypesOf!(C) == Tuple!(int, char)));
    static assert(is(ReturnAndArgumentTypesOf!(D) == Tuple!(int, char)));
    static assert(is(ReturnAndArgumentTypesOf!(E) == Tuple!()));
    static assert(is(ReturnAndArgumentTypesOf!(I) == Tuple!(int, char)));
    static assert(is(ReturnAndArgumentTypesOf!(S) == Tuple!(int, char)));
    static assert(is(ReturnAndArgumentTypesOf!(U) == Tuple!(int, char)));

    // Check hasIndirections

    struct NoIndirections
    {
        struct Z
        {
            int f,g;
        }
        int a;
        long b;
        byte c;
        union U
        {
            char e;
            char[2] arr;
        }

        U u;
        Z q;
    }

    static assert ( hasIndirections!(NoIndirections) == false );

    struct Arrays
    {
        int a;
        int[] b;
    }

    static assert ( hasIndirections!(Arrays) );

    struct Ptr
    {
        int* a;
    }

    static assert ( hasIndirections!(Arrays) );

    struct Class
    {
        class A {}
        A a;
    }

    static assert ( hasIndirections!(Class) );

    struct Asso
    {
        char[int] a;
    }

    static assert ( hasIndirections!(Asso) );

    struct Dg
    {
        void delegate ( ) a;
    }

    static assert ( hasIndirections!(Dg) );

    struct Func
    {
        void function ( ) a;
    }

    static assert ( hasIndirections!(Func) );
}

/*******************************************************************************

    Helper function to wrap any callable type in a delegate. Most useful when
    you need to pass function pointer as a delegate argument.

    This function allocates a closure class for a delegate.

    NB! toDg does not preserve any argument attributes of Func such as ref or
    lazy.

    Params:
        f = function or function pointer or delegate

    Returns:
        delegate that internally calls f and does nothing else

*******************************************************************************/

ReturnTypeOf!(Func) delegate (ParameterTupleOf!(Func)) toDg ( Func ) ( Func f )
{
    static assert (
        is(Func == ReturnTypeOf!(Func) function (ParameterTupleOf!(Func))),
        "toDg does not preserve argument attributes!"
    );

    alias ParameterTupleOf!(Func) ParameterTypes;

    class Closure
    {
        private Func func;

        this (Func func)
        {
            this.func = func;
        }

        ReturnTypeOf!(Func) call (ParameterTypes args)
        {
            return this.func(args);
        }
    }

    auto closure = new Closure(f);

    return &closure.call;
}

unittest
{
    static int foo() { return 42; }
    static assert (is(typeof(toDg(&foo)) == int delegate()));
    assert (toDg(&foo)() == 42);


    static void bar(int a, int b)
    {
        assert (a == 3);
        assert (b == 4);
    }

    toDg(&bar)(3, 4);

    static int bad(ref int x) { return x; }
    static assert(!is(typeof(toDg(&bad))));
}

/*******************************************************************************

    Check if a class or struct type contains a method with the given
    method name, and has the same signature as the given delegate.

    Template_Params:
        T = The class or struct type to check
        name = The name of the method to look up
        Dg = The delegate type with the signature of the method to look for

    Evaluates to:
        True if the given type contains the method, false otherwise

*******************************************************************************/

template hasMethod ( T, istring name, Dg )
{
    static assert(is(T == struct) || is(T == class) || is(T == union));
    static assert(isIdentifier(name));
    static assert(is(Dg == delegate));

    static if ( is(typeof( { Dg dg = mixin("&T.init." ~ name); } )) )
    {
        const bool hasMethod = true;
    }
    else
    {
        const bool hasMethod = false;
    }
}

version ( UnitTest )
{
    template Methods ( )
    {
        void reset ( ) { }
        int retint ( ) { return 0; }
        int retintargs ( int ) { return 0; }
        int retintargs2 ( int, float, char ) { return 0; }
    }

    template Tests ( T )
    {
        static assert( hasMethod!(T, "reset", void delegate()) );
        static assert( !hasMethod!(T, "reset", int delegate()) );
        static assert( !hasMethod!(T, "reset", void delegate(int)) );
        static assert( !hasMethod!(T, "whatever", void delegate()) );
        static assert( hasMethod!(T, "retint", int delegate()) );
        static assert( hasMethod!(T, "retintargs", int delegate(int)) );
        static assert( hasMethod!(T, "retintargs2", int delegate(int, float, char)) );
        static assert( !hasMethod!(T, "retintargs2", int delegate(char, float, int)) );
    }
}

unittest
{
    struct Struct
    {
        mixin Methods;
    }

    mixin Tests!(Struct);

    class Base
    {
        void baseMethodVoid ( ) { }
        int baseMethodInt ( ) { return 0; }
        int baseMethodIntArgs ( int, float, char ) { return 0; }
    }

    class Class : Base
    {
        mixin Methods;
    }

    mixin Tests!(Class);

    static assert ( hasMethod!(Class, "baseMethodVoid", void delegate()) );
    static assert ( !hasMethod!(Class, "baseMethodVoid", int delegate()) );
    static assert ( !hasMethod!(Class, "baseMethodVoid", void delegate(int)) );
    static assert ( hasMethod!(Class, "baseMethodInt", int delegate()) );
    static assert ( hasMethod!(Class, "baseMethodIntArgs", int delegate(int, float, char)) );

    union Union
    {
        mixin Methods;
    }

    mixin Tests!(Union);
}

/*******************************************************************************

    Returns "name" (identifier) of a given symbol as string

    Template_Params:
        Sym = any symbol alias

*******************************************************************************/

public template identifier(alias Sym)
{
    const identifier = _identifier!(Sym)();
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

///
unittest
{
    class ClassName { }
    void funcName ( ) { }
    extern(C) void funcNameArgs ( int a, double b ) { }

    static assert (identifier!(ClassName) == "ClassName");
    assert (identifier!(ClassName) == "ClassName");

    static assert (identifier!(funcName) == "funcName");
    assert (identifier!(funcName) == "funcName");

    static assert (identifier!(funcNameArgs) == "funcNameArgs");
    assert (identifier!(funcNameArgs) == "funcNameArgs");
}

unittest
{
    // #741 regression test

    static void foo () {}
    testNoAlloc({ auto str = identifier!(foo); } ());
}


/*******************************************************************************

    Get key and value type of an associative array in D1 (and D2)

    In D2, one would check if a type `T` is an associative array (and
    get its key / value type in scope) by using an `is` expression:

    ---
    static if (is(T V : V[K], K))
        pragma(msg, "Key type: ", K, ", value type: ", V);
    ---

    Sadly D1 doesn't support this syntax.  However we can use type matching
    in template argument to work around this problem.

    The above example would then be rewritten as:

    ---
    static if (is(AAType!(T).Key))
        pragma(msg, "Key type: ", AAType!(T).Key, ", value type: ",
                AAType!(T).Value);
    ---

    Params:
        T   = Associative array type
        V   = Type of the AA value (deduced from the first arg)
        K   = Type of the AA key (deduced from the first arg)

*******************************************************************************/

public template AAType (T : V[K], V, K)
{
    /***************************************************************************

        Key type for the AA

    ***************************************************************************/

    public alias K Key;


    /***************************************************************************

        Value type for the AA

    ***************************************************************************/

    public alias V Value;
}

unittest
{
    static assert(is(AAType!(ushort[ulong]).Key == ulong));
    static assert(is(AAType!(ushort[ulong]).Value == ushort));

    static assert(is(AAType!(istring[Object]).Key == Object));
    static assert(is(AAType!(istring[Object]).Value == istring));

    static assert(!is(AAType!(istring[]).Key));
    static assert(!is(AAType!(istring[]).Value));

    static assert(!is(AAType!(int[42]).Key));
    static assert(!is(AAType!(int[42]).Value));

    static assert(!is(AAType!(Object).Key));
    static assert(!is(AAType!(Object).Value));
}

/*******************************************************************************

    Emulates `static if (Type : Template!(Args), Args...)`, which is a D2
    feature

    Given a template and an instance of it, allows to get the arguments used
    to instantiate this type.

    An example use case is when you want to wrap an aggregate which is templated
    and need your `Wrapper` class to be templated on the aggregate's template
    arguments:
    ---
    class Wrapper (TArgs...) { /+ Magic stuff +/ }
    class Aggregate (TArgs...) { /+ Some more magic +/ }

    Wrapper!(TemplateInstanceArgs!(Aggregate, Inst)) wrap (Inst) (Inst i)
    {
        auto wrapper = new Wrapper!(TemplateInstanceArgs!(Aggregate, Inst))(i);
        return wrapper;
    }
    ---

    This can also be used to see if a given symbol is an instance of a template:
    `static if (is(TemplateInstanceArgs!(Template, PossibleInstance)))`

    Note that eponymous templates can lead to surprising behaviour:
    ---
    template Identity (T)
    {
        alias T Identity;
    }

    // The following will fail, because `Identity!(char)` resolves to `char` !
    static assert(is(TemplateInstanceArgs!(Identity, Identity!(char))));
    ---

    As a result, this template is better suited for template aggregates,
    or templates with multiple members.

    Params:
        Template = The template symbol (uninstantiated)
        Type     = An instance of `Template`

*******************************************************************************/

public template TemplateInstanceArgs (alias Template, Type : Template!(TA), TA...)
{
    public alias TA TemplateInstanceArgs;
}

version (UnitTest)
{
    private class BaseTestClass (T) {}
    private class DerivedTestClass (T) : BaseTestClass!(T) {}
}

unittest
{
    // Same type
    static assert (is(TemplateInstanceArgs!(BaseTestClass, BaseTestClass!(cstring))));
    // Derives
    static assert (is(TemplateInstanceArgs!(BaseTestClass, DerivedTestClass!(cstring))));
    // Not a template
    static assert (!is(TemplateInstanceArgs!(Object, BaseTestClass!(int))));
    // Not a type
    static assert (!is(TemplateInstanceArgs!(BaseTestClass, BaseTestClass)));
    // Doesn't derive / convert
    static assert (!is(TemplateInstanceArgs!(int, BaseTestClass)));
}
