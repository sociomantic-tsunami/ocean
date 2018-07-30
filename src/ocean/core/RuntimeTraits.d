/**
 * Provides runtime traits, which provide much of the functionality of ocean.core.Traits and
 * is-expressions, as well as some functionality that is only available at runtime, using
 * runtime type information.
 *
 * Authors: Chris Wright (dhasenan) $(EMAIL dhasenan@gmail.com)
 *
 * License:
 *     Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
 *     See LICENSE_TANGO.txt for details.
 *
 * Copyright:
 *     Copyright (c) 2009 CHRISTOPHER WRIGHT
 *     Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
 *     All rights reserved.
 *
 */
module ocean.core.RuntimeTraits;

import ocean.transition;

version(UnitTest) import ocean.core.Test;

/// If the given type represents a typedef, return the actual type.
TypeInfo realType (TypeInfo type)
{
    // TypeInfo_Typedef.next() doesn't return the actual type.
    // I think it returns TypeInfo_Typedef.base.next().
    // So, a slightly different method.

    version(D_Version2)
    {
        // copied from Tango-D2 project
        // makes use of realType to strip away qualifiers instead of adding
        // workaround to all other functions

        auto def = cast(TypeInfo_Enum) type;
        if (def !is null)
        {
            return def.base;
        }
        else if ((type.classinfo.name.length is 14  && type.classinfo.name[9..$] == "Const") ||
                 (type.classinfo.name.length is 18  && type.classinfo.name[9..$] == "Invariant") ||
                 (type.classinfo.name.length is 15  && type.classinfo.name[9..$] == "Shared") ||
                 (type.classinfo.name.length is 14  && type.classinfo.name[9..$] == "Inout"))
        {
            static if (__VERSION__ >= 2070)
                return (cast(TypeInfo_Const)type).base;
            else
                return (cast(TypeInfo_Const)type).next;
        }

        return type;
    }
    else
    {
        auto def = cast(TypeInfo_Typedef) type;
        if (def !is null)
        {
            return def.base;
        }
        return type;
    }
}

unittest
{
    mixin(Typedef!(int, "Type"));
    auto ti = typeid(Type);

    // expected semantical difference, runtime traits will
    // stop working for typedef'ed types in D2
    version(D_Version2)
    {
        test (realType(ti) == typeid(Type));
        test (realType(ti) != typeid(int));
    }
    else
    {
        test (realType(ti) == typeid(int));
    }
}

/// If the given type represents a class, return its ClassInfo; else return null;
ClassInfo asClass (TypeInfo type)
{
    if (isInterface (type))
    {
        auto klass = cast(TypeInfo_Interface) type;
        return klass.info;
    }
    if (isClass (type))
    {
        auto klass = cast(TypeInfo_Class) type;
        return cast(ClassInfo) klass.info;
    }
    return null;
}

unittest
{
    interface I {}
    class C : I { }

    test ( asClass(typeid(C)));
    test ( asClass(typeid(I)));
    test (!asClass(typeid(int)));
}

/** Returns true iff one type is an ancestor of the other, or if the types are the same.
 * If either is null, returns false. */
bool isDerived (ClassInfo derived, ClassInfo base)
{
    if (derived is null || base is null)
        return false;
    do
        if (derived is base)
            return true;
    while ((derived = derived.base) !is null);
    return false;
}

unittest
{
    class A {}
    class B : A { }
    class C { }

    test ( isDerived(A.classinfo, A.classinfo));
    test ( isDerived(B.classinfo, A.classinfo));
    test (!isDerived(B.classinfo, C.classinfo));
}

/** Returns true iff implementor implements the interface described
 * by iface. This is an expensive operation (linear in the number of
 * interfaces and base classes).
 */
bool implements (ClassInfo implementor, ClassInfo iface)
{
    foreach (info; applyInterfaces (implementor))
    {
        if (iface is info)
            return true;
    }
    return false;
}

unittest
{
    interface I { }
    class C1 : I { }
    class C2 { }

    test ( implements(C1.classinfo, I.classinfo));
    test (!implements(C2.classinfo, I.classinfo));
}

/** Returns true iff an instance of class test is implicitly castable to target.
 * This is an expensive operation (isDerived + implements). */
bool isImplicitly (ClassInfo test, ClassInfo target)
{
    // Keep isDerived first.
    // isDerived will be much faster than implements.
    return (isDerived (test, target) || implements (test, target));
}

unittest
{
    interface I { }
    class Base { }
    class Deriv : Base, I { }

    test ( isImplicitly(Deriv.classinfo, Base.classinfo));
    test ( isImplicitly(Deriv.classinfo, I.classinfo));
    test (!isImplicitly(Base.classinfo, I.classinfo));
}

/** Returns true iff an instance of type test is implicitly castable to target.
 * If the types describe classes or interfaces, this is an expensive operation. */
bool isImplicitly (TypeInfo test, TypeInfo target)
{
    // A lot of special cases. This is ugly.
    if (test is target)
        return true;
    if (isStaticArray (test) && isDynamicArray (target) && valueType (test) is valueType (target))
    {
        // you can implicitly cast static to dynamic (currently) if they
        // have the same value type. Other casts should be forbidden.
        return true;
    }
    auto klass1 = asClass (test);
    auto klass2 = asClass (target);
    if (isClass (test) && isClass (target))
    {
        return isDerived (klass1, klass2);
    }
    if (isInterface (test) && isInterface (target))
    {
        return isDerived (klass1, klass2);
    }
    if (klass1 && klass2)
    {
        return isImplicitly (klass1, klass2);
    }
    if (klass1 || klass2)
    {
        // no casts from class to non-class
        return false;
    }
    if ((isSignedInteger (test) && isSignedInteger (target)) || (isUnsignedInteger (test) && isUnsignedInteger (target)) || (isFloat (
            test) && isFloat (target)) || (isCharacter (test) && isCharacter (target)))
    {
        return test.tsize () <= target.tsize ();
    }
    if (isSignedInteger (test) && isUnsignedInteger (target))
    {
        // potential loss of data
        return false;
    }
    if (isUnsignedInteger (test) && isSignedInteger (target))
    {
        // if the sizes are the same, you could be losing data
        // the upper half of the range wraps around to negatives
        // if the target type is larger, you can safely hold it
        return test.tsize () < target.tsize ();
    }
    // delegates and functions: no can do
    // pointers: no
    // structs: no
    return false;
}

unittest
{
    test ( isImplicitly(typeid(int),  typeid(int)));
    test ( isImplicitly(typeid(int),  typeid(long)));
    test ( isImplicitly(typeid(uint), typeid(long)));
    test (!isImplicitly(typeid(long), typeid(int)));
    test (!isImplicitly(typeid(long), typeid(char)));
    test (!isImplicitly(typeid(int),  typeid(uint)));


    test ( isImplicitly(typeid(ubyte[3]), typeid(ubyte[])));
    test (!isImplicitly(typeid(ubyte[3]), typeid(byte[])));
}

///
ClassInfo[] baseClasses (ClassInfo type)
{
    if (type is null)
        return null;
    ClassInfo[] types;
    while ((type = type.base) !is null)
        types ~= type;
    return types;
}

unittest
{
    class A     { }
    class B : A { }
    class C : B { }

    auto ti_arr = baseClasses(C.classinfo);
    test (ti_arr == [ B.classinfo, A.classinfo, Object.classinfo ]);
}

/** Returns a list of all interfaces that this type implements, directly
 * or indirectly. This includes base interfaces of types the class implements,
 * and interfaces that base classes implement, and base interfaces of interfaces
 * that base classes implement. This is an expensive operation. */
ClassInfo[] baseInterfaces (ClassInfo type)
{
    if (type is null)
        return null;
    ClassInfo[] types = directInterfaces (type);
    while ((type = type.base) !is null)
    {
        types ~= interfaceGraph (type);
    }
    return types;
}

unittest
{
    interface I1 { }
    interface I2 { }
    interface I3 { }
    class A : I3 { }
    class B : A, I1, I2 { }

    auto ti_arr = baseInterfaces(B.classinfo);
    test (ti_arr == [ I1.classinfo, I2.classinfo, I3.classinfo]);
}

/** Returns all the interfaces that this type directly implements, including
 * inherited interfaces. This is an expensive operation.
 *
 * Examples:
 * ---
 * interface I1 {}
 * interface I2 : I1 {}
 * class A : I2 {}
 *
 * auto interfaces = interfaceGraph (A.classinfo);
 * // interfaces = [I2.classinfo, I1.classinfo]
 * ---
 *
 * ---
 * interface I1 {}
 * interface I2 {}
 * class A : I1 {}
 * class B : A, I2 {}
 *
 * auto interfaces = interfaceGraph (B.classinfo);
 * // interfaces = [I2.classinfo]
 * ---
 */
ClassInfo[] interfaceGraph (ClassInfo type)
{
    ClassInfo[] info;
    foreach (iface; type.interfaces)
    {
        info ~= iface.classinfo;
        info ~= interfaceGraph (iface.classinfo);
    }
    return info;
}

unittest
{
    interface I1 {}
    interface I2 : I1 {}
    class A : I2 {}

    test (interfaceGraph (A.classinfo) == [ I2.classinfo, I1.classinfo ]);

    interface I3 {}
    class B1 : I1 {}
    class B2 : B1, I3 {}

    test (interfaceGraph (B2.classinfo) == [ I3.classinfo ]);
}

/** Iterate through all interfaces that type implements, directly or indirectly, including base interfaces. */
struct applyInterfaces
{
    ///
    static applyInterfaces opCall (ClassInfo type)
    {
        applyInterfaces apply;
        apply.type = type;
        return apply;
    }

    ///
    int opApply (scope int delegate (ref ClassInfo) dg)
    {
        int result = 0;
        for (; type; type = type.base)
        {
            foreach (iface; type.interfaces)
            {
                result = dg (iface.classinfo);
                if (result)
                    return result;
                result = applyInterfaces (iface.classinfo).opApply (dg);
                if (result)
                    return result;
            }
        }
        return result;
    }

    ClassInfo type;
}

unittest
{
    interface I1 {}
    interface I2 : I1 {}
    interface I3 {}
    interface I4 {}
    class A : I4 {}
    class B : A, I2, I3 {}

    size_t count = 0;

    foreach (_; applyInterfaces(B.classinfo))
        ++count;

    test (count == 4);
}

///
ClassInfo[] baseTypes (ClassInfo type)
{
    if (type is null)
        return null;
    return baseClasses (type) ~ baseInterfaces (type);
}

unittest
{
    interface I {}
    class A : I {}
    class B : A {}

    test (baseTypes(B.classinfo) ==
        [ A.classinfo, Object.classinfo, I.classinfo ]);
}

///
ModuleInfoPtr moduleOf (ClassInfo type)
{
    foreach (modula; ModuleInfo)
        foreach (klass; modula.localClasses)
            if (klass is type)
                return modula;
    return null;
}

version (UnitTest)
{
    class Test { }
}

unittest
{
    auto modinfo = moduleOf(Test.classinfo);
    test (modinfo);
    test (modinfo.name == "ocean.core.RuntimeTraits");
}

/// Returns a list of interfaces that this class directly implements.
ClassInfo[] directInterfaces (ClassInfo type)
{
    ClassInfo[] types;
    foreach (iface; type.interfaces)
        types ~= iface.classinfo;
    return types;
}

unittest
{
    interface I1 {}
    interface I2 {}
    class A : I1 {}
    class B : A, I2 {}

    test (directInterfaces(B.classinfo) == [ I2.classinfo ]);
}

/** Returns a list of all types that are derived from the given type. This does not
 * count interfaces; that is, if type is an interface, you will only get derived
 * interfaces back. It is an expensive operations. */
ClassInfo[] derivedTypes (ClassInfo type)
{
    ClassInfo[] types;
    foreach (modula; ModuleInfo)
        foreach (klass; modula.localClasses)
            if (isDerived (klass, type) && (klass !is type))
                types ~= klass;
    return types;
}

version (UnitTest)
{
    class TestDeriv : Test { }
}

unittest
{
    test (derivedTypes(Test.classinfo) == [ TestDeriv.classinfo ]);
}

///
bool isDynamicArray (TypeInfo type)
{
    // This implementation is evil.
    // Array typeinfos are named TypeInfo_A?, and defined individually for each
    // possible type aside from structs. For example, typeinfo for int[] is
    // TypeInfo_Ai; for uint[], TypeInfo_Ak.
    // So any TypeInfo with length 11 and starting with TypeInfo_A is an array
    // type.
    // Also, TypeInfo_Array is an array type.
    type = realType (type);
    return ((type.classinfo.name[9] == 'A') && (type.classinfo.name.length == 11)) || ((cast(TypeInfo_Array) type) !is null);
}

unittest
{
    int[] arr;
    test (isDynamicArray(typeid(typeof(arr))));

    version (D_Version2)
    {
        auto str = "aaa"d;
        test (isDynamicArray(typeid(typeof(str))));
    }
}

///
bool isStaticArray (TypeInfo type)
{
    type = realType (type);
    return (cast(TypeInfo_StaticArray) type) !is null;
}

unittest
{
    int[5] arr;
    test (isStaticArray(typeid(typeof(arr))));

    version (D_Version2) { }
    else
    {
        auto str = "aaa"d;
        test (isStaticArray(typeid(typeof(str))));
    }
}

/** Returns true iff the given type is a dynamic or static array (false for associative
 * arrays and non-arrays). */
bool isArray (TypeInfo type)
{
    type = realType (type);
    return isDynamicArray (type) || isStaticArray (type);
}

unittest
{
    test ( isArray(typeid(int[])));
    test ( isArray(typeid(int[2])));
    test (!isArray(typeid(int)));
    test (!isArray(typeid(int[int])));

    Const!(char[]) arr;
    test ( isArray(typeid(typeof(arr))));
}

///
bool isAssociativeArray (TypeInfo type)
{
    type = realType (type);
    return (cast(TypeInfo_AssociativeArray) type) !is null;
}

unittest
{
    test (!isAssociativeArray(typeid(int[])));
    test (!isAssociativeArray(typeid(int[2])));
    test (!isAssociativeArray(typeid(int)));
    test ( isAssociativeArray(typeid(int[int])));
}

///
bool isCharacter (TypeInfo type)
{
    type = realType (type);
    return (type is typeid(char) || type is typeid(wchar) || type is typeid(dchar));
}

unittest
{
    test ( isCharacter(typeid(typeof("a"[0]))));
    test ( isCharacter(typeid(char)));
    test ( isCharacter(typeid(dchar)));
    test (!isCharacter(typeid(ubyte)));
}

///
bool isString (TypeInfo type)
{
    type = realType (type);
    return isArray (type) && isCharacter (valueType (type));
}

unittest
{
    test ( isString(typeid(typeof("aaa"))));
    test ( isString(typeid(typeof("aaa"d))));
    test ( isString(typeid(char[])));
    test (!isString(typeid(ubyte[])));
    test (!isString(typeid(int)));

    Const!(char[]) arr;
    test ( isString(typeid(typeof(arr))));
}

///
bool isUnsignedInteger (TypeInfo type)
{
    type = realType (type);
    return (type is typeid(uint) || type is typeid(ulong) || type is typeid(ushort) || type is typeid(ubyte));
}

unittest
{
    test ( isUnsignedInteger(typeid(uint)));
    test (!isUnsignedInteger(typeid(int)));
    test (!isUnsignedInteger(typeid(char)));
}

///
bool isSignedInteger (TypeInfo type)
{
    type = realType (type);
    return (type is typeid(int) || type is typeid(long) || type is typeid(short) || type is typeid(byte));
}

unittest
{
    test (!isSignedInteger(typeid(uint)));
    test ( isSignedInteger(typeid(int)));
    test (!isSignedInteger(typeid(char)));
}

///
bool isInteger (TypeInfo type)
{
    type = realType (type);
    return isSignedInteger (type) || isUnsignedInteger (type);
}

unittest
{
    test ( isInteger(typeid(uint)));
    test ( isInteger(typeid(int)));
    test (!isInteger(typeid(char)));
}

///
bool isBool (TypeInfo type)
{
    type = realType (type);
    return (type is typeid(bool));
}

unittest
{
    test (isBool(typeid(bool)));
}

///
bool isFloat (TypeInfo type)
{
    type = realType (type);
    return (type is typeid(float) || type is typeid(double) || type is typeid(real));
}

unittest
{
    test (isFloat (typeid(real)));
    test (isFloat (typeid(double)));
    test (isFloat (typeid(float)));
    test (!isFloat (typeid(creal)));
    test (!isFloat (typeid(cdouble)));
}

///
bool isPrimitive (TypeInfo type)
{
    type = realType (type);
    return (isArray (type) || isAssociativeArray (type) || isCharacter (type) || isFloat (type) || isInteger (type));
}

unittest
{
    struct S { }

    test ( isPrimitive(typeid(double)));
    test (!isPrimitive(typeid(S)));
}

/// Returns true iff the given type represents an interface.
bool isInterface (TypeInfo type)
{
    return (cast(TypeInfo_Interface) type) !is null;
}

unittest
{
    interface I { }

    test (isInterface(typeid(I)));
}

///
bool isPointer (TypeInfo type)
{
    type = realType (type);
    return (cast(TypeInfo_Pointer) type) !is null;
}

unittest
{
    test (isPointer(typeid(int*)));
}

/// Returns true iff the type represents a class (false for interfaces).
bool isClass (TypeInfo type)
{
    type = realType (type);
    return (cast(TypeInfo_Class) type) !is null;
}

unittest
{
    class C { }

    test (isClass(typeid(C)));
}

///
bool isStruct (TypeInfo type)
{
    type = realType (type);
    return (cast(TypeInfo_Struct) type) !is null;
}

unittest
{
    struct S { }

    test (isStruct(typeid(S)));
}

///
bool isFunction (TypeInfo type)
{
    type = realType (type);
    return ((cast(TypeInfo_Function) type) !is null) || ((cast(TypeInfo_Delegate) type) !is null);
}

unittest
{
    static void foo() {}

    test (isFunction(typeid(void delegate())));
    test (isFunction(typeid(typeof(foo))));

    // doesn't work, it is TypeInfo_Pointer :(
    // assert (isFunction(typeid(void function())));
}

/** Returns true iff the given type is a reference type. */
bool isReferenceType (TypeInfo type)
{
    return isClass (type) || isPointer (type) || isDynamicArray (type);
}

unittest
{
    class C {}

    test (isReferenceType(typeid(C)));
    test (isReferenceType(typeid(int*)));
    test (isReferenceType(typeid(int[])));

    version (D_Version2)
    {
        test (isReferenceType(typeid(typeof("aaa"))));
    }
    else
    {
        test (!isReferenceType(typeid(typeof("aaa"))));
    }

    test (!isReferenceType(typeid(int)));
}

/** Returns true iff the given type represents a user-defined type.
 * This does not include functions, delegates, aliases, or typedefs. */
bool isUserDefined (TypeInfo type)
{
    return isClass (type) || isStruct (type);
}

unittest
{
    test (isUserDefined(typeid(Object))); // true story
}

/** Returns true for all value types, false for all reference types.
 * For functions and delegates, returns false (is this the way it should be?). */
bool isValueType (TypeInfo type)
{
    return !(isDynamicArray (type) || isAssociativeArray (type) || isPointer (type) || isClass (type) || isFunction (
            type));
}

unittest
{
    test ( isValueType(typeid(int)));
    test (!isValueType(typeid(int*)));
    test (!isValueType(typeid(int[])));

    struct S {}
    class  C {}

    test ( isValueType(typeid(S)));
    test (!isValueType(typeid(S*)));
    test (!isValueType(typeid(C)));

    test (!isValueType(typeid(void function())));
    test (!isValueType(typeid(void delegate())));
}

/** The key type of the given type. For an array, size_t; for an associative
 * array T[U], U. */
TypeInfo keyType (TypeInfo type)
{
    type = realType (type);
    auto assocArray = cast(TypeInfo_AssociativeArray) type;
    if (assocArray)
        return assocArray.key;
    if (isArray (type))
        return typeid(size_t);
    return null;
}

unittest
{
    test (keyType(typeid(int[])) == typeid(size_t));
    test (keyType(typeid(int[char])) == typeid(char));
    test (keyType(typeid(int[istring])) == typeid(istring));
}

/** The value type of the given type -- given T[] or T[n], T; given T[U],
 * T; given T*, T; anything else, null. */
TypeInfo valueType (TypeInfo type)
{
    type = realType (type);
    if (isArray (type))
        return type.next;
    auto assocArray = cast(TypeInfo_AssociativeArray) type;
    if (assocArray)
        return assocArray.value;
    auto pointer = cast(TypeInfo_Pointer) type;
    if (pointer)
        return pointer.m_next;
    return null;
}

unittest
{
    test (valueType(typeid(char[])) == typeid(char));
    test (valueType(typeid(char[int])) == typeid(char));
    test (valueType(typeid(istring[int])) == typeid(istring));
}

/** If the given type represents a delegate or function, the return type
 * of that function. Otherwise, null. */
TypeInfo returnType (TypeInfo type)
{
    type = realType (type);
    auto delegat = cast(TypeInfo_Delegate) type;
    if (delegat)
        return delegat.next;
    auto func = cast(TypeInfo_Function) type;
    if (func)
        return func.next;
    return null;
}

unittest
{
    test (returnType(typeid(void delegate())) == typeid(void));

    static int foo() { return int.init; }
    test (returnType(typeid(typeof(foo))) == typeid(int));

    // NB: doesn't work, crashes the app!
    // assert (returnType(typeid(int function())) == typeid(int));

    test (!returnType(typeid(Object)));
}
