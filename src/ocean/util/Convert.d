/**
 * This module provides a templated function that performs value-preserving
 * conversions between arbitrary types.  This function's behaviour can be
 * extended for user-defined types as needed.
 *
 * Copyright:
 *     Copyright &copy; 2007 Daniel Keep.
 *     Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
 *     All rights reserved.
 *
 * License:
 *     Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
 *     See LICENSE_TANGO.txt for details.
 *
 * Authors: Daniel Keep
 *
 * Credits: Inspired in part by Andrei Alexandrescu's work on std.conv.
 *
 */

module ocean.util.Convert;

import ocean.transition;

import ocean.core.ExceptionDefinitions;

import ocean.meta.traits.Basic;
import ocean.meta.traits.Aggregates;
import ocean.meta.traits.Arrays;
import ocean.meta.types.Arrays;
import ocean.meta.types.Typedef;

import ocean.math.Math;
import ocean.text.convert.Utf;
import ocean.text.convert.Float;
import ocean.text.convert.Integer_tango;

version(UnitTest) import ocean.core.Test;

import Ascii = ocean.text.Ascii;

version( TangoDoc )
{
    /**
     * Attempts to perform a value-preserving conversion of the given value
     * from type S to type D.  If the conversion cannot be performed in any
     * context, a compile-time error will be issued describing the types
     * involved.  If the conversion fails at run-time because the destination
     * type could not represent the value being converted, a
     * ConversionException will be thrown.
     *
     * For example, to convert the string "123" into an equivalent integer
     * value, you would use:
     *
     * -----
     * auto v = to!(int)("123");
     * -----
     *
     * You may also specify a default value which should be returned in the
     * event that the conversion cannot take place:
     *
     * -----
     * auto v = to!(int)("abc", 456);
     * -----
     *
     * The function will attempt to preserve the input value as exactly as
     * possible, given the limitations of the destination format.  For
     * instance, converting a floating-point value to an integer will cause it
     * to round the value to the nearest integer value.
     *
     * Below is a complete list of conversions between built-in types and
     * strings.  Capitalised names indicate classes of types.  Conversions
     * between types in the same class are also possible.
     *
     * -----
     * bool         <-- Integer (0/!0), Char ('t'/'f'), String ("true"/"false")
     * Integer      <-- bool, Real, Char ('0'-'9'), String
     * Real         <-- Integer, String
     * Imaginary    <-- Complex
     * Complex      <-- Integer, Real, Imaginary
     * Char         <-- bool, Integer (0-9)
     * String       <-- bool, Integer, Real, Char
     * -----
     *
     * Conversions between arrays and associative arrays are also supported,
     * and are done element-by-element.
     *
     * You can add support for value conversions to your types by defining
     * appropriate static and instance member functions.  Given a type
     * the_type, any of the following members of a type T may be used:
     *
     * -----
     * the_type to_the_type();
     * static T from_the_type(the_type);
     * -----
     *
     * You may also use "camel case" names:
     *
     * -----
     * the_type toTheType();
     * static T fromTheType(the_type);
     * -----
     *
     * Arrays and associative arrays can also be explicitly supported:
     *
     * -----
     * the_type[] to_the_type_array();
     * the_type[] toTheTypeArray();
     *
     * static T from_the_type_array(the_type[]);
     * static T fromTheTypeArray(the_type[]);
     *
     * the_type[int] to_int_to_the_type_map();
     * the_type[int] toIntToTheTypeMap();
     *
     * static T from_int_to_the_type_map(the_type[int]);
     * static T fromIntToTheTypeMap(the_type[int]);
     * -----
     *
     * If you have more complex requirements, you can also use the generic to
     * and from templated members:
     *
     * -----
     * the_type to(the_type)();
     * static T from(the_type)(the_type);
     * -----
     *
     * These templates will have the_type explicitly passed to them in the
     * template instantiation.
     *
     * Finally, strings are given special support.  The following members will
     * be checked for:
     *
     * -----
     * char[]  toString();
     * wchar[] toString16();
     * dchar[] toString32();
     * char[]  toString();
     * -----
     *
     * The "toString_" method corresponding to the destination string type will be
     * tried first.  If this method does not exist, then the function will
     * look for another "toString_" method from which it will convert the result.
     * Failing this, it will try "toString" and convert the result to the
     * appropriate encoding.
     *
     * The rules for converting to a user-defined type are much the same,
     * except it makes use of the "fromUtf8", "fromUtf16", "fromUtf32" and
     * "fromString" static methods.
     *
     * Note: This module contains imports to other Tango modules that needs
     * semantic analysis to be discovered. If your build tool doesn't do this
     * properly, causing compile or link time problems, import the relevant
     * module explicitly.
     */
    D to(D,S)(S value);
    D to(D,S)(S value, D default_); /// ditto
}
else
{
    template to(D)
    {
        D to(S, Def=Missing)(S value, Def def=Def.init)
        {
            static if( is( Def == Missing ) )
                return toImpl!(D,S)(value);

            else
            {
                try
                {
                    return toImpl!(D,S)(value);
                }
                catch( ConversionException e )
                    {}

                return def;
            }
        }
    }
}

/**
 * This exception is thrown when the to template is unable to perform a
 * conversion at run-time.  This typically occurs when the source value cannot
 * be represented in the destination type.  This exception is also thrown when
 * the conversion would cause an over- or underflow.
 */
class ConversionException : Exception
{
    this( istring msg )
    {
        super( msg );
    }
}

private:

mixin(Typedef!(int, "Missing"));

/*
 * So, how is this module structured?
 *
 * Firstly, we need a bunch of support code.  The first block of this contains
 * some CTFE functions for string manipulation (to cut down on the number of
 * template symbols we generate.)
 *
 * The next contains a boat-load of templates.  Most of these are trait
 * templates (things like isPOD, isObject, etc.)  There are also a number of
 * mixins, and some switching templates (like toString_(n).)
 *
 * Another thing to mention is intCmp, which performs a safe comparison
 * between two integers of arbitrary size and signage.
 *
 * Following all this are the templated to* implementations.
 *
 * The actual toImpl template is the second last thing in the module, with the
 * module unit tests coming last.
 */

char ctfe_upper(char c)
{
    if( 'a' <= c && c <= 'z' )
        return cast(char)((c - 'a') + 'A');
    else
        return c;
}

istring ctfe_camelCase(istring s)
{
    istring result;

    bool nextIsCapital = true;

    foreach( c ; s )
    {
        if( nextIsCapital )
        {
            if( c == '_' )
                result ~= c;
            else
            {
                result ~= ctfe_upper(c);
                nextIsCapital = false;
            }
        }
        else
        {
            if( c == '_' )
                nextIsCapital = true;
            else
                result ~= c;
        }
    }

    return result;
}

bool ctfe_isSpace(T)(T c)
{
    static if (T.sizeof is 1)
        return (c <= 32 && (c is ' ' || c is '\t' || c is '\r'
                    || c is '\n' || c is '\v' || c is '\f'));
    else
        return (c <= 32 && (c is ' ' || c is '\t' || c is '\r'
                    || c is '\n' || c is '\v' || c is '\f'))
            || (c is '\u2028' || c is '\u2029');
}

T[] ctfe_triml(T)(T[] source)
{
    if( source.length == 0 )
        return null;

    foreach( i,c ; source )
        if( !ctfe_isSpace(c) )
            return source[i..$];

    return null;
}

T[] ctfe_trimr(T)(T[] source)
{
    if( source.length == 0 )
        return null;

    foreach_reverse( i,c ; source )
        if( !ctfe_isSpace(c) )
            return source[0..i+1];

    return null;
}

T[] ctfe_trim(T)(T[] source)
{
    return ctfe_trimr(ctfe_triml(source));
}

template isString(T)
{
    static if (isBasicArrayType!(T))
        static immutable isString = isCharType!(ElementTypeOf!(T));
    else
        static immutable isString = false;
}

unittest
{
    static assert (isString!(typeof("literal"[])));
}

/*
 * Determines which signed integer type of T and U is larger.
 */
template sintSuperType(T,U)
{
    static if( is( T == long ) || is( U == long ) )
        alias long sintSuperType;
    else static if( is( T == int ) || is( U == int ) )
        alias int sintSuperType;
    else static if( is( T == short ) || is( U == short ) )
        alias short sintSuperType;
    else static if( is( T == byte ) || is( U == byte ) )
        alias byte sintSuperType;
}

/*
 * Determines which unsigned integer type of T and U is larger.
 */
template uintSuperType(T,U)
{
    static if( is( T == ulong ) || is( U == ulong ) )
        alias ulong uintSuperType;
    else static if( is( T == uint ) || is( U == uint ) )
        alias uint uintSuperType;
    else static if( is( T == ushort ) || is( U == ushort ) )
        alias ushort uintSuperType;
    else static if( is( T == ubyte ) || is( U == ubyte ) )
        alias ubyte uintSuperType;
}

template uintOfSize(uint bytes)
{
    static if( bytes == 1 )
        alias ubyte uintOfSize;
    else static if( bytes == 2 )
        alias ushort uintOfSize;
    else static if( bytes == 4 )
        alias uint uintOfSize;
}

/*
 * Safely performs a comparison between two integer values, taking into
 * account different sizes and signages.
 */
int intCmp(T,U)(T lhs, U rhs)
{
    static if( isSignedIntegerType!(T) && isSignedIntegerType!(U) )
    {
        alias sintSuperType!(T,U) S;
        auto l = cast(S) lhs;
        auto r = cast(S) rhs;
        if( l < r ) return -1;
        else if( l > r ) return 1;
        else return 0;
    }
    else static if( isUnsignedIntegerType!(T) && isUnsignedIntegerType!(U) )
    {
        alias uintSuperType!(T,U) S;
        auto l = cast(S) lhs;
        auto r = cast(S) rhs;
        if( l < r ) return -1;
        else if( l > r ) return 1;
        else return 0;
    }
    else
    {
        static if( isSignedIntegerType!(T) )
        {
            if( lhs < 0 )
                return -1;
            else
            {
                static if( U.sizeof >= T.sizeof )
                {
                    auto l = cast(U) lhs;
                    if( l < rhs ) return -1;
                    else if( l > rhs ) return 1;
                    else return 0;
                }
                else
                {
                    auto l = cast(ulong) lhs;
                    auto r = cast(ulong) rhs;
                    if( l < r ) return -1;
                    else if( l > r ) return 1;
                    else return 0;
                }
            }
        }
        else static if( isSignedIntegerType!(U) )
        {
            if( rhs < 0 )
                return 1;
            else
            {
                static if( T.sizeof >= U.sizeof )
                {
                    auto r = cast(T) rhs;
                    if( lhs < r ) return -1;
                    else if( lhs > r ) return 1;
                    else return 0;
                }
                else
                {
                    auto l = cast(ulong) lhs;
                    auto r = cast(ulong) rhs;
                    if( l < r ) return -1;
                    else if( l > r ) return 1;
                    else return 0;
                }
            }
        }
    }
}

template unsupported(istring desc="")
{
    static assert(false, "Unsupported conversion: cannot convert to "
            ~ctfe_trim(D.stringof)~" from "
            ~(desc!="" ? desc~" " : "")~ctfe_trim(S.stringof)~".");
}

template unsupported_backwards(istring desc="")
{
    static assert(false, "Unsupported conversion: cannot convert to "
            ~(desc!="" ? desc~" " : "")~ctfe_trim(D.stringof)
            ~" from "~ctfe_trim(S.stringof)~".");
}

// TN works out the c_case name of the given type.
template TN(T:T[])
{
    static if( is( T == char ) )
        static immutable TN = "string";
    else static if( is( T == wchar ) )
        static immutable TN = "wstring";
    else static if( is( T == dchar ) )
        static immutable TN = "dstring";
    else
        static immutable TN = TN!(T)~"_array";
}

// ditto
template TN(T:T*)
{
    static immutable TN = TN!(T)~"_pointer";
}

// ditto
template TN(T)
{
    static if( isArrayType!(T) == ArrayKind.Associative )
        static immutable TN = TN!(typeof(T.keys[0]))~"_to_"
            ~TN!(typeof(T.values[0]))~"_map";
    else
        static immutable TN = ctfe_trim(T.stringof);
}

// Picks an appropriate toString* method from t.text.convert.Utf.
template toString_(T)
{
    static if( is( T == char[] ) )
        alias ocean.text.convert.Utf.toString toString_;

    else static if( is( T == wchar[] ) )
        alias ocean.text.convert.Utf.toString16 toString_;

    else
        alias ocean.text.convert.Utf.toString32 toString_;
}

template UtfNum(T)
{
    static immutable UtfNum = is(typeof(T[0])==char) ? "8" : (
            is(typeof(T[0])==wchar) ? "16" : "32");
}

template StringNum(T)
{
    static immutable StringNum = is(Unqual!(typeof(T.init[0]))==char) ? "" : (
            is(Unqual!(typeof(T.init[0]))==wchar) ? "16" : "32");
}

// Decodes a single dchar character from a string.  Yes, I know they're
// actually code points, but I can't be bothered to type that much.  Although
// I suppose I just typed MORE than that by writing this comment.  Meh.
dchar firstCharOf(T)(T s, out size_t used)
{
    static if( is( T : char[] ) || is( T : wchar[] ) )
    {
        return ocean.text.convert.Utf.decode(s, used);
    }
    else
    {
        used = 1;
        return s[0];
    }
}

// This mixin defines a general function for converting to a UDT.
template toUDT()
{
    D toDfromS()
    {
        static if( isString!(S) )
        {
            static if( is( typeof(mixin("D.fromUtf"
                                ~UtfNum!(S)~"(value)")) : D ) )
                return mixin("D.fromUtf"~UtfNum!(S)~"(value)");

            else static if( is( typeof(D.fromUtf8(""c)) : D ) )
                return D.fromUtf8(toString_!(char[])(value));

            else static if( is( typeof(D.fromUtf16(""w)) : D ) )
                return D.fromUtf16(toString_!(wchar[])(value));

            else static if( is( typeof(D.fromUtf32(""d)) : D ) )
                return D.fromUtf32(toString_!(dchar[])(value));

            else static if( is( typeof(D.fromString(""c)) : D ) )
            {
                static if( is( S == char[] ) )
                    return D.fromString(value);

                else
                    return D.fromString(toString_!(char[])(value));
            }

            // Default fallbacks

            else static if( is( typeof(D.from!(S)(value)) : D ) )
                return D.from!(S)(value);

            else
                mixin unsupported!("user-defined type");
        }
        else
        {
            // TODO: Check for templates.  Dunno what to do about them.

            static if( is( typeof(mixin("D.from_"~TN!(S)~"()")) : D ) )
                return mixin("D.from_"~TN!(S)~"()");

            else static if( is( typeof(mixin("D.from"
                                ~ctfe_camelCase(TN!(S))~"()")) : D ) )
                return mixin("D.from"~ctfe_camelCase(TN!(S))~"()");

            else static if( is( typeof(D.from!(S)(value)) : D ) )
                return D.from!(S)(value);

            else
                mixin unsupported!("user-defined type");
        }
    }
}

// This mixin defines a general function for converting from a UDT.
template fromUDT(istring fallthrough="")
{
    D toDfromS()
    {
        static if( isString!(D) )
        {
            static if( is( typeof(value.toString()) ) )
                return toStringFromString!(D)(value.toString());

            else static if( is( typeof(value.toString16()) ) )
                return toStringFromString!(D)(value.toString16());

            else static if( is( typeof(value.toString32()) ) )
                return toStringFromString!(D)(value.toString32());

            // Default fallbacks

            else static if( is( typeof(value.to!(D)()) : D ) )
                return value.to!(D)();

            else static if( fallthrough != "" )
                mixin(fallthrough);

            else
                mixin unsupported!("user-defined type");
        }
        else
        {
            // TODO: Check for templates.  Dunno what to do about them.

            static if( is( typeof(mixin("value.to_"~TN!(D)~"()")) : D ) )
                return mixin("value.to_"~TN!(D)~"()");

            else static if( is( typeof(mixin("value.to"
                                ~ctfe_camelCase(TN!(D))~"()")) : D ) )
                return mixin("value.to"~ctfe_camelCase(TN!(D))~"()");

            else static if( is( typeof(value.to!(D)()) : D ) )
                return value.to!(D)();

            else static if( fallthrough != "" )
                mixin(fallthrough);

            else
                mixin unsupported!("user-defined type");
        }
    }
}

template convError()
{
    void throwConvError()
    {
        // Since we're going to use to!(T) to convert the value to a string,
        // we need to make sure we don't end up in a loop...
        static if( isString!(D) || !is( typeof(to!(istring)(value)) == istring ) )
        {
            throw new ConversionException("Could not convert a value of type "
                    ~S.stringof~" to type "~D.stringof~".");
        }
        else
        {
            throw new ConversionException("Could not convert `"
                    ~to!(istring)(value)~"` of type "
                    ~S.stringof~" to type "~D.stringof~".");
        }
    }
}

D toBool(D,S)(S value)
{
    static assert(is(D==bool));

    static if( isIntegerType!(S) /+|| isRealType!(S) || isImaginaryType!(S)
                || isComplexType!(S)+/ )
        // The weird comparison is to support NaN as true
        return !(value == 0);

    else static if( isCharType!(S) )
    {
        switch( value )
        {
            case 'F': case 'f':
                return false;

            case 'T': case 't':
                return true;

            default:
                mixin convError;
                throwConvError;
                assert(0);
        }
    }

    else static if( isString!(S) )
    {
        if (0 == Ascii.icompare(value, "true"))
            return true;
        if (0 == Ascii.icompare(value, "false"))
            return false;

        mixin convError;
        throwConvError;
        assert(0);
    }
    else static if( isAggregateType!(S) )
    {
        mixin fromUDT;
        return toDfromS;
    }
    else
    {
        mixin unsupported;
    }
}

D toIntegerFromInteger(D,S)(S value)
{
    static if( (cast(ulong) D.max) < (cast(ulong) S.max)
            || (cast(long) D.min) > (cast(long) S.min) )
    {
        mixin convError; // TODO: Overflow error

        if( intCmp(value,D.min)<0 || intCmp(value,D.max)>0 )
        {
            throwConvError;
        }
    }
    return cast(D) value;
}

D toIntegerFromReal(D,S)(S value)
{
    auto v = ocean.math.Math.round(value);
    if( (cast(real) D.min) <= v && v <= (cast(real) D.max) )
    {
        return cast(D) v;
    }
    else
    {
        mixin convError; // TODO: Overflow error
        throwConvError;
        assert(0);
    }
}

D toIntegerFromString(D,S)(S value)
{
    static if( is( S charT : charT[] ) )
    {
        mixin convError;

        static if( is( D == ulong ) )
        {
            // Check for sign
            S s = value;

            if( s.length == 0 )
                throwConvError;

            else if( s[0] == '-' )
                throwConvError;

            else if( s[0] == '+' )
                s = s[1..$];

            uint len;
            auto result = ocean.text.convert.Integer_tango.convert(s, 10, &len);

            if( len < s.length || len == 0 )
                throwConvError;

            return result;
        }
        else
        {
            uint len;
            auto result = ocean.text.convert.Integer_tango.parse(value, 10, &len);

            if( len < value.length || len == 0 )
                throwConvError;

            return toIntegerFromInteger!(D,long)(result);
        }
    }
}

D toInteger(D,S)(S value)
{
    static if( is( S == bool ) )
        return (value ? 1 : 0);

    else static if( isIntegerType!(S) )
    {
        return toIntegerFromInteger!(D,S)(value);
    }
    else static if( isCharType!(S) )
    {
        if( value >= '0' && value <= '9' )
        {
            return cast(D)(value - '0');
        }
        else
        {
            mixin convError;
            throwConvError;
            assert(0);
        }
    }
    else static if( isRealType!(S) )
    {
        return toIntegerFromReal!(D,S)(value);
    }
    else static if( isString!(S) )
    {
        return toIntegerFromString!(D,S)(value);
    }
    else static if( isAggregateType!(S) )
    {
        mixin fromUDT;
        return toDfromS;
    }
    else
        mixin unsupported;
}

D toReal(D,S)(S value)
{
    static if( isIntegerType!(S) || isRealType!(S) )
        return cast(D) value;

    else static if( isString!(S) )
    {
        mixin convError;

        uint len;
        auto r = ocean.text.convert.Float.parse(value, &len);
        if( len < value.length || len == 0 )
            throwConvError;

        return r;
    }

    else static if( isAggregateType!(S) )
    {
        mixin fromUDT;
        return toDfromS;
    }
    else
        mixin unsupported;
}

D toImaginary(D,S)(S value)
{
    static if ( isComplexType!(S) )
    {
        if( value.re == 0.0 )
            return value.im * cast(D)1.0i;

        else
        {
            mixin convError;
            throwConvError;
            assert(0);
        }
    }
    else static if( isAggregateType!(S) )
    {
        mixin fromUDT;
        return toDfromS;
    }
    else
        mixin unsupported;
}

D toComplex(D,S)(S value)
{
    static if( isIntegerType!(S) || isRealType!(S) || isImaginaryType!(S)
            || isComplexType!(S) )
        return cast(D) value;

    /+else static if( isCharType!(S) )
        return cast(D) to!(uint)(value);+/

    else static if( isAggregateType!(S) )
    {
        mixin fromUDT;
        return toDfromS;
    }
    else
        mixin unsupported;
}

D toChar(D,S)(S value)
{
    static if( is( S == bool ) )
        return (value ? 't' : 'f');

    else static if( isIntegerType!(S) )
    {
        if( value >= 0 && value <= 9 )
            return cast(D) (value + '0');

        else
        {
            mixin convError; // TODO: Overflow error
            throwConvError;
            assert(0);
        }
    }
    else static if( isString!(S) )
    {
        void fail()
        {
            mixin convError;
            throwConvError;
        }

        if( value.length == 0 )
            fail();

        else
        {
            auto str = toStringFromString!(D[])(value);
            if (str.length != 1)
                fail();
            return str[0];
        }
        assert(0);
    }
    else static if( isAggregateType!(S) )
    {
        mixin fromUDT;
        return toDfromS;
    }
    else
        mixin unsupported;
}

D toStringFromString(D,S)(S value)
{
    alias typeof(D.init[0]) DElem;
    // S.init[0] caused obscure compilation error, not important
    // enough to investigate
    alias typeof(value[0]) SElem;

    static if (is(S : D))
        return value;

    else static if (!isMutable!(DElem) || !isMutable!(SElem))
        // both cases require creating new string which makes
        // blindly casting result of transcoding to D inherently const correct
        return cast(D) toStringFromString!(Unqual!(DElem)[])(value.dup);

    else static if( is( DElem == char ) )
        return ocean.text.convert.Utf.toString(value);

    else static if( is( DElem == wchar ) )
        return ocean.text.convert.Utf.toString16(value);

    else
    {
        static assert( is( DElem == dchar ) );
        return ocean.text.convert.Utf.toString32(value);
    }
}

static immutable istring CHARS =
"\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2a\x2b\x2c\x2d\x2e\x2f"
~ "\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3a\x3b\x3c\x3d\x3e\x3f"
~ "\x40\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4a\x4b\x4c\x4d\x4e\x4f"
~ "\x50\x51\x52\x53\x54\x55\x56\x57\x58\x59\x5a\x5b\x5c\x5d\x5e\x5f"
~ "\x60\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6a\x6b\x6c\x6d\x6e\x6f"
~ "\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7a\x7b\x7c\x7d\x7e";

D toStringFromChar(D,S)(S value)
{
    static if( is( D == S[] ) )
    {
        static if (is(S == Const!(char))
                   || is(S == Immut!(char)))
        {
            if( 0x20 <= value && value <= 0x7e )
                return (&CHARS[value-0x20])[0..1];
        }
        auto r = new S[1];
        r[0] = value;
        return r;
    }
    else
    {
        S[1] temp;
        temp[0] = value;
        return toStringFromString!(D,S[])(temp);
    }
}

D toString(D,S)(S value)
{
    // casts to match const qualifier if any

    static if( is( S == bool ) )
        return (value ? to!(D)("true"[]) : to!(D)("false"[]));

    else static if( isCharType!(S) )
        return toStringFromChar!(D,S)(value);

    else static if( isIntegerType!(S) )
        // TODO: Make sure this works with ulongs.
        return cast(D) mixin("ocean.text.convert.Integer_tango.toString"~StringNum!(D)~"(value)");

    else static if( isRealType!(S) )
        return cast(D) mixin("ocean.text.convert.Float.toString"~StringNum!(D)~"(value)");

    else static if( isBasicArrayType!(S) )
        mixin unsupported!("array type");

    else static if( isArrayType!(S) == ArrayKind.Associative )
        mixin unsupported!("associative array type");

    else static if( isAggregateType!(S) )
    {
        mixin fromUDT;
        return toDfromS;
    }
    else
        mixin unsupported;
}

D fromString(D,S)(D value)
{
    static if( isBasicArrayType!(S) )
        mixin unsupported_backwards!("array type");

    else static if( isArrayType!(S) == ArrayKind.Associative )
        mixin unsupported_backwards!("associative array type");

    else static if( isBasicArrayType!(S) )
    {
        mixin toUDT;
        return toDfromS;
    }
    else
        mixin unsupported_backwards;
}

D toArrayFromArray(D,S)(S value)
{
    alias ElementTypeOf!(D) De;

    D result; result.length = value.length;
    scope(failure) delete result;

    foreach( i,e ; value )
        result[i] = to!(De)(e);

    return result;
}

D toMapFromMap(D,S)(S value)
{
    alias typeof(D.init.keys[0])   Dk;
    alias typeof(D.init.values[0]) Dv;

    D result;

    foreach( k,v ; value )
        result[ to!(Dk)(k) ] = to!(Dv)(v);

    return result;
}

D toFromUDT(D,S)(S value)
{
    // D2 Typedef
    static if ( isTypedef!(S) == TypedefKind.Struct )
        return to!(D)(value.value);
    // Try value.to*
    else static if ( hasMember!(S, "to_" ~ TN!(D)) )
        return mixin("value.to_"~TN!(D)~"()");
    else static if ( hasMember!(S, "to" ~ ctfe_camelCase(TN!(D))) )
        return mixin("value.to"~ctfe_camelCase(TN!(D))~"()");
    else static if ( hasMember!(S, "to") && is(typeof(value.to!(D))) )
        return value.to!(D)();
    // Try D.from*
    else static if( hasMember!(D, "from_" ~ TN!(S)) )
        return mixin("D.from_"~TN!(S)~"(value)");
    else static if( hasMember!(D, "from" ~ ctfe_camelCase(TN!(S))) )
        return mixin("D.from"~ctfe_camelCase(TN!(S))~"(value)");
    else static if ( hasMember!(D, "from") && is(typeof(D.from!(S)(value))) )
            return D.from!(S)(value);

    // Give up
    else
        mixin unsupported!();
}

D toImpl(D,S)(S value)
{
    static if( is( D == S ) )
        return value;

    else static if ( isTypedef!(S) == TypedefKind.Keyword )
        return toImpl!(D,TypedefBaseType!(S))(value);

    else static if ( isTypedef!(S) == TypedefKind.Struct )
        return toImpl!(D, typeof(S.value))(value.value);

    else static if( is( S BaseType == enum ) )
        return toImpl!(D,BaseType)(value);

    else static if( isBasicArrayType!(D) && isBasicArrayType!(S)
            && is( typeof(D[0]) == typeof(S[0]) ) )
        // Special-case which catches to!(T[])!(T[n]).
        return value;

    else static if( is( D == bool ) )
        return toBool!(D,S)(value);

    else static if( isIntegerType!(D) )
        return toInteger!(D,S)(value);

    else static if( isRealType!(D) )
        return toReal!(D,S)(value);

    else static if( isImaginaryType!(D) )
        return toImaginary!(D,S)(value);

    else static if( isComplexType!(D) )
        return toComplex!(D,S)(value);

    else static if( isCharType!(D) )
        return toChar!(D,S)(value);

    else static if( isString!(D) && isString!(S) )
        return toStringFromString!(D,S)(value);

    else static if( isString!(D) )
        return toString!(D,S)(value);

    else static if( isString!(S) )
        return fromString!(D,S)(value);

    else static if( isBasicArrayType!(D) && isBasicArrayType!(S) )
        return toArrayFromArray!(D,S)(value);

    else static if( isArrayType!(D) == ArrayKind.Associative
        && isArrayType!(S) == ArrayKind.Associative )
    {
        return toMapFromMap!(D,S)(value);
    }
    else static if( isAggregateType!(D) || isAggregateType!(S) )
        return toFromUDT!(D,S)(value);

    else
        mixin unsupported;
}

version (UnitTest)
{
    bool ex(T)(lazy T v)
    {
        bool result = false;
        try
        {
            v();
        }
        catch( ConversionException _ )
        {
            result = true;
        }
        return result;
    }

    bool nx(T)(lazy T v)
    {
        bool result = true;
        try
        {
            v();
        }
        catch( ConversionException _ )
        {
            result = false;
        }
        return result;
    }

    struct Foo
    {
        int toInt() { return 42; }

        istring toString() { return "string foo"; }

        int[] toIntArray() { return [1,2,3]; }

        Bar toBar()
        {
            Bar result; return result;
        }

        T to(T)()
        {
            static if( is( T == bool ) )
                return true;
            else
                static assert( false );
        }
    }

    struct Bar
    {
        real toReal()
        {
            return 3.14159;
        }

        ireal toIreal()
        {
            return 42.0i;
        }
    }

    struct Baz
    {
        static Baz fromFoo(Foo foo)
        {
            Baz result; return result;
        }

        Bar toBar()
        {
            Bar result; return result;
        }
    }
}

unittest
{
    /*
     * bool
     */
    static assert( !is( typeof(to!(bool)(1.0)) ) );
    static assert( !is( typeof(to!(bool)(1.0i)) ) );
    static assert( !is( typeof(to!(bool)(1.0+1.0i)) ) );

    test( to!(bool)(0) == false );
    test( to!(bool)(1) == true );
    test( to!(bool)(-1) == true );

    test( to!(bool)('t') == true );
    test( to!(bool)('T') == true );
    test( to!(bool)('f') == false );
    test( to!(bool)('F') == false );
    test(ex( to!(bool)('x') ));

    test( to!(bool)("true"[]) == true );
    test( to!(bool)("false"[]) == false );
    test( to!(bool)("TrUe"[]) == true );
    test( to!(bool)("fAlSe"[]) == false );

    /*
     * Integer
     */
    test( to!(int)(42L) == 42 );
    test( to!(byte)(42) == cast(byte)42 );
    test( to!(short)(-1701) == cast(short)-1701 );
    test( to!(long)(cast(ubyte)72) == 72L );

    test(nx( to!(byte)(127) ));
    test(ex( to!(byte)(128) ));
    test(nx( to!(byte)(-128) ));
    test(ex( to!(byte)(-129) ));

    test(nx( to!(ubyte)(255) ));
    test(ex( to!(ubyte)(256) ));
    test(nx( to!(ubyte)(0) ));
    test(ex( to!(ubyte)(-1) ));

    test(nx( to!(long)(9_223_372_036_854_775_807UL) ));
    test(ex( to!(long)(9_223_372_036_854_775_808UL) ));
    test(nx( to!(ulong)(0L) ));
    test(ex( to!(ulong)(-1L) ));

    test( to!(int)(3.14159) == 3 );
    test( to!(int)(2.71828) == 3 );

    test( to!(int)("1234"[]) == 1234 );

    test( to!(int)(true) == 1 );
    test( to!(int)(false) == 0 );

    test( to!(int)('0') == 0 );
    test( to!(int)('9') == 9 );

    /*
     * Real
     */
    test( to!(real)(3) == 3.0 );
    test( to!(real)("1.125"[]) == 1.125 );

    /*
     * Imaginary
     */
    static assert( !is( typeof(to!(ireal)(3.0)) ) );

    test( to!(ireal)(0.0+1.0i) == 1.0i );
    test(nx( to!(ireal)(0.0+1.0i) ));
    test(ex( to!(ireal)(1.0+0.0i) ));

    /*
     * Complex
     */
    test( to!(creal)(1) == (1.0+0.0i) );
    test( to!(creal)(2.0) == (2.0+0.0i) );
    test( to!(creal)(3.0i) == (0.0+3.0i) );

    /*
     * Char
     */
    test( to!(char)(true) == 't' );
    test( to!(char)(false) == 'f' );

    test( to!(char)(0) == '0' );
    test( to!(char)(9) == '9' );

    test(ex( to!(char)(-1) ));
    test(ex( to!(char)(10) ));

    test( to!(char)("a"d[]) == 'a' );
    test( to!(dchar)("ε"c[]) == 'ε' );

    test(ex( to!(char)("ε"d[]) ));

    /*
     * String-string
     */
    test( to!(char[])("Í love to æt "w[]) == "Í love to æt "c );
    test( to!(istring)("Í love to æt "w[]) == "Í love to æt "c );
    test( to!(char[])("them smûrƒies™,"d[]) == "them smûrƒies™,"c );
    test( to!(istring)("them smûrƒies™,"d[]) == "them smûrƒies™,"c );
    test( to!(wchar[])("Smûrﬁes™ I love"c[]) == "Smûrﬁes™ I love"w );
    test( to!(wchar[])("２ 食い散らす"d[]) == "２ 食い散らす"w );
    test( to!(dchar[])("bite đey µgly"c[]) == "bite đey µgly"d );
    test( to!(dchar[])("headž ㍳ff"w[]) == "headž ㍳ff"d );
    // ... nibble on they bluish feet.

    /*
     * String
     */
    test( to!(char[])(true) == "true" );
    test( to!(istring)(true) == "true" );
    test( to!(char[])(false) == "false" );

    test( to!(char[])(12345678) == "12345678" );
    test( to!(istring)(12345678) == "12345678" );
    test( to!(char[])(1234.567800) == "1234.57");
    test( to!(istring)(1234.567800) == "1234.57");

    test( to!( char[])(cast(char) 'a') == "a"c );
    test( to!(wchar[])(cast(char) 'b') == "b"w );
    test( to!(dchar[])(cast(char) 'c') == "c"d );
    test( to!( char[])(cast(wchar)'d') == "d"c );
    test( to!(wchar[])(cast(wchar)'e') == "e"w );
    test( to!(dchar[])(cast(wchar)'f') == "f"d );
    test( to!( char[])(cast(dchar)'g') == "g"c );
    test( to!(wchar[])(cast(dchar)'h') == "h"w );
    test( to!(dchar[])(cast(dchar)'i') == "i"d );

    /*
     * Array-array
     */
    test( to!(ubyte[])([1,2,3][]) == [cast(ubyte)1, 2, 3] );
    test( to!(bool[])(["true", "false"][]) == [true, false] );

    /*
     * Map-map
     */
    {
        istring[int] src = [1:"true"[], 2:"false"];
        bool[ubyte] dst = to!(bool[ubyte])(src);
        test( dst.keys.length == 2 );
        test( dst[1] == true );
        test( dst[2] == false );
    }

    /*
     * UDT
     */
    {
        Foo foo;

        test( to!(bool)(foo) == true );
        test( to!(int)(foo) == 42 );
        test( to!(char[])(foo) == "string foo" );
        test( to!(wchar[])(foo) == "string foo"w );
        test( to!(dchar[])(foo) == "string foo"d );
        test( to!(int[])(foo) == [1,2,3] );
        test( to!(ireal)(to!(Bar)(foo)) == 42.0i );
        test( to!(real)(to!(Bar)(to!(Baz)(foo))) == 3.14159 );
    }

    /*
     * Default values
     */
    {
        test( to!(int)("123"[], 456) == 123,
                `to!(int)("123", 456) == "` ~ to!(char[])(
                    to!(int)("123"[], 456)) ~ `"` );
        test( to!(int)("abc"[], 456) == 456,
                `to!(int)("abc", 456) == "` ~ to!(char[])(
                    to!(int)("abc"[], 456)) ~ `"` );
    }

    /*
     * Ticket #1486
     */
    {
        test(ex( to!(int)(""[]) ));

        test(ex( to!(real)("Foo"[]) ));
        test(ex( to!(real)(""[]) ));
        test(ex( to!(real)("0x1.2cp+9"[]) ));

        // From d0c's patch
        test(ex( to!(int)("0x20"[]) ));
        test(ex( to!(int)("0x"[]) ));
        test(ex( to!(int)("-"[]) ));
        test(ex( to!(int)("-0x"[]) ));

        test( to!(real)("0x20"[]) == cast(real) 0x20 );
        test(ex( to!(real)("0x"[]) ));
        test(ex( to!(real)("-"[]) ));
    }
}

unittest
{
    mixin(Typedef!(int, "MyInt"));
    MyInt value = 42;
    auto s = toImpl!(char[])(value);
    test (s == "42");
}
