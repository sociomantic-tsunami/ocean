/*******************************************************************************

    Collection of utilities to create new data based on arrays.

    All functions in this module must never mutate their arguments. Some of
    them allocate new GC memory to store return data, some request explicit
    buffer argument for result.

    Based on `tango.core.Array` module from Tango library.

    Copyright:
        Copyright (C) 2005-2006 Sean Kelly.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

*******************************************************************************/

module ocean.core.array.Transformation;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;
import ocean.core.Traits;

import ocean.core.array.DefaultPredicates;
import ocean.core.Buffer;

import ocean.core.array.Search;

version (UnitTest)
{
    import ocean.core.Test;
}

/*******************************************************************************

    Computes the union of setA and setB as a set operation and returns the
    retult in a new sorted array.  Both setA and setB are required to be
    sorted.  If either setA or setB contain duplicates, the result will
    contain the larger number of duplicates from setA and setB.  When an
    overlap occurs, entries will be copied from setA.  Comparisons will be
    performed using the supplied predicate or '<' if none is supplied.

    Params:
        setA = The first sorted array to evaluate.
        setB = The second sorted array to evaluate.
        pred = The evaluation predicate, which should return true if e1 is
            less than e2 and false if not.  This predicate may be any
            callable type.

    Returns:
        A new array containing the union of setA and setB.

*******************************************************************************/

T[] unionOf ( T, Pred = DefaultPredicates.IsLess!(T) )
    ( in T[] setA, in T[] setB, Pred pred = Pred.init )
{
    static assert( isCallableType!(Pred ) );

    size_t  posA = 0,
            posB = 0;
    T[] setU;

    while( posA < setA.length && posB < setB.length )
    {
        if( pred( setA[posA], setB[posB] ) )
            setU ~= setA[posA++];
        else if( pred( setB[posB], setA[posA] ) )
            setU ~= setB[posB++];
        else
            setU ~= setA[posA++], posB++;
    }
    setU ~= setA[posA .. $];
    setU ~= setB[posB .. $];
    return setU;
}

///
unittest
{
    test!("==")(unionOf( "", "" ), "");
    test!("==")(unionOf( "abc", "def" ), "abcdef");
    test!("==")(unionOf( "abbbcd", "aadeefg" ), "aabbbcdeefg");
}

/*******************************************************************************

    Computes the intersection of setA and setB as a set operation and
    returns the retult in a new sorted array.  Both setA and setB are
    required to be sorted.  If either setA or setB contain duplicates, the
    result will contain the smaller number of duplicates from setA and setB.
    All entries will be copied from setA.  Comparisons will be performed
    using the supplied predicate or '<' if none is supplied.

    Params:
        setA = The first sorted array to evaluate.
        setB = The second sorted array to evaluate.
        pred = The evaluation predicate, which should return true if e1 is
             less than e2 and false if not.  This predicate may be any
             callable type.

    Returns:
        A new array containing the intersection of setA and setB.

*******************************************************************************/

T[] intersectionOf ( T, Pred = DefaultPredicates.IsLess!(T) )
    ( in T[] setA, in T[] setB, Pred pred = Pred.init )
{
    static assert( isCallableType!(Pred ) );

    size_t  posA = 0,
            posB = 0;
    T[]  setI;

    while( posA < setA.length && posB < setB.length )
    {
        if( pred( setA[posA], setB[posB] ) )
            ++posA;
        else if( pred( setB[posB], setA[posA] ) )
            ++posB;
        else
            setI ~= setA[posA++], posB++;
    }
    return setI;
}

///
unittest
{
    test!("==")(intersectionOf( ""[], ""[] ), "");
    test!("==")(intersectionOf( "abc"[], "def"[] ), "");
    test!("==")(intersectionOf( "abbbcd"[], "aabdddeefg"[] ), "abd");
}

/*******************************************************************************

    Returns a new array containing all elements in setA which are not
    present in setB.  Both setA and setB are required to be sorted.
    Comparisons will be performed using the supplied predicate or '<'
    if none is supplied.

    Params:
    setA = The first sorted array to evaluate.
    setB = The second sorted array to evaluate.
    pred = The evaluation predicate, which should return true if e1 is
        less than e2 and false if not.  This predicate may be any
        callable type.

    Returns:
        A new array containing the elements in setA that are not in setB.

*******************************************************************************/

T[] missingFrom ( T, Pred = DefaultPredicates.IsLess!(T) )
    ( in T[] setA, in T[] setB, Pred pred = Pred.init )
{
    static assert( isCallableType!(Pred ) );

    size_t  posA = 0,
            posB = 0;
    T[]  setM;

    while( posA < setA.length && posB < setB.length )
    {
        if( pred( setA[posA], setB[posB] ) )
            setM ~= setA[posA++];
        else if( pred( setB[posB], setA[posA] ) )
            ++posB;
        else
            ++posA, ++posB;
    }
    setM ~= setA[posA .. $];
    return setM;
}

///
unittest
{
    test!("==")(missingFrom("abbbcd", "abd"), "bbc" );
}

unittest
{
    test!("==")(missingFrom( ""[], ""[] ), "" );
    test!("==")(missingFrom( ""[], "abc"[] ), "" );
    test!("==")(missingFrom( "abc"[], ""[] ), "abc" );
    test!("==")(missingFrom( "abc"[], "abc"[] ), "" );
    test!("==")(missingFrom( "abc"[], "def"[] ), "abc" );
    test!("==")(missingFrom( "abced"[], "dedf"[] ), "abc" );
    test!("==")(missingFrom( "abbbcd"[], "abd"[] ), "bbc" );
    test!("==")(missingFrom( "abcdef"[], "bc"[] ), "adef" );
}

/*******************************************************************************

    Returns a new array containing all elements in setA which are not
    present in setB and the elements in setB which are not present in
    setA.  Both setA and setB are required to be sorted.  Comparisons
    will be performed using the supplied predicate or '<' if none is
    supplied.

    Params:
        setA = The first sorted array to evaluate.
        setB = The second sorted array to evaluate.
        pred = The evaluation predicate, which should return true if e1 is
            less than e2 and false if not.  This predicate may be any
            callable type.

    Returns:
        A new array containing the elements in setA that are not in setB
        and the elements in setB that are not in setA.

*******************************************************************************/

T[] differenceOf ( T, Pred = DefaultPredicates.IsLess!(T) )
    ( in T[] setA, in T[] setB, Pred pred = Pred.init )
{
    static assert( isCallableType!(Pred ) );

    size_t  posA = 0,
            posB = 0;
    T[] setD;

    while( posA < setA.length && posB < setB.length )
    {
        if( pred( setA[posA], setB[posB] ) )
            setD ~= setA[posA++];
        else if( pred( setB[posB], setA[posA] ) )
            setD ~= setB[posB++];
        else
            ++posA, ++posB;
    }
    setD ~= setA[posA .. $];
    setD ~= setB[posB .. $];
    return setD;
}

unittest
{
    test!("==")( differenceOf( ""[], ""[] ), "" );
    test!("==")( differenceOf( ""[], "abc"[] ), "abc" );
    test!("==")( differenceOf( "abc"[], ""[] ), "abc" );
    test!("==")( differenceOf( "abc"[], "abc"[] ), "" );
    test!("==")( differenceOf( "abc"[], "def"[] ), "abcdef" );
    test!("==")( differenceOf( "abbbcd"[], "abd"[] ), "bbc" );
    test!("==")( differenceOf( "abd"[], "abbbcd"[] ), "bbc" );
}

/*******************************************************************************

    Apply a function to each element an array. The function's
    return values are stored in another array.

    Params:
        array = the array.
        func  = the function to apply.
        buf   = a buffer in which to store the results. This will be
            resized if it does not have sufficient space.

    Returns:
        an array (the same as the buffer passed in, if possible) where the
        ith element is the result of applying func to the ith element of the
        input array

*******************************************************************************/

U[] map ( T, U, MapFunc )
    ( in T[] array, MapFunc func, ref Buffer!(U) buf )
{
    static assert (is(U == ReturnTypeOf!(MapFunc)));

    if (buf.length < array.length)
        buf.length = array.length;

    foreach (i, a; array)
        buf[i] = func(a);

    return buf[];
}

///
unittest
{
    Buffer!(long) buffer;
    auto mapping = map(
        [1, 17, 8, 12][],
        (int i) { return i * 2L; },
        buffer
    );
    test!("==")(mapping[], [2L, 34L, 16L, 24L]);
}

// deprecated ("Must use Buffer as a buffer argument")
U[] map ( T, MapFunc, U = ReturnTypeOf!(MapFunc) )
    ( in T[] array, MapFunc func, U[] pseudo_buff = null )
{
    auto tmp_buffer = Buffer!(U)(pseudo_buff);
    return map(array, func, tmp_buffer);
}

deprecated unittest
{
    auto arr = map([1, 17, 8, 12][], (int i) { return i * 2L; });
    test(arr == [2L, 34L, 16L, 24L]);
}

/*******************************************************************************

    Reduce an array of elements to a single element, using a user-supplied
    reductor function.

    If the array is empty, return the default value for the element type.

    If the array contains only one element, return that element.

    Otherwise, the reductor function will be called on every member of the
    array and on every resulting element until there is only one element,
    which is then returned.

    Params:
        array = the array to reduce
        func = the reductor function

    Returns: the single element reduction

*******************************************************************************/

ReturnTypeOf!(ReduceFunc) reduce (T, ReduceFunc)
    ( in T[] array, ReduceFunc func )
{
    static assert(isCallableType!(ReduceFunc));

    if (array.length == 0)
        return ReturnTypeOf!(ReduceFunc).init;
    T e = array[0];

    foreach (i, a; array)
    {
        if (i == 0) continue;
        e = func(e, a);
    }

    return e;
}

///
unittest
{
    auto result = reduce([1, 17, 8, 12][], (int i, int j){ return i * j; });
    test!("==")(result, 1632);

    result = reduce("", (char c1, char c2) { return 'X'; });
    test!("==")(result, char.init);
}

/*******************************************************************************

    Performs a linear scan of buf from [0 .. buf.length$(RP), creating a new
    array with just the elements that satisfy pred.  The relative order of
    elements will be preserved.

    Params:
        array = The array to scan.
        pred  = The evaluation predicate, which should return true if the
          element satisfies the condition and false if not.  This
          predicate may be any callable type.
        buf   = an optional buffer into which elements are filtered. This
          is the array that gets returned to you.

    Returns:
        A new array with just the elements from buf that satisfy pred.

    Notes:
        While most Array functions that take an output buffer size that buffer
        optimally, in this case, there is no way of knowing whether the output
        will be empty or the entire input array. If you have special knowledge
        in this regard, preallocating the output buffer will be advantageous.

*******************************************************************************/

T[] filter ( T, Pred )
    ( in T[] array, Pred pred, ref Buffer!(T) buf)
{
    static assert(isCallableType!(Pred));

    // Unfortunately, we don't know our output size -- it could be empty or
    // the length of the input array. So we won't try to do anything fancy
    // with preallocation.
    buf.length = 0;

    foreach (i, e; array)
    {
        if (pred(e))
        {
            buf ~= e;
        }
    }

    return buf[];
}

///
unittest
{
    Buffer!(char) result;
    test!("==")(filter("aabbaab",
        (char c) { return c == 'a'; }, result), "aaaa");
}

// deprecated ("Must use Buffer as a buffer argument")
T[] filter ( T, Pred )
    ( in T[] array, Pred pred, T[] pseudo_buf = null )
{
    auto buffer = Buffer!(T)(pseudo_buf);
    return filter(array, pred, buffer)[];
}

deprecated unittest
{
    test!("==")(filter("aabbaab",
        (char c) { return c == 'a'; }), "aaaa");
}

unittest
{
    void test( cstring array, bool delegate( char ) dg, size_t num )
    {
        Buffer!(char) buf;
        auto r = filter( array, dg, buf );
        assert( r.length == num );
        size_t rpos = 0;
        foreach( pos, cur; buf )
        {
            if ( dg( cur ) )
            {
                assert( r[rpos] == cur );
                rpos++;
            }
        }

        assert( rpos == num );
    }

    test( "abcdefghij", ( char c ) { return c == 'x'; },  0 );
    test( "xabcdefghi", ( char c ) { return c == 'x'; },  1 );
    test( "abcdefghix", ( char c ) { return c == 'x'; },  1 );
    test( "abxxcdefgh", ( char c ) { return c == 'x'; },  2 );
    test( "xaxbcdxxex", ( char c ) { return c == 'x'; },  5 );
}

/*******************************************************************************

    Removes all instances of match from source.

    TODO: merge with `filter`

    Template params:
        T = type of array element

    Params:
        src = source array to search
        match = pattern to remove from source array
        result = buffer to write resulting array to

    Returns:
        result

*******************************************************************************/

public T[] remove ( T ) ( in T[] source, in T[] match, ref Buffer!(T) result )
{
    T[] replacement = null;
    return substitute(source, match, replacement, result);
}

///
unittest
{
    Buffer!(char) result;
    remove("aaabbbaaa"[], "bbb"[], result);
    test!("==")(result[], "aaaaaa"[]);
}

// deprecated ("Must use Buffer as a buffer argument")
public T[] remove ( T ) ( in T[] source, in T[] match, ref T[] result )
{
    return remove(source, match, *cast(Buffer!(T)*) &result);
}

deprecated unittest
{
    mstring result;
    remove("aaabbbaaa"[], "bbb"[], result);
    test!("==")(result, "aaaaaa"[]);
}
/*******************************************************************************

    Split the provided array wherever a pattern instance is found, and return
    the resultant segments. The pattern is excluded from each of the segments.

    Note that the src content is not duplicated by this function, but is sliced
    instead.

    (Adapted from ocean.text.Util : split, which isn't memory safe.)

    Template params:
        T = type of array element

    Params:
        src = source array to split
        pattern = pattern to split array by
        result = receives split array segments (slices into src)

    Returns:
        result

*******************************************************************************/

public T3[] split ( T1, T2, T3 ) ( T1[] src, T2[] pattern,
    ref Buffer!(T3) result )
{
    result.length = 0;

    while (true)
    {
        auto index = find(src, pattern);
        result ~= src[0 .. index];
        if (index < src.length)
        {
            index += pattern.length;
            src = src[index .. $];
        }
        else
            break;
    }

    return result[];
}

///
unittest
{
    Buffer!(cstring) result;
    split("aaa..bbb..ccc", "..", result);
    test!("==")(result[], [ "aaa", "bbb", "ccc" ]);
}

unittest
{
    Buffer!(cstring) result;

    split(`abc"def"`, `"`, result);
    test!("==")(result[], [ "abc", "def", "" ]);

    split(`abc"def"`.dup, `"`, result);
    test!("==")(result[], [ "abc", "def", "" ]);
}

// deprecated ("Must use Buffer as a buffer argument")
public T3[][] split ( T1, T2, T3 ) ( T1[] src, T2[] pattern, ref T3[][] result )
{
    auto buffer = cast(Buffer!(T3[])*) &result;
    return split(src, pattern, *buffer)[];
}

deprecated unittest
{
    istring[] result;
    split("aaa..bbb..ccc", "..", result);
    test!("==")(result, [ "aaa", "bbb", "ccc" ]);
}

deprecated unittest
{
    mstring[] result;
    split("aaa.bbb.".dup, ".", result);
    test!("==")(result, [ "aaa", "bbb", "" ]);
}

/*******************************************************************************

    Substitute all instances of match from source. Set replacement to null in
    order to remove instead of replace (or use the remove() function, below).

    Template params:
        T = type of array element

    Params:
        src = source array to search
        match = pattern to match in source array
        replacement = pattern to replace matched sub-arrays
        result = buffer to write resulting array to

    Returns:
        result

*******************************************************************************/

public T[] substitute ( T ) ( in T[] source, in T[] match,
    in T[] replacement, ref Buffer!(T) result )
{
    result.length = 0;
    Const!(T)[] src = source;

    do
    {
        auto index = find(src, match);
        result ~= src[0 .. index];
        if (index < src.length)
        {
            result ~= replacement;
            index += match.length;
        }
        src = src[index .. $];
    }
    while (src.length);

    return result[];
}

///
unittest
{
    Buffer!(char) result;
    substitute("some string", "ring", "oops", result);
    test!("==")(result[], "some stoops");
}

// deprecated ("Must use Buffer as a buffer argument")
public T[] substitute ( T ) ( in T[] source, in T[] match,
    in T[] replacement, ref T[] result )
{
    return substitute(source, match, replacement,
        * cast(Buffer!(char)*) &result);
}

deprecated unittest
{
    mstring result;
    substitute("some string", "ring", "oops", result);
    test!("==")(result[], "some stoops");
}

/*******************************************************************************

    Creates a single element dynamic array that slices val. This will not
    allocate memory in contrast to the '[val]' expression.

    Params:
        val = value to slice

    Returns:
        single element dynamic array that slices val.

*******************************************************************************/

public T[] toArray ( T ) ( ref T val )
{
    return (&val)[0 .. 1];
}

///
unittest
{
    int x;
    int[] arr = toArray(x);
}
