/*******************************************************************************

    Collection of utilities to modify arrays and buffers in-place.

    All function is this module only work on mutable arguments and modify them
    in place. New memory must never be allocated.

    Based on `tango.core.Array` module from Tango library.

    Copyright:
        Copyright (C) 2005-2006 Sean Kelly.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

*******************************************************************************/

module ocean.core.array.Mutation;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.stdc.string; // memmove, memset
import ocean.stdc.math; // fabs;

import ocean.core.Traits;
import ocean.core.Buffer;
import ocean.core.array.DefaultPredicates;

version (UnitTest)
{
    import ocean.core.Test;
    import ocean.text.convert.Format;
}

/*******************************************************************************

    Performs a linear scan of array from [0 .. array.length$(RP), replacing
    occurrences of specified element with new one.  Comparisons will be
    performed using the supplied predicate or '==' if none is supplied.

    Params:
        array = The array to scan.
        element = The pattern to match.
        new_element = The value to substitute.
        pred  = The evaluation predicate, which should return true if e1 is
            equal to e2 and false if not.  This predicate may be any
            callable type.

    Returns:
        The number of elements replaced.

*******************************************************************************/

size_t replace ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( T[] array, in T element, T new_element, Pred pred = Pred.init )
{
    static assert( isCallableType!(Pred) );

    size_t cnt = 0;

    foreach( size_t pos, ref T cur; array )
    {
        if( pred( cur, element ) )
        {
            cur = new_element;
            ++cnt;
        }
    }

    return cnt;
}

///
unittest
{
    auto array = "abbbbc".dup;
    test!("==")(replace(array, 'b', 'x'), 4);
    test!("==")(array, "axxxxc");
}

unittest
{
    test!("==")( replace( "gbbbi".dup, 'a', 'b' ), 0 );
    test!("==")( replace( "gbbbi".dup, 'g', 'h' ), 1 );
    test!("==")( replace( "gbbbi".dup, 'b', 'c' ), 3 );
    test!("==")( replace( "gbbbi".dup, 'i', 'j' ), 1 );
    test!("==")( replace( "gbbbi".dup, 'd', 'e' ), 0 );
}

/// ditto
size_t replace ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( ref Buffer!(T) array, in T element, T new_element, Pred pred = Pred.init )
{
    return replace(array[0..array.length], element, new_element, pred);
}

///
unittest
{
    auto buffer = createBuffer("abbbbc");
    test!("==")(replace(buffer, 'b', 'x'), 4);
    test!("==")(buffer[], "axxxxc");
}

/*******************************************************************************

    Performs a linear scan of the array from [0 .. buf.length$(RP), replacing
    elements where pred returns true.

    Params:
        array = The array to scan.
        new_element = The value to substitute.
        pred = The evaluation predicate, which should return true if the
            element is a valid match and false if not.  This predicate
            may be any callable type.

    Returns:
    The number of elements replaced.

*******************************************************************************/

size_t replaceIf ( T, Pred ) ( T[] array, T new_element, Pred pred )
{
    static assert( isCallableType!(Pred) );

    size_t cnt = 0;

    foreach( size_t pos, ref T cur; array )
    {
        if( pred( cur ) )
        {
            cur = new_element;
            ++cnt;
        }
    }
    return cnt;
}

///
unittest
{
    auto array = "abbc".dup;
    test!("==")(replaceIf(array, 'x', (char c) { return c > 'a'; }), 3);
    test!("==")(array, "axxx");
}

/// ditto
size_t replaceIf ( T, Pred ) ( ref Buffer!(T) array, T new_element, Pred pred )
{
    return replaceIf(array[0..array.length], new_element, pred);
}

///
unittest
{
    auto buffer = createBuffer("abbc");
    test!("==")(replaceIf(buffer, 'x', (char c) { return c > 'a'; }), 3);
    test!("==")(buffer[], "axxx");
}

unittest
{
    test!("==")( replaceIf( "gbbbi".dup, 'b', ( char c ) { return c == 'a'; } ), 0 );
    test!("==")( replaceIf( "gbbbi".dup, 'h', ( char c ) { return c == 'g'; } ), 1 );
    test!("==")( replaceIf( "gbbbi".dup, 'c', ( char c ) { return c == 'b'; } ), 3 );
    test!("==")( replaceIf( "gbbbi".dup, 'j', ( char c ) { return c == 'i'; } ), 1 );
    test!("==")( replaceIf( "gbbbi".dup, 'e', ( char c ) { return c == 'd'; } ), 0 );
}

/*******************************************************************************

    Performs a linear scan of array from [0 .. array.length$(RP), moving all
    elements matching element to the end of the sequence.  The relative order of
    elements not matching one will be preserved.  Comparisons will be
    performed using the supplied predicate or '==' if none is supplied.

    Params:
        array = The array to scan. This parameter is not marked 'ref'
            to allow temporary slices to be modified.  As array is not resized
            in any way, omitting the 'ref' qualifier has no effect on the
            result of this operation, even though it may be viewed as a
            side-effect.
        element = The element value to look for
        pred = The evaluation predicate, which should return true if e1 is
            equal to e2 and false if not.  This predicate may be any
            callable type.

    Returns:
        The number of elements that do not match element.

*******************************************************************************/

size_t moveToEnd ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( T[] array, in T element, Pred pred = Pred.init )
{
    static assert( isCallableType!(Pred) );

    // NOTE: Indexes are passed instead of references because DMD does
    //       not inline the reference-based version.
    void exch( size_t p1, size_t p2 )
    {
        T t = array[p1];
        array[p1] = array[p2];
        array[p2] = t;
    }

    size_t cnt = 0;

    for( size_t pos = 0, len = array.length; pos < len; ++pos )
    {
        if( pred( array[pos], element ) )
            ++cnt;
        else
            exch( pos, pos - cnt );
    }
    return array.length - cnt;
}

/// ditto
deprecated ("Use `moveToEnd()` instead")
size_t remove ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( T[] array, in T element, Pred pred = Pred.init )
{
    return moveToEnd(array, element, pred);
}

///
unittest
{
    auto array = "abbcc".dup;
    test!("==")(moveToEnd(array, 'b'), 3);
    test!("==")(array, "accbb");
}

/// ditto
size_t moveToEnd ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( ref Buffer!(T) array, in T element, Pred pred = Pred.init )
{
    return moveToEnd(array[0..array.length], element, pred);
}

/// ditto
deprecated ("Use `moveToEnd()` instead")
size_t remove ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( ref Buffer!(T) array, in T element, Pred pred = Pred.init )
{
    return moveToEnd(array[0..array.length], element, pred);
}

///
unittest
{
    auto buffer = createBuffer("abbcc");
    test!("==")(moveToEnd(buffer, 'b'), 3);
    test!("==")(buffer[], "accbb");
}

unittest
{
    static void testOne ( cstring _array,
        char element, size_t num, int line = __LINE__ )
    {
        auto array = _array.dup;
        auto t = new NamedTest(Format("moveToEnd.testOne:{}", line));
        t.test!("==")(moveToEnd(array, element), num);
        foreach (pos, cur; array)
            t.test(pos < num ? cur != element : cur == element);
    }

    testOne("abcdefghij", 'x', 10);
    testOne("xabcdefghi", 'x',  9);
    testOne("abcdefghix", 'x',  9);
    testOne("abxxcdefgh", 'x',  8);
    testOne("xaxbcdxxex", 'x',  5);
}

/*******************************************************************************

    Performs a linear scan of array from [0 .. buf.length$(RP), moving all
    elements that satisfy pred to the end of the sequence.  The relative
    order of elements that do not satisfy pred will be preserved.

    Params:
    array = The array to scan.  This parameter is not marked 'ref'
           to allow temporary slices to be modified.  As array is not resized
           in any way, omitting the 'ref' qualifier has no effect on the
           result of this operation, even though it may be viewed as a
           side-effect.
    pred = The evaluation predicate, which should return true if the
           element satisfies the condition and false if not.  This
           predicate may be any callable type.

    Returns:
        The number of elements that do not satisfy pred.

*******************************************************************************/

size_t removeIf ( T, Pred ) ( T[] array, Pred pred )
{
    static assert( isCallableType!(Pred) );

    // NOTE: Indexes are passed instead of references because DMD does
    //       not inline the reference-based version.
    void exch( size_t p1, size_t p2 )
    {
        T t  = array[p1];
        array[p1] = array[p2];
        array[p2] = t;
    }

    size_t cnt = 0;

    for( size_t pos = 0, len = array.length; pos < len; ++pos )
    {
        if( pred( array[pos] ) )
            ++cnt;
        else
            exch( pos, pos - cnt );
    }
    return array.length - cnt;
}

///
unittest
{
    auto array = "abbcc".dup;
    test!("==")(removeIf(array, (char c) { return c == 'b'; }), 3);
    test!("==")(array, "accbb");
}

/// ditto
size_t removeIf ( T, Pred ) ( ref Buffer!(T) array, Pred pred )
{
    return removeIf(array[0..array.length], pred);
}

///
unittest
{
    auto buffer = createBuffer("abbcc");
    test!("==")(removeIf(buffer, (char c) { return c == 'b'; }), 3);
    test!("==")(buffer[], "accbb");
}

unittest
{
    static void testOne ( cstring _array,
        bool delegate(char) dg, size_t num, int line = __LINE__ )
    {
        auto array = _array.dup;
        auto t = new NamedTest(Format("removeIf.testOne:{}", line));
        t.test!("==")(removeIf( array, dg ), num);
        foreach (pos, cur; array)
            t.test(pos < num ? !dg( cur ) : dg( cur ));
    }

    testOne("abcdefghij", ( char c ) { return c == 'x'; }, 10);
    testOne("xabcdefghi", ( char c ) { return c == 'x'; },  9);
    testOne("abcdefghix", ( char c ) { return c == 'x'; },  9);
    testOne("abxxcdefgh", ( char c ) { return c == 'x'; },  8);
    testOne("xaxbcdxxex", ( char c ) { return c == 'x'; },  5);
}

/*******************************************************************************

    Performs a linear scan of array from [0 .. array.length$(RP), moving all
    but the first element of each consecutive group of duplicate elements to
    the end of the sequence.  The relative order of all remaining elements
    will be preserved.  Comparisons will be performed using the supplied
    predicate or '==' if none is supplied.

    Params:
        array = The array to scan.  This parameter is not marked 'ref'
           to allow temporary slices to be modified.  As array is not resized
           in any way, omitting the 'ref' qualifier has no effect on the
           result of this operation, even though it may be viewed as a
           side-effect.
        pred = The evaluation predicate, which should return true if e1 is
           equal to e2 and false if not.  This predicate may be any
           callable type.

    Returns:
        The number of distinct sub-sequences in array.

*******************************************************************************/

size_t distinct ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( T[] array, Pred pred = Pred.init )
{
    static assert( isCallableType!(Pred) );

    // NOTE: Indexes are passed instead of references because DMD does
    //       not inline the reference-based version.
    void exch( size_t p1, size_t p2 )
    {
        T t  = array[p1];
        array[p1] = array[p2];
        array[p2] = t;
    }

    if( array.length < 2 )
        return array.length;

    size_t cnt = 0;
    T element = array[0];

    for( size_t pos = 1, len = array.length; pos < len; ++pos )
    {
        if( pred( array[pos], element ) )
            ++cnt;
        else
        {
            element = array[pos];
            exch( pos, pos - cnt );
        }
    }
    return array.length - cnt;
}

///
unittest
{
    auto array = "aabbcdd".dup;
    auto last = distinct(array);
    test!("==")(array[0 .. last], "abcd");
}

/// ditto
size_t distinct ( T, Pred = DefaultPredicates.IsEqual!(T) )
    ( ref Buffer!(T) array, Pred pred = Pred.init )
{
    return distinct(array[0..array.length], pred);
}

///
unittest
{
    auto buffer = createBuffer("aabbcdd");
    auto last = distinct(buffer);
    test!("==")(buffer[0 .. last], "abcd");
}

unittest
{
    test!("==")(distinct("a".dup), 1);

    static void testOne ( cstring _array,
        cstring expected, int line = __LINE__ )
    {
        auto array = _array.dup;
        auto t = new NamedTest(Format("distinct.testOne:{}", line));
        t.test!("==")(distinct(array), expected.length);
        t.test!("==")(array[0 .. expected.length], expected);
    }

    testOne("abcdefghij", "abcdefghij");
    testOne("aabcdefghi", "abcdefghi");
    testOne("bcdefghijj", "bcdefghij");
    testOne("abccdefghi", "abcdefghi");
    testOne("abccdddefg", "abcdefg");
}

/*******************************************************************************

    Partitions array such that all elements that satisfy pred will be placed
    before the elements that do not satisfy pred.  The algorithm is not
    required to be stable.

    Params:
        array  = The array to partition.  This parameter is not marked 'ref'
            to allow temporary slices to be sorted.  As array is not resized
            in any way, omitting the 'ref' qualifier has no effect on
            the result of this operation, even though it may be viewed
            as a side-effect.
        pred = The evaluation predicate, which should return true if the
            element satisfies the condition and false if not.  This
            predicate may be any callable type.

    Returns:
        The number of elements that satisfy pred.

*******************************************************************************/

size_t partition ( T, Pred ) ( T[] array, Pred pred )
{
    static assert( isCallableType!(Pred ) );

    // NOTE: Indexes are passed instead of references because DMD does
    //       not inline the reference-based version.
    void exch( size_t p1, size_t p2 )
    {
        T t = array[p1];
        array[p1] = array[p2];
        array[p2] = t;
    }

    if( array.length == 0 )
        return 0;

    size_t  l = 0,
            r = array.length,
            i = l,
            j = r - 1;

    while( true )
    {
        while( i < r && pred( array[i] ) )
            ++i;
        while( j > l && !pred( array[j] ) )
            --j;
        if( i >= j )
            break;
        exch( i++, j-- );
    }
    return i;
}

///
unittest
{
    auto array = "af242df56s2".dup;
    test!("==")(partition(array, (char c) { return c >= '0' && c <= '9'; }), 6);
}

/// ditto
size_t partition ( T, Pred ) ( ref Buffer!(T) array, Pred pred )
{
    return partition(array[0..array.length], pred);
}

///
unittest
{
    auto buffer = createBuffer("af242df56s2");
    test!("==")(partition(buffer, (char c) { return c >= '0' && c <= '9'; }), 6);
}

unittest
{
    test!("==")(partition("".dup, (char c) { return true; }), 0);

    static void testOne ( cstring _array,
        bool delegate(char) dg, size_t num, int line = __LINE__ )
    {
        auto array = _array.dup;
        auto t = new NamedTest(Format("partition.testOne:{}", line));
        t.test!("==")(partition(array, dg), num);
        for ( size_t pos = 0; pos < array.length; ++pos )
            t.test( pos < num ? dg( array[pos] ) : !dg( array[pos] ) );
    }

    testOne("abcdefg".dup, ( char c ) { return c < 'a'; }, 0);
    testOne("gfedcba".dup, ( char c ) { return c < 'a'; }, 0);
    testOne("abcdefg".dup, ( char c ) { return c < 'h'; }, 7);
    testOne("gfedcba".dup, ( char c ) { return c < 'h'; }, 7);
    testOne("abcdefg".dup, ( char c ) { return c < 'd'; }, 3);
    testOne("gfedcba".dup, ( char c ) { return c < 'd'; }, 3);
    testOne("bbdaabc".dup, ( char c ) { return c < 'c'; }, 5);
    testOne("f".dup,       ( char c ) { return c == 'f'; }, 1);
}

/*******************************************************************************

    Sorts array using the supplied predicate or '<' if none is supplied.  The
    algorithm is not required to be stable.  The current implementation is
    based on quicksort, but uses a three-way partitioning scheme to improve
    performance for ranges containing duplicate values (Bentley and McIlroy,
    1993).

    Params:
        array = The array to sort.  This parameter is not marked 'ref' to
            allow temporary slices to be sorted.  As array is not resized
            in any way, omitting the 'ref' qualifier has no effect on
            the result of this operation, even though it may be viewed
            as a side-effect.
        pred = The evaluation predicate, which should return true if e1 is
            less than e2 and false if not.  This predicate may be any
            callable type.

*******************************************************************************/

T[] sort ( T, Pred = DefaultPredicates.IsLess!(T) )
    ( T[] array, Pred pred = Pred.init )
{
    static assert( isCallableType!(Pred ) );

    bool equiv( T p1, T p2 )
    {
        return !pred( p1, p2 ) && !pred( p2, p1 );
    }

    // NOTE: Indexes are passed instead of references because DMD does
    //       not inline the reference-based version.
    void exch( size_t p1, size_t p2 )
    {
        T t  = array[p1];
        array[p1] = array[p2];
        array[p2] = t;
    }

    // NOTE: This algorithm operates on the inclusive range [l .. r].
    void insertionSort( size_t l, size_t r )
    {
        for( size_t i = r; i > l; --i )
        {
            // swap the min element to array[0] to act as a sentinel
            if( pred( array[i], array[i - 1] ) )
                exch( i, i - 1 );
        }
        for( size_t i = l + 2; i <= r; ++i )
        {
            size_t  j = i;
            T    v = array[i];

            // don't need to test (j != l) because of the sentinel
            while( pred( v, array[j - 1] ) )
            {
                array[j] = array[j - 1];
                j--;
            }
            array[j] = v;
        }
    }

    size_t medianOf( size_t l, size_t m, size_t r )
    {
        if( pred( array[m], array[l] ) )
        {
            if( pred( array[r], array[m] ) )
                return m;
            else
            {
                if( pred( array[r], array[l] ) )
                    return r;
                else
                    return l;
            }
        }
        else
        {
            if( pred( array[r], array[m] ) )
            {
                if( pred( array[r], array[l] ) )
                    return l;
                else
                    return r;
            }
            else
                return m;
        }
    }

    // NOTE: This algorithm operates on the inclusive range [l .. r].
    void quicksort( size_t l, size_t r, size_t d )
    {
        if( r <= l )
            return;

        // HEURISTIC: Use insertion sort for sufficiently small arrays.
        enum { MIN_LENGTH = 80 }
        if( r - l < MIN_LENGTH )
            return insertionSort( l, r );

        // HEURISTIC: Use the median-of-3 value as a pivot.  Swap this
        //            into r so quicksort remains untouched.
        exch( r, medianOf( l, l + (r - l) / 2, r ) );

        // This implementation of quicksort improves upon the classic
        // algorithm by partitioning the array into three parts, one
        // each for keys smaller than, equal to, and larger than the
        // partitioning element, v:
        //
        // |--less than v--|--equal to v--|--greater than v--[v]
        // l               j              i                   r
        //
        // This approach sorts ranges containing duplicate elements
        // more quickly.  During processing, the following situation
        // is maintained:
        //
        // |--equal--|--less--|--[###]--|--greater--|--equal--[v]
        // l         p        i         j           q          r
        //
        // Please note that this implementation varies from the typical
        // algorithm by replacing the use of signed index values with
        // unsigned values.

        T v = array[r];
        size_t  i = l,
                j = r,
                p = l,
                q = r;

        while( true )
        {
            while( pred( array[i], v ) )
                ++i;
            while( pred( v, array[--j] ) )
                if( j == l ) break;
            if( i >= j )
                break;
            exch( i, j );
            if( equiv( array[i], v ) )
                exch( p++, i );
            if( equiv( v, array[j] ) )
                exch( --q, j );
            ++i;
        }
        exch( i, r );
        if( p < i )
        {
            j = i - 1;
            for( size_t k = l; k < p; k++, j-- )
                exch( k, j );
            quicksort( l, j, d );
        }
        if( ++i < q )
        {
            for( size_t k = r - 1; k >= q; k--, i++ )
                exch( k, i );
            quicksort( i, r, d );
        }
    }

    size_t maxDepth( size_t x )
    {
        size_t d = 0;

        do
        {
            ++d;
            x /= 2;
        } while( x > 1 );
        return d * 2; // same as "floor( log( x ) / log( 2 ) ) * 2"
    }

    if( array.length > 1 )
    {
        quicksort( 0, array.length - 1, maxDepth( array.length ) );
    }

    return array;
}

unittest
{
    static void testOne ( cstring _array, int line = __LINE__ )
    {
        auto array = _array.dup;
        auto t = new NamedTest(Format("sort.testOne:{}", line));
        sort( array );
        for ( ptrdiff_t i = 0; i + 1 < array.length; ++ i )
            t.test!(">=")(array[i+1], array[i]);
    }

    testOne("");
    testOne("a");
    testOne("mkcvalsidivjoaisjdvmzlksvdjioawmdsvmsdfefewv");
    testOne("asdfasdfasdfasdfasdfasdfasdfasdfasdfasdfasdf");
    testOne("the quick brown fox jumped over the lazy dog");
    testOne("abcdefghijklmnopqrstuvwxyz");
    testOne("zyxwvutsrqponmlkjihgfedcba");

    auto longer = new char[500];
    foreach (i, ref c; longer)
        c = cast(char) (i % 7);
    testOne(longer);

    auto very_long = new char[100_000];
    foreach (i, ref c; very_long)
        c = cast(char) (i % 34);
    testOne(very_long);
}

/*******************************************************************************

    Swaps elements of argument array so they all come in reverse order

    Params:
        array = array slice to reverse in-place

    Returns:
        slice of the argument

*******************************************************************************/

T[] reverse (T) (T[] array)
{
    for (ptrdiff_t i = 0; i < array.length / 2; ++i)
    {
        auto tmp = array[i];
        array[i] = array[$-i-1];
        array[$-i-1] = tmp;
    }

    return array;
}

///
unittest
{
    assert (reverse((int[]).init) == (int[]).init);
    assert (reverse([1, 2, 3]) == [3, 2, 1]);
    assert (reverse([1, 2, 3, 4]) == [4, 3, 2, 1]);
}

////////////////////////////////////////////////////////////////////////////////
//          Functions below originally come from ocean.core.Array             //
////////////////////////////////////////////////////////////////////////////////

/*******************************************************************************

    Copies the contents of one element of arrays to another, starting at
    dest[start], setting the length of the destination array first.
    Note that start may be greater than the initial length of dest; dest will
    then be extended appropriately.

    Template params:
        func = function name for static assertion messages

    Params:
        dest   = reference to the destination array
        arrays = arrays to copy; a null parameter has the same effect as an
                 empty array.

    Returns:
        dest

    TODO: Could be made public but must then not rely on elements to be arrays.

*******************************************************************************/

public DE[] append ( DE, T... ) ( ref Buffer!(DE) dest, T arrays )
{
    size_t appended_length = 0;
    foreach (array; arrays)
        appended_length += array.length;
    dest.reserve(dest.length + appended_length);

    foreach (array; arrays)
        dest ~= array;

    return dest[];
}

// deprecated("Must use Buffer argument")
public DE[] append ( DE, T... ) ( ref DE[] dest, T arrays )
{
    return append( *(cast(Buffer!(DE)*) &dest), arrays);
}

///
unittest
{
    auto buffer = createBuffer("zero");
    append(buffer, "one", "two", "three");
    test!("==")(buffer[], "zeroonetwothree");
}

/*******************************************************************************

    Concatenates a list of arrays into a destination array. The function results
    in at most a single memory allocation, if the destination array is too small
    to contain the concatenation results.

    The destination array is passed as a reference, so its length can be
    modified in-place as required. This avoids any per-element memory
    allocation, which the normal ~ operator suffers from.

    Template params:
        T = type of array element

    Params:
        dest = reference to the destination array
        arrays = variadic list of arrays to concatenate

    Returns:
        dest

********************************************************************************/

public DE[] concat ( DE, T... ) ( ref Buffer!(DE) dest, T arrays )
{
    dest.reset();
    return append(dest, arrays);
}

///
unittest
{
    Buffer!(char) dest;
    concat(dest, "hello "[], "world"[]);
    test!("==")(dest[], "hello world");
}


// deprecated("Must use Buffer argument")
public DE[] concat ( DE, T... ) ( ref DE[] dest, T arrays )
{
    return concat(*(cast(Buffer!(DE)*) &dest), arrays);
}

deprecated unittest
{
    mstring dest;
    concat(dest, "hello "[], "world"[]);
    test!("==")(dest, "hello world");
}

/*******************************************************************************

    Copies the contents of one array to another, setting the length of the
    destination array first.

    This function is provided as a shorthand for this common operation.

    Template params:
        T = type of array element

    Params:
        dest = reference to the destination array
        array = array to copy; null has the same effect as an empty array

    Returns:
        dest

*******************************************************************************/

public T[] copy ( T, T2 ) ( ref Buffer!(T) dest, T2[] src )
{
    static assert (is(typeof({ dest[] = src[]; })),
                   "Type " ~ T2.stringof ~ " cannot be assigned to " ~ T.stringof);

    dest.length = src.length;
    dest[] = src[];
    return dest[];
}

///
unittest
{
    Buffer!(char) dest;
    cstring src = "hello";
    copy(dest, src);
    test!("==")(dest[], "hello"[]);
}

unittest
{
    Buffer!(cstring) dest;
    mstring[] src = [ "Hello".dup, "World".dup ];
    copy(dest, src);
    // Doesn't compile in D2...
    //test!("==")(dest[], src);
}

// deprecated("Must use Buffer argument")
public T[] copy ( T, T2 ) ( ref T[] dest, T2[] src )
{
    return copy(*(cast(Buffer!(T)*) &dest), src);
}

deprecated unittest
{
    mstring dest;
    cstring src = "hello";
    copy(dest, src);
    test!("==")(dest[], "hello"[]);
}

/*******************************************************************************

    Copies the contents of src to dest, increasing dest.length if required.
    Since dest.length will not be decreased, dest will contain tailing garbage
    if src.length < dest.length.

    Template params:
        T = type of array element

    Params:
        dest  = reference to the destination array
        array = array to copy; null has the same effect as an empty array

    Returns:
        slice to copied elements in dest

*******************************************************************************/

public T[] copyExtend ( T, T2 ) ( ref Buffer!(T) dest, T2[] src )
{
    static assert (is(typeof({ dest[] = src[]; })),
                   "Type " ~ T2.stringof ~ " cannot be assigned to " ~ T.stringof);

    if (dest.length < src.length)
        dest.length = src.length;
    dest[0 .. src.length] = src[];
    return dest[0 .. src.length];
}

///
unittest
{
    auto dst = createBuffer("aa");
    copyExtend(dst, "bbbb");
    test!("==")(dst[], "bbbb");
    copyExtend(dst, "ccc");
    test!("==")(dst[], "cccb");
}

// deprecated("Must use Buffer argument")
public T[] copyExtend ( T, T2 ) ( ref T[] dest, T2[] src )
{
    return copyExtend(*(cast(Buffer!(T)*) &dest), src);
}

deprecated unittest
{
    auto dst = "aa".dup;
    copyExtend(dst, "bbbb");
    test!("==")(dst[], "bbbb");
    copyExtend(dst, "ccc");
    test!("==")(dst[], "cccb");
}

/*******************************************************************************

    Appends an element to a list of arrays, and copies the contents of the
    passed source array into the new element, setting the length of the
    destination array first.

    This function is provided as a shorthand for this common operation.

    Template params:
        T = type of array element

    Params:
        dest = reference to the destination array list
        array = array to copy

    Returns:
        dest

*******************************************************************************/

public void appendCopy ( T, T2 ) ( ref Buffer!(T)[] dest, T2[] src )
{
    dest.length = dest.length + 1;
    copy(dest[dest.length - 1], src);
}

///
unittest
{
    Buffer!(char)[] dest;
    cstring src = "hello";
    appendCopy(dest, src);
    test!("==")(dest[0][], "hello");
}

unittest
{
    Buffer!(cstring)[] dest;
    mstring[] src = [ "Hello".dup, "World".dup ];
    appendCopy(dest, src);
    // Doesn't compile in D2...
    //test!("==")(dest[0][], src);
}


// deprecated ("Must use Buffer as a buffer argument")
public void appendCopy ( T, T2 ) ( ref T[][] dest, T2[] src )
{
    appendCopy(*(cast(Buffer!(T)[]*) &dest), src);
}

///
deprecated unittest
{
    mstring[] dest;
    cstring src = "hello";
    appendCopy(dest, src);
    test!("==")(dest[0][], "hello");
}

/*******************************************************************************

    Removes and returns (via the 'popped' out parameter) the last element in an
    array. If the provided array is empty, the function returns false.

    Template params:
        T = type of array element

    Params:
        buffer = buffer to pop an element from
        popped = popped element (if array contains > 0 elements)

    Returns:
        true if an element was popped

*******************************************************************************/

public bool pop ( T ) ( ref Buffer!(T) buffer, out T popped )
{
    if (buffer.length == 0)
        return false;

    popped = *buffer[buffer.length - 1];
    buffer.length = buffer.length - 1;
    return true;
}

///
unittest
{
    auto buffer = createBuffer("something");
    char elem;
    test(pop(buffer, elem));
    test!("==")(buffer[], "somethin"[]);
    test!("==")(elem, 'g');
}

// deprecated ("Must use Buffer as a buffer argument")
public bool pop ( T ) ( ref T[] array, out T popped )
{
    return pop (* cast(Buffer!(T)*) &array, popped);
}

deprecated unittest
{
    auto buffer = "something".dup;
    char elem;
    test(pop(buffer, elem));
    test!("==")(buffer, "somethin"[]);
    test!("==")(elem, 'g');
}

/*******************************************************************************

    Removes elements from the middle of a buffer, maintaining the order of the
    remaining elements by shifting them left using memmove.

    Template params:
        T = type of buffer element

    Params:
        buffer = buffer to remove from
        index = position in buffer from which to remove elements
        remove_elems = number of elements to remove, defaults to one

    Returns:
        slice of buffer

*******************************************************************************/

public T[] removeShift ( T ) ( ref Buffer!(T) buffer, size_t index,
    size_t remove_elems = 1 )
in
{
    assert(index < buffer.length, "removeShift: index is >= buffer length");
    assert(index + remove_elems - 1 < buffer.length, "removeShift: end is >= buffer length");
}
body
{
    if ( remove_elems == 0 )
        return buffer[];

    auto end = index + remove_elems - 1;
    auto shift_elems = (buffer.length - end) - 1;

    if ( shift_elems )
    {
        // shift after elements to the left
        void* src = buffer[].ptr + end + 1;
        void* dst = buffer[].ptr + index;
        size_t num = T.sizeof * shift_elems;

        memmove(dst, src, num);
    }

    // adjust buffer length
    buffer.length = buffer.length - remove_elems;
    return buffer[];
}

///
unittest
{
    auto arr = createBuffer("something");
    removeShift(arr, 3, 4);
    test!("==")(arr[], "somng"[]);
}

// deprecated ("Must use Buffer as a buffer argument")
public T[] removeShift ( T ) ( ref T[] buffer, size_t index,
    size_t remove_elems = 1 )
{
    return removeShift(*cast(Buffer!(T)*) &buffer, index, remove_elems);
}

deprecated unittest
{
    mstring arr = "something".dup;
    removeShift(arr, 3, 4);
    test!("==")(arr, "somng"[]);
}

/*******************************************************************************

    Inserts elements into the middle of a buffer, maintaining the order of the
    existing elements by shifting them right using memmove.

    Template params:
        T = type of buffer element

    Params:
        buffer = buffer to insert into
        index = position in buffer at which to insert new elements
        insert_elems = number of elements to insert, defaults to one

    Returns:
        slice of buffer

*******************************************************************************/

public T[] insertShift ( T ) ( ref Buffer!(T) buffer, size_t index,
    size_t insert_elems = 1)
in
{
    assert(index <= buffer.length, "insertShift: index is > buffer length");
}
body
{
    if ( insert_elems == 0 )
        return buffer[];

    auto shift_elems = buffer.length - index;

    // adjust buffer length
    buffer.length = buffer.length + insert_elems;

    // shift required elements one place to the right
    if ( shift_elems )
    {
        void* src = buffer[].ptr + index;
        void* dst = buffer[].ptr + index + insert_elems;
        size_t num = T.sizeof * shift_elems;
        memmove(dst, src, num);
    }

    return buffer[];
}

///
unittest
{
    auto arr = createBuffer("something");
    insertShift(arr, 2, 2);
    test!("==")(arr[], "somemething");
}

// deprecated ("Must use Buffer as a buffer argument")
public T[] insertShift ( T ) ( ref T[] buffer, size_t index,
    size_t insert_elems = 1)
{
    return insertShift(* cast(Buffer!(T)*) &buffer, index, insert_elems);
}

/*******************************************************************************

    Sorts array and removes all value duplicates.

    Template params:
        T    = type of array element
        sort = true: do array.sort first; false: array is already sorted

    Params:
        array = array to clean from duplicate values

    Returns:
        result

*******************************************************************************/

public T[] uniq ( T, bool sort = true ) ( T[] array )
{
    if (array.length)
    {
        size_t n = 0;

        static if (sort)
        {
            .sort(array);
        }

        T item = array[n];

        foreach (element; array)
        {
            if (element != item)
            {
                array[++n] = element;
                item       = element;
            }
        }

        return array[0 .. n + 1];
    }
    else
    {
        return array;
    }
}

///
unittest
{
    int[] arr = [ 42, 43, 43, 42, 2 ];
    auto slice = uniq(arr);
    test!("==")(slice, [ 2, 42, 43 ]);
    test!("==")(arr, [ 2, 42, 43, 43, 43 ]);
}

unittest
{
    auto buffer = createBuffer([ 42, 43, 43, 42, 2 ]);
    auto slice = uniq(buffer[]);
    test!("==")(slice, [ 2, 42, 43 ][]);
    test!("==")(buffer[], [ 2, 42, 43, 43, 43 ][]);
}

/*******************************************************************************

    Sorts array and checks if it contains at least one duplicate.

    Template params:
        T    = type of array element
        sort = true: do array.sort first; false: array is already sorted

    Params:
        array = array to clean from duplicate values

    Returns:
        true if array contains a duplicate or false if not. Returns false if
        array is empty.

*******************************************************************************/

public bool containsDuplicate ( T, bool sort = true ) ( T[] array )
{
    return !!findDuplicates!(T, sort)(
        array,
        delegate int(ref size_t index, ref T element) {return true;}
    );
}

/*******************************************************************************

    Sorts array and iterates over each array element that compares equal to the
    previous element.

    To just check for the existence of duplicates it's recommended to make
    found() return true (or some other value different from 0) to stop the
    iteration after the first duplicate.

    To assert array has no duplicates or throw an exception if it has, put the
    `assert(false)` or `throw ...` in `found()`:
    ---
        int[] array;

        findDuplicates(array,
                       (ref size_t index, ref int element)
                       {
                           throw new Exception("array contains duplicates");
                           return 0; // pacify the compiler
                       });
    ---

    Template params:
        T    = type of array element
        sort = true: do array.sort first; false: array is already sorted

    Params:
        array = array to clean from duplicate values
        found = `foreach`/`opApply()` style delegate, called with the index and
                the value of each array element that is equal to the previous
                element, returns 0 to continue or a value different from 0 to
                stop iteration.

    Returns:
        - 0 if no duplicates were found so `found()` was not called or
        - 0 if `found()` returned 0 on each call or
        - the non-zero value returned by `found()` on the last call.

*******************************************************************************/

public int findDuplicates ( T, bool sort = true )
    ( T[] array, int delegate ( ref size_t index, ref T element ) found )
{
    if (array.length)
    {
        static if (sort)
        {
            .sort(array);
        }

        foreach (i, ref element; array[1 .. $])
        {
            if (element == array[i])
            {
                auto j = i + 1;
                if (int x = found(j, element))
                {
                    return x;
                }
            }
        }
    }

    return 0;
}

unittest
{
    uint n_iterations, n_duplicates;

    struct Found
    {
        int    value;
        size_t index;
    }

    Found[8] found;
    int[8] array;
    alias findDuplicates!(typeof(array[0]), false) fd;

    int found_cb ( ref size_t index, ref int element )
    in
    {
        assert(n_iterations);
    }
    body
    {
        test(index);
        test(index < array.length);
        test(array[index] == array[index - 1]);
        found[n_duplicates++] = Found(element, index);
        return !--n_iterations;
    }

    array[] = 2;

    test(containsDuplicate(array));

    for (uint i = 1; i < array.length; i++)
    {
        n_iterations = i;
        n_duplicates = 0;
        int ret = fd(array, &found_cb);
        test(ret);
        test(n_duplicates == i);
    }

    n_iterations = array.length;
    n_duplicates = 0;
    {
        int ret = fd(array, &found_cb);
        test(!ret);
    }
    test(n_duplicates == array.length - 1);

    array[] = [2, 3, 5, 7, 11, 13, 17, 19];

    test(!containsDuplicate(array));

    n_duplicates = 0;

    for (uint i = 1; i <= array.length; i++)
    {
        n_iterations = i;
        int ret = fd(array, &found_cb);
        test(!ret);
        test(!n_duplicates);
    }

    n_iterations = array.length;
    array[] = 2;
    {
        n_duplicates = 0;
        int ret = fd(array[0 .. 0], &found_cb);
        test(!ret);
        test(!n_duplicates);
        ret = fd(array[0 .. 1], &found_cb);
        test(!ret);
        test(!n_duplicates);
        ret = fd(array[0 .. 2], &found_cb);
        test(!ret);
        test(n_duplicates == 1);
    }
}

/*******************************************************************************

    Moves all elements from array which match the exclusion criterum
    represented by exclude to the back of array so that the elements that do not
    match this criterium are in the front.

    array is modified in-place, the order of the elements may change.

    exclude is expected to be callable (function or delegate), accepting exactly
    one T argument and returning an integer (bool, (u)int, (u)short or (u)long).
    It is called with the element in question and should return true if that
    element should moved to the back or false if to the front.

    Params:
        array   = array to move values matching the exclusion criterum to the
                  back
        exclude = returns true if the element matches the exclusion criterium

    Returns:
        the index of the first excluded elements in array. This element and all
        following ones matched the exclusion criterum; all elements before it
        did not match.
        0 indicates that all elements matched the exclusion criterium
        and array.length that none matched.

        This allows the calling code to keep only the non-excluded items
        by calling: `arr.length = filterInPlace(arr, filterFunc);`

    Out:
        The returned index is at most array.length.

*******************************************************************************/

public size_t filterInPlace ( T, Exclude ) ( T[] array, Exclude exclude )
out (end)
{
    assert(end <= array.length, "result index out of bounds");
}
body
{
    alias ReturnAndArgumentTypesOf!(Exclude) ExcludeParams;

    static assert(
        ExcludeParams.length,
        "exclude is expected to be callable, not \"" ~ Exclude.stringof ~ '"'
    );
    static assert(
        ExcludeParams.length == 2,
        "exclude is expected to accept one argument, which " ~
            Exclude.stringof ~ " doesn't'"
    );
    static assert(
        is(ExcludeParams[0]: long),
        "the return type of exclude is expected to be an integer type, " ~
            "not " ~ ExcludeParams[0].stringof
    );
    static assert(
        is(ExcludeParams[1] == T),
        "exclude is expected to accept an argument of type " ~ T.stringof ~
            ", not " ~ ExcludeParams[1].stringof
    );

    return filterInPlaceCore(
        array.length,
        (size_t i)
        {
            return !!exclude(array[i]);
        },
        (size_t i, size_t j)
        {
            typeid(T).swap(&array[i], &array[j]);
        }
    );
}

unittest
{
    auto arr = "something".dup;
    filterInPlace(arr, (char c) { return c / 2; });
}

/*******************************************************************************

    Moves all elements in an array which match the exclusion criterum
    represented by exclude to the back of array so that the elements that do not
    match this criterium are in the front.

    array is modified in-place, the order of the elements may change.

    exclude is called with the index of the element in question and should
    return true if array[index] should moved to the back or false if to the
    front. At the time exclude is called, the order of the array elements may
    have changed so exclude should index the same array instance this function
    is working on (i.e. not a copy).

    Params:
        length  = array length
        exclude = returns true if array)[index] matches the exclusion
                  criterium
        swap    = swaps array[i] and array[j]

    Returns:
        the index of the first excluded elements in the array. This element
        and all following ones matched the exclusion criterum; all elements
        before it did not match.
        length indicates that all elements matched the exclusion criterium and
        0 that none matched.

*******************************************************************************/

private size_t filterInPlaceCore ( size_t length,
    bool delegate ( size_t index ) exclude,
    void delegate ( size_t i, size_t j ) swap )
out (end)
{
    assert(end <= length, "result length out of bounds");
}
body
{
    for (size_t i = 0; i < length; i++)
    {
        if (exclude(i))
        {
            length--;

            while (length > i)
            {
                if (exclude(length))
                {
                    length--;
                }
                else
                {
                    swap(i, length);
                    break;
                }
            }
        }
    }

    return length;
}

/******************************************************************************/

unittest
{
    uint[] array = [2, 3, 5, 8, 13, 21, 34, 55, 89, 144];
    size_t end;

    /***************************************************************************

        Returns true if array[0 .. end] contains n or false if not.

    ***************************************************************************/

    bool inIncluded ( uint n )
    {
        foreach (element; array[0 .. end])
        {
            if (element == n) return true;
        }

        return false;
    }

    /***************************************************************************

        Returns true if array[end .. $] contains n or false if not.

    ***************************************************************************/

    bool inExcluded ( uint n )
    {
        foreach (element; array[end .. $])
        {
            if (element == n) return true;
        }

        return false;
    }

    /***************************************************************************

        Returns true n is even or false if n is odd.

    ***************************************************************************/

    bool even ( uint n )
    {
        return !(n & 1);
    }

    end = .filterInPlace(array, &even);
    assert(end == 6);
    assert(inIncluded(3));
    assert(inIncluded(5));
    assert(inIncluded(13));
    assert(inIncluded(21));
    assert(inIncluded(55));
    assert(inIncluded(89));
    assert(inExcluded(2));
    assert(inExcluded(8));
    assert(inExcluded(34));
    assert(inExcluded(144));

    array    = [2, 4, 6];
    end = .filterInPlace(array, &even);
    assert(!end);
    assert(inExcluded(2));
    assert(inExcluded(4));
    assert(inExcluded(6));

    array    = [8];
    end = .filterInPlace(array, &even);
    assert(!end);
    assert(array[end] == 8);

    array    = [12345];
    end = .filterInPlace(array, &even);
    assert(end == array.length);
    assert(array[0] == 12345);

    array = [1, 2, 4, 6];
    end = .filterInPlace(array, &even);
    assert(end == 1);
    assert(array[0] == 1);
    assert(inExcluded(2));
    assert(inExcluded(4));
    assert(inExcluded(6));

    array = [1, 3, 5, 7];
    end = .filterInPlace(array, &even);
    assert(end == array.length);
    assert(inIncluded(1));
    assert(inIncluded(3));
    assert(inIncluded(5));
    assert(inIncluded(7));

    array = [1, 2, 5, 7];
    end = .filterInPlace(array, &even);
    assert(end == 3);
    assert(inIncluded(1));
    assert(inIncluded(5));
    assert(inIncluded(7));
    assert(inExcluded(2));
}

/*******************************************************************************

    Shuffles the elements of array in-place.

    Params:
        array = array with elements to shuffle
        rand  = random number generator, will be invoked array.length - 1 times

    Returns:
        shuffled array

*******************************************************************************/

public T[] shuffle ( T ) ( T[] array, lazy double rand )
{
    auto result = shuffle(
        array,
        (size_t i) { return cast(size_t) (fabs(rand) * (i + 1)); }
    );
    return result;
}

///
unittest
{
    int[] arr = [ 1, 2, 3, 4 ];
    auto random_generator = () { return 0.42; }; // not proven by the dice roll
    shuffle(arr, random_generator());
}

/*******************************************************************************

    Shuffles the elements of array in-place.

    Params:
        array     = array with elements to shuffle
        new_index = returns the new index for the array element whose index is
                    currently i. i is guaranteed to be in the range
                    [1 .. array.length - 1]; the returned index should be in the
                    range [0 .. i] and must be in range [0 .. array.length - 1].

    Returns:
        shuffled array

*******************************************************************************/

public T[] shuffle ( T ) ( T[] array, size_t delegate ( size_t i ) new_index )
{
    for (auto i = array.length? array.length - 1 : 0; i; i--)
    {
        auto j = new_index(i);
        auto tmp = array[i];
        array[i] = array[j];
        array[j] = tmp;
    }

    return array;
}

///
unittest
{
    int[] arr = [ 1, 2, 3, 4 ];
    int[] orig = arr.dup;
    auto modified = shuffle(arr, (size_t i) { return i; });
    test!("==")(modified, orig);
}

/******************************************************************************

    Resets each elements of array to its initial value.

    T.init must consist only of zero bytes.

    Params:
        array = array to clear elements

    Returns:
        array with cleared elements

 ******************************************************************************/

public T[] clear ( T ) ( T[] array )
in
{
    assert(isClearable!(T), T.stringof ~ ".init contains a non-zero byte so " ~
           (T[]).stringof ~ " cannot be simply cleared");
}
body
{
    memset(array.ptr, 0, array.length * array[0].sizeof);

    return array;
}

unittest
{
    auto arr = [ 1, 2, 3 ];
    clear(arr);
}

/******************************************************************************

    Checks if T.init consists only of zero bytes so that a T[] array can be
    cleared by clear().

    Returns:
        true if a T[] array can be cleared by clear() or false if not.

 ******************************************************************************/

bool isClearable ( T ) ( )
{
    const size_t n = T.sizeof;

    T init;

    ubyte[n] zero_data;

    return (cast (void*) &init)[0 .. n] == zero_data;
}

unittest
{
    auto x = isClearable!(double);
}

/*******************************************************************************

    Selects the kth element of an array as defined by the given predicate.

    Notes:
        -> Uses the Quickselect selection algorithm
           (http://en.wikipedia.org/wiki/Quickselect)
        -> Typically, Quickselect is used to select the kth smallest element
           of an array, but this function can also be used to select elements
           ordered in any fashion, as defined by the given predicate.
        -> The array elements may be reordered during the selection process.
        -> The following would be true if the selection happens successfully
           (i.e. if no exception is thrown):
               * the kth element in the array as defined by the given
                 predicate would have been moved to index 'k'.
               * All elements before index 'k' are guaranteed to be passed by
                 the predicate compared to element 'k' (i.e. the predicate
                 would return true) whereas all elements after index 'k' are
                 guaranteed to not be passed by the predicate compared to
                 element 'k' (i.e.  the predicate would return false).  This
                 means that, if the kth smallest element is being selected,
                 then all elements before the kth smallest element would be
                 lesser than it and all elements after the kth smallest
                 element would be greater than or equal to it. However, no
                 guarantees are made about the sorting order of the elements
                 before/after the kth smallest element. In other words,
                 unordered partial sorting of the array will take place.
        -> The result is defined only if all values in the array are ordered
           (unordered values like floating-point NaNs could result in
           undefined behaviour).

    Params:
        arr  = the array being worked upon.
        k    = the order statistic being looked for (starting from zero). In
               particular, there should be 'k' elements in the array for which
               the predicate will return true.
        pred = predicate used for array element comparisons. Takes two array
               elements to be compared and returns true/false based upon the
               comparison.
               (defaults to a comparison using "<" if no predicate is given)

    Returns:
        the index of the kth element in the array as defined by the ordering
        predicate.

    Throws:
        new Exception if input array is empty.

*******************************************************************************/

size_t select ( T, Pred = DefaultPredicates.IsLess!(T) )
    ( T[] arr, size_t k, Pred pred = Pred.init )
{
    /* For best results, i.e. to achieve O(n) performance from
     * Quickselect, it is recommended to choose a random initial pivot
     * value. But for now, for the sake of simplicity, the selection
     * function is called with its default value of zero which causes
     * the first value in the array to be treated as the initial pivot
     * value. */

    quickselect(arr, k, pred);

    if ( k >= arr.length )
    {
        k = arr.length - 1;
    }

    return k;
}

/*******************************************************************************

    Same as `select` with two changes:

    1. An additional input parameter:
           initial_pivot_index = the array index at which the first pivot
                                 value can be found. In theory, the pivot
                                 value can be chosen at random, but
                                 making an intelligent first guess close
                                 to the expected kth smallest (or
                                 largest) element is a good idea as that
                                 reduces the number of iterations needed
                                 to close-in on the target value
                                 (defaults to zero).
    2. The return value:
           returns the kth element in the array as defined by the
           ordering predicate.

*******************************************************************************/

T quickselect ( T, Pred = DefaultPredicates.IsLess!(T) )
    ( T[] arr, size_t k, Pred pred = Pred.init, size_t initial_pivot_index = 0 )
{
    static assert (isCallableType!(Pred));

    /*
     * Partitions a range of elements within an array based on a pivot
     * value.
     *
     * At the end of the partition function in a typical Quickselect
     * example, the range of elements being worked upon would be
     * modified such that all elements before the pivot element will be
     * smaller than it, while all elements after the pivot element will
     * be greater than it. This function is capable of this typical
     * behaviour as well as the opposite behaviour depending upon the
     * given predicate.
     *
     * Params:
     *  arr         = array being worked upon.
     *  left        = leftmost index of the range of elements to
     *                partition.
     *  right       = rightmost index of the range of elements to
     *                partition.
     *  pivot_index = index of the pivot value to be used.
     *  pred        = predicate used for array element comparisons.
     *                Takes two array elements to be compared and
     *                returns true/false based upon the comparison.
     *
     * Returns:
     *  the new index to which the pivot value has moved.
     */

    static size_t partition( T[] arr, size_t left, size_t right,
                      size_t pivot_index, Pred pred )
    {
        if( left >= right )
        {
            return left;
        }

        if( pivot_index < left || pivot_index > right )
        {
            pivot_index = left;
        }

        auto pivot_value = arr[pivot_index];

        // Move the pivot value to the last index in the current range.

        if( pivot_index != right )
        {
            /* Note that the following line will result in a
             * compile-time error in D1 if 'Elem' is a static array.
             * This is because D1 does not allow assignment to a static
             * array. */

            arr[pivot_index] = arr[right];
            arr[right] = pivot_value;
        }

        auto store_index = left;

        for( auto i = left; i < right; ++i )
        {
            if( pred(arr[i], pivot_value) )
            {
                if( i != store_index )
                {
                    typeid(T).swap(&arr[i], &arr[store_index]);
                }

                ++store_index;
            }
        }

        // Move the pivot value from the last index to its rightful
        // place.

        if( store_index != right )
        {
            arr[right] = arr[store_index];
            arr[store_index] = pivot_value;
        }

        return store_index;
    }

    if( arr.length == 0 )
    {
        throw new Exception("Zero-length arrays are not supported");
    }

    if( arr.length == 1 )
    {
        return arr[0];
    }

    /* The initial pivot index must be a valid array index. */

    if( initial_pivot_index >= arr.length )
    {
        initial_pivot_index = 0;
    }

    /* One cannot have "the fifth largest element in an array" if the
     * array contains only three elements. In such a case, 'k' is set to
     * the largest valid index of the array. */

    if( k >= arr.length )
    {
        k = arr.length - 1;
    }

    /*
     * Important Note:
     * ---------------
     *     This function uses 'left' and 'right' markers to define a
     *     range of elements in the array being searched. At first
     *     glance, this may seem unnecessary as D's slicing operations
     *     could be used to inspect a range of elements in an array.
     *     However, the QuickSelect algorithm works in such a way that
     *     the kth element in the array will move to index 'k' of the
     *     original array at the end of computation. This makes it
     *     necessary for us to maintain the original length of the
     *     array, and not use slices.
     */

    /* The selection process works on a constantly reducing range of
     * elements within the given array, with the search range being
     * halved in each iteration. To begin with, the range is set to the
     * entire array. */

    size_t left = 0;
    size_t right = arr.length - 1;

    size_t pivot_index = initial_pivot_index;

    while( 1 )
    {
        pivot_index = partition(arr, left, right, pivot_index, pred);

        if( pivot_index == k )
        {
            /* The kth element in the array is the current pivot. */

            break;
        }
        else if( pivot_index > k )
        {
            /* The kth element is before the current pivot, so restrict
             * further searching to the first half of the current range
             * by shortening the range from the right. */

            right = pivot_index - 1;
            pivot_index = right;
        }
        else
        {
            /* The kth element is after the current pivot, so restrict
             * further searching to the second half of the current range
             * by shortening the range from the left. */

            left = pivot_index + 1;
            pivot_index = left;
        }
    }

    return arr[pivot_index];
}

version (UnitTest)
{
    void verifySelect ( T, istring file = __FILE__, int line = __LINE__ )
        ( T[] buf, size_t k, T expected_value )
    {
        auto t = new NamedTest(file ~ ":" ~ line.stringof);
        auto kth_element_index = select(buf, k);

        t.test!("<")(kth_element_index, buf.length);
        t.test!("==")(buf[kth_element_index], expected_value);

        /* Confirm that unordered partial sorting of the array has also
         * happened as expected. */

        if( k > buf.length )
            k = buf.length;

        foreach (cur; buf[0 .. k])
            t.test!("<=")(cur, expected_value);

        foreach (cur; buf[k .. $])
            test!(">=")(cur, expected_value);
    }

}

unittest
{
    testThrown!(Exception)(select((int[]).init, 0));

    verifySelect("efedcaabca".dup, 5, 'c');

    verifySelect(['x'], 0, 'x');
    verifySelect([42], 10, 42);

    verifySelect([7, 3, 4, 1, 9], 0, 1);
    verifySelect([7, 3, 4, 1, 9], 1, 3);
    verifySelect([7, 3, 4, 1, 9], 2, 4);
    verifySelect([7, 3, 4, 1, 9], 3, 7);
    verifySelect([7, 3, 4, 1, 9], 4, 9);
    verifySelect([7, 3, 4, 1, 9], 5, 9);

    verifySelect([7.4, 3.57, 4.2, 1.23, 3.56], 1, 3.56);

    struct Person
    {
        istring name;
        int age;
    }

    Person a = Person("Gautam", 18);
    Person b = Person("Tom",    52);
    Person c = Person("George", 53);
    Person d = Person("Arnold", 67);

    bool person_age_predicate( Person p1, Person p2 )
    {
        return p1.age < p2.age;
    }

    Person[] buf = [a, b, c, d];

    auto kth_element_index = select(buf, 0, &person_age_predicate);
    test!("==")(buf[kth_element_index].name, "Gautam");

    kth_element_index = select(buf, 2, &person_age_predicate);
    test!("==")(buf[kth_element_index].name, "George");

    test!("==")(quickselect([7, 3, 4, 1, 9][], 1), 3);

    bool greater_than_predicate( int a, int b )
    {
        return a > b;
    }

    test!("==")(quickselect([7, 3, 4, 1, 9][], 1, &greater_than_predicate), 7);
    test!("==")(quickselect([7, 3, 4, 1][], 1, &greater_than_predicate, 2), 4);
}
