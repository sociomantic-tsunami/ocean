/*******************************************************************************

    Collection of utilities to search within arrays and buffers.

    All functions in this module must never mutate their arguments and must
    never allocate new memory each call. Some may keep internal static GC
    buffers if required by algorithm.

    Based on `tango.core.Array` module from Tango library.

    Copyright:
        Copyright (C) 2005-2006 Sean Kelly.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.
    
    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.
 

*******************************************************************************/

module ocean.core.array.Search;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.stdc.posix.sys.types; // ssize_t;

import ocean.core.Traits;
import ocean.core.Buffer;
import ocean.core.array.DefaultPredicates;

version (UnitTest)
{
    import ocean.core.Test;
}

/*******************************************************************************

    Linear search in an array

    Performs a linear scan of haystack from [0 .. haystack.length$(RP), returning
    the index of the first element matching needle, or haystack.length if no match
    was found.  Comparisons will be performed using the supplied predicate
    or '==' if none is supplied.
  
    Params:
        haystack = The array to search.
        needle   = The needletern to search for, either sub-array or element
        pred     = The evaluation predicate, which should return true if e1 is
            equal to e2 and false if not.  This predicate may be any callable
            type.
      
    Returns:
        The index of the first match or haystack.length if no match was found.

*******************************************************************************/

size_t find ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( in T[] haystack, in T needle, Pred pred = Pred.init )
{
    static assert (isCallableType!(Pred));

    foreach ( pos, cur; haystack )
    {
        if( pred( cur, needle ) )
            return pos;
    }

    return haystack.length;
}

///
unittest
{
    test!("==")(find( "abc", 'b' ), 1);
}

unittest
{
    test!("==")(find( "", 'a' ), 0);
    test!("==")(find( "abc", 'a' ),  0);
    test!("==")(find( "abc", 'b' ), 1);
    test!("==")(find( "abc", 'c' ), 2);
    test!("==")(find( "abc", 'd' ), 3);
}

/// ditto
size_t find ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( in T[] haystack, in T[] needle, Pred pred = Pred.init )
{
    static assert (isCallableType!(Pred));

    if( haystack.length == 0 ||
            needle.length == 0 ||
            haystack.length < needle.length )
    {
        return haystack.length;
    }

    size_t end = haystack.length - needle.length + 1;

    for( size_t pos = 0; pos < end; ++pos )
    {
        if( pred( haystack[pos], needle[0] ) )
        {
            size_t mat = 0;

            do
            {
                if( ++mat >= needle.length )
                    return pos - needle.length + 1;
                ++pos;
                assert (pos < haystack.length);
            } while( pred( haystack[pos], needle[mat] ) );
            pos -= mat;
        }
    }
    return haystack.length;
}

///
unittest
{
    test!("==")(find( "abc", "bc" ), 1);
    test!("==")(find( "abcd", "cc" ), 4);
}

/// ditto
size_t find ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( ref Buffer!(T) haystack, in T[] needle, Pred pred = Pred.init )
{
    return find(haystack[], needle, pred);
}

///
unittest
{
    auto buffer = createBuffer([ 1, 2, 3 ]);
    test!("==")(find(buffer, [ 2, 3 ]), 1);
}

/// ditto
size_t find ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( ref Buffer!(T) haystack, in T needle, Pred pred = Pred.init )
{
    return find(haystack[], needle, pred);
}

///
unittest
{
    auto buffer = createBuffer([ 1, 2, 3 ]);
    test!("==")(find(buffer, 3), 2);
}

unittest
{
    // null parameters
    test!("==")(find( "", ""[] ), 0);
    test!("==")(find( "a", ""[] ), 1);
    test!("==")(find( "", "a"[] ), 0);

    // exact match
    test!("==")(find( "abc", "abc"[] ), 0);

    // simple substring match
    test!("==")(find( "abc", "a"[] ), 0);
    test!("==")(find( "abca", "a"[] ), 0);
    test!("==")(find( "abc", "b"[] ), 1);
    test!("==")(find( "abc", "c"[] ), 2);
    test!("==")(find( "abc", "d"[] ), 3);

    // multi-char substring match
    test!("==")(find( "abc", "ab"[] ), 0);
    test!("==")(find( "abcab", "ab"[] ), 0);
    test!("==")(find( "abc", "bc"[] ), 1);
    test!("==")(find( "abc", "ac"[] ), 3);
    test!("==")(find( "abrabracadabra", "abracadabra"[] ), 3);

    // different qualifiers
    mstring s = "abcd".dup;
    test!("==")(find(s, "bc"[]), 1);

    // custom predicate
    bool foo(char a, char b)
    {
        return a == 'x';
    }

    test!("==")(find( "abcdxa", 'b', &foo ), 4);
    test!("==")(find( "abcdxa", "b"[], &foo ), 4);
}

/*******************************************************************************

    Performs a linear scan of haystack from $(LP)haystack.length .. 0], returning
    the index of the first element matching needle, or haystack.length if no match
    was found.  Comparisons will be performed using the supplied predicate
    or '==' if none is supplied.

    Params:
        haystac  = The array to search.
        needle   = The needletern to search for.
        pred     = The evaluation predicate, which should return true if e1 is
            equal to e2 and false if not.  This predicate may be any
            callable type.

    Returns:
        The index of the first match or haystack.length if no match was found.

*******************************************************************************/

size_t rfind (T, Pred = DefaultPredicates.IsEqual!(T))
    ( in T[] haystack, in T needle, Pred pred = Pred.init )
{
    static assert ( isCallableType!(Pred) );

    if( haystack.length == 0 )
        return haystack.length;

    size_t pos = haystack.length;

    do
    {
        if( pred( haystack[--pos], needle ) )
            return pos;
    } while( pos > 0 );
    return haystack.length;
}

///
unittest
{
    test!("==")(rfind([ 1, 2, 3 ], 1), 0);
}

unittest
{
    // rfind element
    test!("==")( rfind( "", 'a' ), 0 );
    test!("==")( rfind( "abc", 'a' ), 0 );
    test!("==")( rfind( "abc", 'b' ), 1 );
    test!("==")( rfind( "abc", 'c' ), 2 );
    test!("==")( rfind( "abc", 'd' ), 3 );
}

/// ditto
size_t rfind ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( in T[] haystack, in T[] needle, Pred pred = Pred.init )
{
    static assert (isCallableType!(Pred) );

    if( haystack.length == 0 ||
        needle.length == 0 ||
        haystack.length < needle.length )
    {
        return haystack.length;
    }

    size_t pos = haystack.length - needle.length + 1;

    do
    {
        if( pred( haystack[--pos], needle[0] ) )
        {
            size_t mat = 0;

            do
            {
                if( ++mat >= needle.length )
                    return pos - needle.length + 1;
                ++pos;
                assert (pos < haystack.length);
            } while( pred( haystack[pos], needle[mat] ) );
            pos -= mat;
        }
    } while( pos > 0 );
    return haystack.length;
}

///
unittest
{
    test!("==")(rfind([ 1, 2, 3 ], [ 1, 2 ]), 0);
}

/// ditto
size_t rfind ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( ref Buffer!(T) haystack, in T[] needle, Pred pred = Pred.init )
{
    return rfind(haystack[], needle, pred);
}

///
unittest
{
    auto buffer = createBuffer([ 1, 2, 3 ]);
    test!("==")(rfind(buffer, 1), 0);
}

/// ditto
size_t rfind ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( ref Buffer!(T) haystack, in T needle, Pred pred = Pred.init )
{
    return rfind(haystack[], needle, pred);
}

///
unittest
{
    auto buffer = createBuffer([ 1, 2, 3 ]);
    test!("==")(rfind(buffer, [ 2, 3 ]), 1);
}

unittest
{
    // null parameters
    test!("==")(rfind( "", ""[] ), 0 );
    test!("==")(rfind( "a", ""[] ), 1 );
    test!("==")(rfind( "", "a"[] ), 0 );

    // exact match
    test!("==")(rfind( "abc", "abc"[] ), 0 );

    // simple substring match
    test!("==")(rfind( "abc", "a"[] ), 0 );
    test!("==")(rfind( "abca", "a"[] ), 3 );
    test!("==")(rfind( "abc", "b"[] ), 1 );
    test!("==")(rfind( "abc", "c"[] ), 2 );
    test!("==")(rfind( "abc", "d"[] ), 3 );

    // multi-char substring match
    test!("==")(rfind( "abc", "ab"[] ), 0 );
    test!("==")(rfind( "abcab", "ab"[] ), 3 );
    test!("==")(rfind( "abc", "bc"[] ), 1 );
    test!("==")(rfind( "abc", "ac"[] ), 3 );
    test!("==")(rfind( "abracadabrabra", "abracadabra"[] ), 0 );

    // custom predicate
    bool foo(char a, char b)
    {
        return a == 'x';
    }

    test!("==")(rfind( "axcdxa", 'b', &foo ), 4 );
    test!("==")(rfind( "axcdxa", "b"[], &foo ), 4 );

}

/*******************************************************************************

    Performs a linear scan of haystack from [0 .. haystack.length$(RP), returning
    the index of the first element matching needle, or haystack.length if no match
    was found.  Comparisons will be performed using the supplied predicate
    or '==' if none is supplied.

    This function uses the KMP algorithm and offers O(M+N) performance but
    must allocate a temporary buffer of size needle.sizeof to do so.  If it is
    available on the target system, alloca will be used for the allocation,
    otherwise a standard dynamic memory allocation will occur.

    Params:
        haystack = The array to search.
        needle   = The pattern to search for.
        pred     = The evaluation predicate, which should return true if e1 is
            equal to e2 and false if not.  This predicate may be any
            callable type.

    Returns:
        The index of the first match or haystack.length if no match was found.

*******************************************************************************/

size_t kfind (T, Pred = DefaultPredicates.IsEqual!(T))
    ( in T[] haystack, in T needle, Pred pred = Pred.init )
{
    return find(haystack, needle, pred);
}

///
unittest
{
    test!("==")(kfind( "abc", 'b' ), 1);
}

/// ditto
size_t kfind (T, Pred = DefaultPredicates.IsEqual!(T))
    ( in T[] haystack, in T[] needle, Pred pred = Pred.init )
{
    static assert (isCallableType!(Pred));

    if( haystack.length == 0 ||
        needle.length   == 0 ||
        haystack.length < needle.length )
    {
        return haystack.length;
    }

    static Buffer!(size_t) func;
    func.length = needle.length + 1;

    func[0] = 0;

    // building prefix-function
    for( size_t m = 0, i = 1 ; i < needle.length ; ++i )
    {
        while( ( m > 0 ) && !pred( needle[m], needle[i] ) )
            m = *func[m - 1];
        if( pred( needle[m], needle[i] ) )
            ++m;
        func[i] = m;
    }

    // searching
    for( size_t m = 0, i = 0; i < haystack.length; ++i )
    {
        while( ( m > 0 ) && !pred( needle[m], haystack[i] ) )
            m = *func[m - 1];
        if( pred( needle[m], haystack[i] ) )
        {
            ++m;
            if( m == needle.length )
            {
                return i - needle.length + 1;
            }
        }
    }

    return haystack.length;
}

///
unittest
{
    test!("==")( kfind( "abc", "a" ), 0 );
}

/// ditto
size_t kfind ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( ref Buffer!(T) haystack, in T[] needle, Pred pred = Pred.init )
{
    return kfind(haystack[], needle[0..needle.length], pred);
}

///
unittest
{
    auto buffer = createBuffer([ 1, 2, 3 ]);
    test!("==")(kfind(buffer, 1), 0);
}

/// ditto
size_t kfind ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( ref Buffer!(T) haystack, in T needle, Pred pred = Pred.init )
{
    return kfind(haystack[], needle, pred);
}

///
unittest
{
    auto buffer = createBuffer([ 1, 2, 3 ]);
    test!("==")(kfind(buffer, [ 2, 3 ]), 1);
}

unittest
{
    // find element
    test!("==")( kfind( ""[], 'a' ), 0 );
    test!("==")( kfind( "abc"[], 'a' ), 0 );
    test!("==")( kfind( "abc"[], 'b' ), 1 );
    test!("==")( kfind( "abc"[], 'c' ), 2 );
    test!("==")( kfind( "abc"[], 'd' ), 3 );

    // null parameters
    test!("==")( kfind( ""[], ""[] ), 0 );
    test!("==")( kfind( "a"[], ""[] ), 1 );
    test!("==")( kfind( ""[], "a"[] ), 0 );

    // exact match
    test!("==")( kfind( "abc"[], "abc"[] ), 0 );

    // simple substring match
    test!("==")( kfind( "abc"[], "a"[] ), 0 );
    test!("==")( kfind( "abca"[], "a"[] ), 0 );
    test!("==")( kfind( "abc"[], "b"[] ), 1 );
    test!("==")( kfind( "abc"[], "c"[] ), 2 );
    test!("==")( kfind( "abc"[], "d"[] ), 3 );

    // multi-char substring match
    test!("==")( kfind( "abc"[], "ab"[] ), 0 );
    test!("==")( kfind( "abcab"[], "ab"[] ), 0 );
    test!("==")( kfind( "abc"[], "bc"[] ), 1 );
    test!("==")( kfind( "abc"[], "ac"[] ), 3 );
    test!("==")( kfind( "abrabracadabra"[], "abracadabra"[] ), 3 );
}

/*******************************************************************************

    Performs a linear scan of haystack from [0 .. haystack.length$(RP), returning
    the index of the first element where pred returns true.

    Params:
        haystack  = The array to search.
        pred      = The evaluation predicate, which should return true if the
            element is a valid match and false if not.  This predicate
            may be any callable type.

    Returns:
        The index of the first match or haystack.length if no match was found.

*******************************************************************************/

size_t findIf ( T, Pred ) ( in T[] haystack, Pred pred )
{
    static assert( isCallableType!(Pred) );

    foreach( size_t pos, T cur; haystack )
    {
        if( pred( cur ) )
            return pos;
    }
    return haystack.length;
}

///
unittest
{
    test!("==")(findIf("bcecg", ( char c ) { return c == 'a'; }), 5);
}

/// ditto
size_t findIf ( T, Pred ) ( ref Buffer!(T) haystack, Pred pred )
{
    return findIf(haystack[], pred);
}

///
unittest
{
    auto buffer = createBuffer("bcecg");
    test!("==")(findIf(buffer, ( char c ) { return c == 'a'; }), 5);
}

unittest
{
    test!("==")( findIf( "bcecg"[], ( char c ) { return c == 'a'; } ), 5 );
    test!("==")( findIf( "bcecg"[], ( char c ) { return c == 'b'; } ), 0 );
    test!("==")( findIf( "bcecg"[], ( char c ) { return c == 'c'; } ), 1 );
    test!("==")( findIf( "bcecg"[], ( char c ) { return c == 'd'; } ), 5 );
    test!("==")( findIf( "bcecg"[], ( char c ) { return c == 'g'; } ), 4 );
    test!("==")( findIf( "bcecg"[], ( char c ) { return c == 'h'; } ), 5 );
}

/*******************************************************************************

    Performs a linear scan of haystack from $(LP)haystack.length .. 0], returning
    the index of the first element where pred returns true.

    Params:
        haystack = The array to search.
        pred     = The evaluation predicate, which should return true if the
            element is a valid match and false if not.  This predicate
            may be any callable type.

    Returns:
        The index of the first match or haystack.length if no match was found.

*******************************************************************************/

size_t rfindIf ( T, Pred ) ( in T[] haystack, Pred pred )
{
    static assert( isCallableType!(Pred) );

    if( haystack.length == 0 )
        return haystack.length;

    size_t pos = haystack.length;

    do
    {
        if( pred( haystack[--pos] ) )
            return pos;
    } while( pos > 0 );
    return haystack.length;
}

///
unittest
{
    test!("==")(rfindIf("bcecg", ( char c ) { return c == 'a'; }), 5);
}

/// ditto
size_t rfindIf ( T, Pred ) ( ref Buffer!(T) haystack, Pred pred )
{
    return rfindIf(haystack[], pred);
}

///
unittest
{
    auto buffer = createBuffer("bcecg");
    test!("==")(rfindIf(buffer, ( char c ) { return c == 'a'; }), 5);
}

unittest
{
    test!("==")(rfindIf("", ( char c ) { return c == 'a'; }), 0);
    test!("==")(rfindIf("bcecg", ( char c ) { return c == 'a'; } ), 5);
    test!("==")(rfindIf("bcecg", ( char c ) { return c == 'b'; } ), 0);
    test!("==")(rfindIf("bcecg", ( char c ) { return c == 'c'; } ), 3);
    test!("==")(rfindIf("bcecg", ( char c ) { return c == 'd'; } ), 5);
    test!("==")(rfindIf("bcecg", ( char c ) { return c == 'g'; } ), 4);
    test!("==")(rfindIf("bcecg", ( char c ) { return c == 'h'; } ), 5);
}

/*******************************************************************************

    Performs a linear scan of haystack from [0 .. haystack.length$(RP), returning
    the index of the first element that compares equal to the next element
    in the sequence.  Comparisons will be performed using the supplied
    predicate or '==' if none is supplied.

    Params:
        haystack = The array to scan.
        pred     = The evaluation predicate, which should return true if e1 is
            equal to e2 and false if not.  This predicate may be any
            callable type.

    Returns:
        The index of the first match or haystack.length if no match was found.

*******************************************************************************/

size_t findAdj( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( in T[] haystack, Pred pred = Pred.init )
{
    static assert( isCallableType!(Pred) );

    if( haystack.length < 2 )
        return haystack.length;

    Unqual!(T) sav = haystack[0];

    foreach( size_t pos, T cur; haystack[1 .. $] )
    {
        if( pred( cur, sav ) )
            return pos;
        sav = cur;
    }
    return haystack.length;
}

///
unittest
{
    test!("==")(findAdj("abcddef"), 3);
}

/// ditto
size_t findAdj( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( ref Buffer!(T) haystack, Pred pred = Pred.init )
{
    return findAdj(haystack[], pred);
}

///
unittest
{
    auto buffer = createBuffer("abcddef");
    test!("==")(findAdj(buffer), 3);
}

unittest
{
    test!("==")(findAdj(""), 0);
    test!("==")(findAdj("aabcdef"), 0);
    test!("==")(findAdj("abcdeff"), 5);
    test!("==")(findAdj("abcdefg"), 7);
}

/*******************************************************************************

    Performs a linear scan of haystack from [0 .. haystack.length$(RP), returning
    true if an element matching needle is found.  Comparisons will be performed
    using the supplied predicate or '<' if none is supplied.

    Params:
        haystack = The array to search.
        needle   = The pattern to search for.
        pred     = The evaluation predicate, which should return true if e1 is
           equal to e2 and false if not.  This predicate may be any
           callable type.

    Returns:
        True if an element equivalent to needle is found, false if not.

*******************************************************************************/

equals_t contains ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( in T[] haystack, in T needle, Pred pred = Pred.init )
{
    return find(haystack, needle, pred) != haystack.length;
}

///
unittest
{
    test( contains("abc", 'a'));
    test(!contains("abc", 'd'));
}

/// ditto
equals_t contains ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( in T[] haystack, in T[] needle, Pred pred = Pred.init )
{
    return find(haystack, needle, pred) != haystack.length;
}

///
unittest
{
    test( contains("abc", "a"));
    test(!contains("abc", "d"));
}

/// ditto
equals_t contains ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( ref Buffer!(T) haystack, in T needle, Pred pred = Pred.init )
{
    return find(haystack, needle, pred) != haystack.length;
}

///
unittest
{
    auto buffer = createBuffer("abc");
    test( contains(buffer, 'a'));
    test(!contains(buffer, 'd'));
}

/// ditto
equals_t contains ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( ref Buffer!(T) haystack, in T[] needle, Pred pred = Pred.init )
{
    return find(haystack, needle, pred) != haystack.length;
}

///
unittest
{
    auto buffer = createBuffer("abc");
    test( contains(buffer, "a"));
    test(!contains(buffer, "d"));
}

unittest
{
    mixin (Typedef!(hash_t, "Hash"));
    auto id = cast(Hash) 42;
    Hash[] arr = [ cast(Hash) 1, cast(Hash) 2, cast(Hash) 3 ];
    auto result = contains(arr, id);
}

unittest
{
    // find element
    test(!contains( ""[], 'a' ));
    test( contains( "abc"[], 'a' ));
    test( contains( "abc"[], 'b' ));
    test( contains( "abc"[], 'c' ));
    test(!contains( "abc"[], 'd' ));

    // null parameters
    test(!contains( ""[], ""[] ));
    test(!contains( "a"[], ""[] ));
    test(!contains( ""[], "a"[] ));

    // exact match
    test( contains( "abc"[], "abc"[] ));

    // simple substring match
    test( contains( "abc"[], "a"[] ));
    test( contains( "abca"[], "a"[] ));
    test( contains( "abc"[], "b"[] ));
    test( contains( "abc"[], "c"[] ));
    test(!contains( "abc"[], "d"[] ));

    // multi-char substring match
    test( contains( "abc"[], "ab"[] ));
    test( contains( "abcab"[], "ab"[] ));
    test( contains( "abc"[], "bc"[] ));
    test(!contains( "abc"[], "ac"[] ));
    test( contains( "abrabracadabra"[], "abracadabra"[] ));
}

/*******************************************************************************

    Performs a parallel linear scan of arr and arr_against from [0 .. N$(RP)
    where N = min(arr.length, arr_against.length), returning the index of
    the first element in arr which does not match the corresponding element
    in arr_against or N if no mismatch occurs.  Comparisons will be performed
    using the supplied predicate or '==' if none is supplied.

    Params:
        arr         = The array to evaluate.
        arr_against = The array to match against.
        pred        = The evaluation predicate, which should return true if e1
            is equal to e2 and false if not.  This predicate may be any
            callable type.

    Returns:
        The index of the first mismatch or N if the first N elements of arr
        and arr_against match, where
        N = min$(LP)arr.length, arr_against.length$(RP).

*******************************************************************************/

size_t mismatch ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( in T[] arr, in T[] arr_against, Pred pred = Pred.init )
{
    static assert( isCallableType!(Pred) );

    size_t  posA = 0,
            posB = 0;

    while( posA < arr.length && posB < arr_against.length )
    {
        if( !pred( arr_against[posB], arr[posA] ) )
            break;
        ++posA, ++posB;
    }
    return posA;
}

///
unittest
{
    // result must not change from swapping argument order:
    test!("==")(mismatch("abcxefg", "abcdefg"), 3);
    test!("==")(mismatch("abcdefg", "abcxefg"), 3);
}

/// ditto
size_t mismatch ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( ref Buffer!(T) arr, ref Buffer!(T) arr_against, Pred pred = Pred.init )
{
    return mismatch(arr[0..arr.length],
        arr_against[0..arr_against.length], pred);
}

///
unittest
{
    // result must not change from swapping argument order:
    auto buffer1 = createBuffer("abcxefg");
    auto buffer2 = createBuffer("abcdefg");
    test!("==")( mismatch(buffer1, buffer2), 3 );
    test!("==")( mismatch(buffer2, buffer1), 3 );
}

unittest
{
    test!("==")( mismatch( "a"[], "abcdefg"[] ), 1 );
    test!("==")( mismatch( "abcdefg"[], "a"[] ), 1 );

    test!("==")( mismatch( "x"[], "abcdefg"[] ), 0 );
    test!("==")( mismatch( "abcdefg"[], "x"[] ), 0 );

    test!("==")( mismatch( "xbcdefg"[], "abcdefg"[] ), 0 );
    test!("==")( mismatch( "abcdefg"[], "xbcdefg"[] ), 0 );

    test!("==")( mismatch( "abcxefg"[], "abcdefg"[] ), 3 );
    test!("==")( mismatch( "abcdefg"[], "abcxefg"[] ), 3 );

    test!("==")( mismatch( "abcdefx"[], "abcdefg"[] ), 6 );
    test!("==")( mismatch( "abcdefg"[], "abcdefx"[] ), 6 );
}

/******************************************************************************

    Performs a linear scan of haystack from [0 .. haystack.length$(RP), returning
    a count of the number of elements matching needle.  Comparisons will be
    performed using the supplied predicate or '==' if none is supplied.

    Params:
        haystack = The array to scan.
        needle   = The pattern to match.
        pred = The evaluation predicate, which should return true if e1 is
            equal to e2 and false if not.  This predicate may be any
            callable type.

    Returns:
        The number of elements matching needle.

******************************************************************************/

size_t count ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( in T[] haystack, in T needle, Pred pred = Pred.init )
{
    static assert( isCallableType!(Pred) );

    size_t cnt = 0;

    foreach( size_t pos, T cur; haystack )
    {
        if( pred( cur, needle ) )
            ++cnt;
    }
    return cnt;
}

///
unittest
{
    test!("==")(count("gbbbi", 'b'), 3);
}

/// ditto
size_t count ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( ref Buffer!(T) haystack, in T needle, Pred pred = Pred.init )
{
    return count(haystack[], needle, pred);
}

///
unittest
{
    auto buffer = createBuffer("gbbbi");
    test!("==")(count(buffer, 'b'), 3);
}

unittest
{
    test!("==")( count( "gbbbi"[], 'a' ), 0 );
    test!("==")( count( "gbbbi"[], 'g' ), 1 );
    test!("==")( count( "gbbbi"[], 'b' ), 3 );
    test!("==")( count( "gbbbi"[], 'i' ), 1 );
    test!("==")( count( "gbbbi"[], 'd' ), 0 );
}

/*******************************************************************************

   Performs a linear scan of haystack from [0 .. haystack.length$(RP), returning
   a count of the number of elements where pred returns true.
  
   Params:
       haystack = The array to scan.
       pred = The evaluation predicate, which should return true if the
              element is a valid match and false if not.  This predicate
              may be any callable type.
  
   Returns:
       The number of elements where pred returns true.

*******************************************************************************/

size_t countIf ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( in T[] haystack, Pred pred = Pred.init )
{
    static assert( isCallableType!(Pred) );

    size_t cnt = 0;

    foreach( size_t pos, T cur; haystack )
    {
        if( pred( cur ) )
            ++cnt;
    }
    return cnt;
}

///
unittest
{
    test!("==")(countIf("gbbbi", ( char c ) { return c == 'b'; }), 3);
}

size_t countIf ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( ref Buffer!(T) haystack, Pred pred = Pred.init )
{
    return countIf(haystack[], pred);
}

///
unittest
{
    auto buffer = createBuffer("gbbbi");
    test!("==")(countIf(buffer, ( char c ) { return c == 'b'; }), 3);
}

unittest
{
    test!("==")( countIf( "gbbbi"[], ( char c ) { return c == 'a'; } ), 0 );
    test!("==")( countIf( "gbbbi"[], ( char c ) { return c == 'g'; } ), 1 );
    test!("==")( countIf( "gbbbi"[], ( char c ) { return c == 'b'; } ), 3 );
    test!("==")( countIf( "gbbbi"[], ( char c ) { return c == 'i'; } ), 1 );
    test!("==")( countIf( "gbbbi"[], ( char c ) { return c == 'd'; } ), 0 );
}

/*******************************************************************************

    Searches a sorted array for the specified element or for the insert
    position of the element. The array is assumed to be pre-sorted in ascending
    order, the search will not work properly if it is not.
    If T is a class or struct, comparison is performed using T.opCmp().
    Otherwise, elements of T are compared using ">" and ">=" or, if T is
    compatible to size_t (which includes ssize_t, the signed version of size_t),
    by calculating the difference.

    Template params:
        T = type of array element

    Params:
        array = array to search
        match = element to search for
        position = out value, value depends on whether the element was found:

            1. If found, the position at which element was found is output.

            2. If not found, the position at which the element could be inserted
               is output, as follows:

               * A value of 0 means that the element is smaller than all
                 elements in the array, and would need to be inserted at the
                 beginning of the array, and all other elements shifted to the
                 right.
               * A value of array.length means that the element is larger than
                 all elements in the array, and would need to be appended to the
                 end of the array.
               * A value of > 0 and < array.length means that the element would
                 need to be inserted at the specified position, and all elements
                 of index >= the specified position shifted to the right.

    Returns:
        true if the element was found in the array

    In:
        array.length must be at most ssize_t.max (int.max if size_t is uint or
        long.max if size_t is ulong). TODO: Remove this restriction by
        rephrasing the implementation in bsearchCustom().

*******************************************************************************/

public bool bsearch ( T ) ( T[] array, T match, out size_t position )
out (found)
{
    if (found)
    {
        assert (position < array.length);
    }
    else
    {
        assert (position <= array.length);
    }
}
body
{
    return bsearchCustom(
        array.length,
        delegate ssize_t ( size_t i )
        {
            static if (is (T : size_t)) // will also be true if T is ssize_t
            {
                // If T is unsigned, check if cast (ssize_t) (0 - 1) == -1.
                // TODO: Is this behaviour guaranteed? If so, remove the
                // check.

                static if (T.min == 0)
                {
                    static assert (cast (ssize_t) (T.min - cast (T) 1) == -1,
                                   "bsearch: 0 - 1 != -1 for type " ~ T.stringof);
                }

                return match - array[i];
            }
            else static if (is (T == class) || is (T == struct))
            {
                return match.opCmp(array[i]);
            }
            else
            {
                return (match >= array[i])? (match > array[i]) : -1;
            }
        },
        position
    );
}

unittest
{
    auto arr = [ 1, 2, 4, 6, 20, 100, 240 ];
    size_t pos;
    bool found = bsearch(arr, 6, pos);
}

/*******************************************************************************

    Searches a sorted array for an element or an insert position for an element.
    The array is assumed to be pre-sorted according to cmp.

    Params:
        array_length = length of array to search
        cmp       = comparison callback delegate, should return
                    * a positive value if the array element at index i compares
                      greater than the element to search for,
                    * a negative value if the array element at index i compares
                      less than the element to search for,
                    * 0 if if the array element at index i compares equal to
                      the element to search for.
        position  = out value, value depends on whether the element was found:

            1. If found, the position at which element was found is output.

            2. If not found, the position at which the element could be inserted
               is output, as follows:

               * A value of 0 means that the element is smaller than all
                 elements in the array, and would need to be inserted at the
                 beginning of the array, and all other elements shifted to the
                 right.
               * A value of array.length means that the element is larger than
                 all elements in the array, and would need to be appended to the
                 end of the array.
               * A value of > 0 and < array.length means that the element would
                 need to be inserted at the specified position, and all elements
                 of index >= the specified position shifted to the right.

    Returns:
        true if the element was found in the array

    In:
        array_length must be at most ssize_t.max (int.max if size_t is uint or
        long.max if size_t is ulong). TODO: Remove this restriction by
        rephrasing the implementation so that min/max cannot be less than 0.

*******************************************************************************/

public bool bsearchCustom ( size_t array_length, ssize_t delegate ( size_t i ) cmp, out size_t position )
in
{
    assert (cast (ssize_t) array_length >= 0,
            "bsearchCustom: array_length integer overflow (maximum is " ~
            ssize_t.stringof ~ ".max = " ~ ssize_t.max.stringof ~ ')');
}
out (found)
{
    if (found)
    {
        assert (position < array_length);
    }
    else
    {
        assert (position <= array_length);
    }
}
body
{
    if ( array_length == 0 )
    {
        return false;
    }

    ssize_t min = 0;
    ssize_t max = array_length - 1;

    ssize_t c = cmp(position = (min + max) / 2);

    while ( min <= max && c )
    {
        if ( c < 0 ) // match < array[position]
        {
            max = position - 1;
        }
        else        // match > array[position]
        {
            min = position + 1;
        }

        c = cmp(position = (min + max) / 2);
    }

    position += c > 0;

    return !c;
}

/*******************************************************************************

    Performs a parallel linear scan of setA and setB from [0 .. N$(RP)
    where N = min(setA.length, setB.length), returning true if setA
    includes all elements in setB and false if not.  Both setA and setB are
    required to be sorted, and duplicates in setB require an equal number of
    duplicates in setA.  Comparisons will be performed using the supplied
    predicate or '<' if none is supplied.

    Params:
        setA = The sorted array to evaluate.
        setB = The sorted array to match against.
        pred = The evaluation predicate, which should return true if e1 is
           less than e2 and false if not.  This predicate may be any
       callable type.

    Returns:
        True if setA includes all elements in setB, false if not.

*******************************************************************************/

bool includes ( T,  Pred = DefaultPredicates.IsLess!(T) )
    ( in T[] setA, in T[] setB, Pred pred = Pred.init )
{
    static assert( isCallableType!(Pred ) );

    size_t  posA = 0,
            posB = 0;

    while( posA < setA.length && posB < setB.length )
    {
        if( pred( setB[posB], setA[posA] ) )
            return false;
        else if( pred( setA[posA], setB[posB] ) )
            ++posA;
        else
            ++posA, ++posB;
    }
    return posB == setB.length;
}

///
unittest
{
    test(includes("abcdefg", "cde"));
}

unittest
{
    test( includes( "abcdefg"[], "a"[] ) );
    test( includes( "abcdefg"[], "g"[] ) );
    test( includes( "abcdefg"[], "d"[] ) );
    test( includes( "abcdefg"[], "abcdefg"[] ) );
    test( includes( "aaaabbbcdddefgg"[], "abbbcdefg"[] ) );

    test( !includes( "abcdefg"[], "aaabcdefg"[] ) );
    test( !includes( "abcdefg"[], "abcdefggg"[] ) );
    test( !includes( "abbbcdefg"[], "abbbbcdefg"[] ) );
}

/*******************************************************************************

    Check if the given array starts with the given prefix

    Template Params:
        T = The type of the array element

    Params:
        arr    = The array to be tested
        prefix = The prefix to test for

    Returns:
        True if the array starts with the prefix, false otherwise

*******************************************************************************/

bool startsWith ( T ) ( in T[] arr, in T[] prefix )
{
    return (arr.length >= prefix.length) && (arr[0..prefix.length] == prefix[]);
}

unittest
{
    test( startsWith("abcd", "abc"));
    test( startsWith("abcd", "abcd"));
    test(!startsWith("ab", "abc"));
    test( startsWith("ab", ""));
    test(!startsWith("", "xx"));

    test( startsWith([1,2,3,4], [1,2,3]));
    test( startsWith([1,2,3,4], [1,2,3,4]));
    test(!startsWith([1,2], [1,2,3]));
    test( startsWith([1,2], (int[]).init));
    test(!startsWith((int[]).init, [1,2]));
}

/*******************************************************************************

    Check if the given array ends with the given suffix

    Template Params:
        T = The type of the array element

    Params:
        arr    = The array to be tested
        suffix = The suffix to test for

    Returns:
        True if the array ends with the suffix, false otherwise

*******************************************************************************/

bool endsWith ( T ) ( in T[] arr, in T[] suffix )
{
    return (arr.length >= suffix.length) && (arr[$ - suffix.length .. $] == suffix[]);
}

unittest
{
    test( endsWith("abcd", "bcd"));
    test( endsWith("abcd", "abcd"));
    test(!endsWith("ab", "abc"));
    test( endsWith("ab", ""));
    test(!endsWith("", "xx"));

    test( endsWith([1,2,3,4], [2,3,4]));
    test( endsWith([1,2,3,4], [1,2,3,4]));
    test(!endsWith([1,2], [1,2,3]));
    test( endsWith([1,2], (int[]).init));
    test(!endsWith((int[]).init, [1,2]));
}

/*******************************************************************************

    Remove the given prefix from the given array.

    Template Params:
        T = The type of the array element

    Params:
        arr    = The array from which the prefix is to be removed
        prefix = The prefix to remove

    Returns:
        A slice without the prefix if successful, the original array otherwise

*******************************************************************************/

public T1[] removePrefix ( T1, T2 ) ( T1[] arr, in T2[] prefix )
{
    return ((arr.length >= prefix.length) && (startsWith(arr, prefix))
                ? arr[prefix.length .. $]
                : arr);
}

unittest
{
    test(removePrefix("abcd", "abc") == "d");
    test(removePrefix("abcd", "abcd") == "");
    test(removePrefix("abcd", "abcde") == "abcd");
    test(removePrefix("abcd", "") == "abcd");
    test(removePrefix("", "xx") == "");
    test("abcd".removePrefix("abc") == "d");
    test("abcd".removePrefix("abcd") == "");
    test("abcd".removePrefix("abcde") == "abcd");
    test("abcd".removePrefix("") == "abcd");
    test("".removePrefix("xx") == "");

    test(removePrefix([1,2,3,4], [1,2,3]) == [ 4 ]);
    test(removePrefix([1,2,3,4], [1,2,3,4]) == cast(int[]) null);
    test(removePrefix([1,2], [1,2,3]) == [ 1, 2 ]);
    test(removePrefix([1,2], (int[]).init) == [ 1, 2 ]);
    test(removePrefix((int[]).init, [1,2]) == cast(int[]) null);
}

/*******************************************************************************

    Remove the given suffix from the given array.

    Template Params:
        T = The type of the array element

    Params:
        arr    = The array from which the suffix is to be removed
        suffix = The suffix to remove

    Returns:
        A slice without the suffix if successful, the original array otherwise

*******************************************************************************/

public T1[] removeSuffix ( T1, T2 ) ( T1[] arr, in T2[] suffix )
{
    return ((arr.length >= suffix.length) && (endsWith(arr, suffix))
                ? arr[0 .. $-suffix.length]
                : arr);
}

unittest
{
    test(removeSuffix("abcd", "cd") == "ab");
    test(removeSuffix("abcd", "abcd") == "");
    test(removeSuffix("abcd", "abcde") == "abcd");
    test(removeSuffix("abcd", "") == "abcd");
    test(removeSuffix("", "xx") == "");
    test("abcd".removeSuffix("cd") == "ab");
    test("abcd".removeSuffix("abcd") == "");
    test("abcd".removeSuffix("abcde") == "abcd");
    test("abcd".removeSuffix("") == "abcd");
    test("".removeSuffix("xx") == "");

    test(removeSuffix([1,2,3,4], [2,3,4]) == [ 1 ]);
    test(removeSuffix([1,2,3,4], [1,2,3,4]) == cast(int[]) null);
    test(removeSuffix([1,2], [1,2,3]) == [ 1, 2 ]);
    test(removeSuffix([1,2], (int[]).init) == [ 1, 2 ]);
    test(removeSuffix((int[]).init, [1,2]) == cast(int[]) null);
}

