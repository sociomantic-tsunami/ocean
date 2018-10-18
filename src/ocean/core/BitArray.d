/**
 * This module contains a packed bit array implementation in the style of D's
 * built-in dynamic arrays.
 *
 * Copyright:
 *     Copyright (C) 2005-2006 Digital Mars, www.digitalmars.com.
 *     Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
 *     All rights reserved.
 *
 * License:
 *     Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
 *     See LICENSE_TANGO.txt for details.
 *
 * Authors: Walter Bright, Sean Kelly
 *
 */
module ocean.core.BitArray;

import ocean.transition;

import ocean.core.BitManip;
import ocean.core.Verify;

version(UnitTest) import ocean.core.Test;

/**
 * This struct represents an array of boolean values, each of which occupy one
 * bit of memory for storage.  Thus an array of 32 bits would occupy the same
 * space as one integer value.  The typical array operations--such as indexing
 * and sorting--are supported, as well as bitwise operations such as and, or,
 * xor, and complement.
 */
struct BitArray
{
    size_t  len;
    uint*   ptr;


    /**
     * This initializes a BitArray of bits.length bits, where each bit value
     * matches the corresponding boolean value in bits.
     *
     * Params:
     *  bits = The initialization value.
     *
     * Returns:
     *  A BitArray with the same number and sequence of elements as bits.
     */
    static BitArray opCall( bool[] bits )
    {
        BitArray temp;

        temp.length = bits.length;
        foreach( pos, val; bits )
            temp[pos] = val;
        return temp;
    }

    /**
     * Get the number of bits in this array.
     *
     * Returns:
     *  The number of bits in this array.
     */
    size_t length()
    {
        return len;
    }


    /**
     * Resizes this array to newlen bits.  If newlen is larger than the current
     * length, the new bits will be initialized to zero.
     *
     * Params:
     *  newlen = The number of bits this array should contain.
     */
    void length( size_t newlen )
    {
        if( newlen != len )
        {
            auto olddim = dim();
            auto newdim = (newlen + 31) / 32;

            if( newdim != olddim )
            {
                // Create a fake array so we can use D's realloc machinery
                uint[] buf = ptr[0 .. olddim];

                buf.length = newdim; // realloc
                enableStomping(buf);

                ptr = buf.ptr;
            }

            if( auto pad_bits = (newlen & 31) )
            {
                // Set any pad bits to 0
                ptr[newdim - 1] &= ~(~0 << pad_bits);
            }

            len = newlen;
        }
    }


    /**
     * Gets the length of a uint array large enough to hold all stored bits.
     *
     * Returns:
     *  The size a uint array would have to be to store this array.
     */
    size_t dim()
    {
        return (len + 31) / 32;
    }


    /**
     * Duplicates this array, much like the dup property for built-in arrays.
     *
     * Returns:
     *  A duplicate of this array.
     */
    BitArray dup()
    {
        BitArray ba;

        uint[] buf = ptr[0 .. dim].dup;
        ba.len = len;
        ba.ptr = buf.ptr;
        return ba;
    }


    unittest
    {
        BitArray a;
        BitArray b;

        a.length = 3;
        a[0] = 1; a[1] = 0; a[2] = 1;
        b = a.dup;
        test( b.length == 3 );
        for( int i = 0; i < 3; ++i )
        {
            test( b[i] == (((i ^ 1) & 1) ? true : false) );
        }
    }

    /**
     * Resets the length of this array to bits.length and then initializes this
     *
     * Resizes this array to hold bits.length bits and initializes each bit
     * value to match the corresponding boolean value in bits.
     *
     * Params:
     *  bits = The initialization value.
     */
    void opAssign( bool[] bits )
    {
        length = bits.length;
        foreach( i, b; bits )
        {
            (*(&this))[i] = b;
        }
    }

    /**
     * Copy the bits from one array into this array.  This is not a shallow
     * copy.
     *
     * Params:
     *  rhs = A BitArray with the same number of bits as this bit array.
     *
     * Returns:
     *  A shallow copy of this array.
     *
     *  --------------------
     *  BitArray ba = [0,1,0,1,0];
     *  BitArray ba2;
     *  ba2.length = ba.length;
     *  ba2[] = ba; // perform the copy
     *  ba[0] = true;
     *  assert(ba2[0] == false);
     *  -------------------
     */
    BitArray opSliceAssign(BitArray rhs)
    {
        verify(rhs.len == len);

        auto dimension = (&this).dim();
        (&this).ptr[0..dimension] = rhs.ptr[0..dimension];
        return *(&this);
    }


    /**
     * Map BitArray onto target, with numbits being the number of bits in the
     * array. Does not copy the data.  This is the inverse of opCast.
     *
     * Params:
     *  target  = The array to map.
     *  numbits = The number of bits to map in target.
     */
    void init( void[] target, size_t numbits )
    {
        verify(numbits <= target.length * 8);
        verify((target.length & 3) == 0);

        ptr = cast(uint*)target.ptr;
        len = numbits;
    }


    unittest
    {
        BitArray a = [1,0,1,0,1];
        BitArray b;
        void[] buf;

        buf = cast(void[])a;
        b.init( buf, a.length );

        test( b[0] == 1 );
        test( b[1] == 0 );
        test( b[2] == 1 );
        test( b[3] == 0 );
        test( b[4] == 1 );

        a[0] = 0;
        test( b[0] == 0 );

        test( a == b );

        // test opSliceAssign
        BitArray c;
        c.length = a.length;
        c[] = a;
        test( c == a );
        a[0] = 1;
        test( c != a );
    }

    /**
     * Reverses the contents of this array in place, much like the reverse
     * property for built-in arrays.
     *
     * Returns:
     *  A shallow copy of this array.
     */
    BitArray reverse()
    out( result )
    {
        assert(compare(result, *(&this)));
    }
    body
    {
        if( len >= 2 )
        {
            bool t;
            size_t lo, hi;

            lo = 0;
            hi = len - 1;
            for( ; lo < hi; ++lo, --hi )
            {
                t = (*(&this))[lo];
                (*(&this))[lo] = (*(&this))[hi];
                (*(&this))[hi] = t;
            }
        }
        return *(&this);
    }


    unittest
    {
        static bool[5] data = [1,0,1,1,0];
        BitArray b = data;
        b.reverse;

        for( size_t i = 0; i < data.length; ++i )
        {
            test( b[i] == data[4 - i] );
        }
    }

    /**
     * Sorts this array in place, with zero entries sorting before one.  This
     * is equivalent to the sort property for built-in arrays.
     *
     * Returns:
     *  A shallow copy of this array.
     */
    BitArray sort()
    out( result )
    {
        assert(compare(result, *(&this)));
    }
    body
    {
        if( len >= 2 )
        {
            size_t lo, hi;

            lo = 0;
            hi = len - 1;
            while( true )
            {
                while( true )
                {
                    if( lo >= hi )
                        goto Ldone;
                    if( (*(&this))[lo] == true )
                        break;
                    ++lo;
                }

                while( true )
                {
                    if( lo >= hi )
                        goto Ldone;
                    if( (*(&this))[hi] == false )
                        break;
                    --hi;
                }

                (*(&this))[lo] = false;
                (*(&this))[hi] = true;

                ++lo;
                --hi;
            }
            Ldone:
            ;
        }
        return *(&this);
    }


    unittest
    {
        uint x = 0b1100011000;
        BitArray ba = { 10, &x };

        ba.sort;
        for( size_t i = 0; i < 6; ++i )
            test( ba[i] == false );
        for( size_t i = 6; i < 10; ++i )
            test( ba[i] == true );
    }

    /**
     * Operates on all bits in this array.
     *
     * Params:
     *  dg = The supplied code as a delegate.
     */
    int opApply( scope int delegate(ref bool) dg )
    {
        int result;

        for( size_t i = 0; i < len; ++i )
        {
            bool b = opIndex( i );
            result = dg( b );
            opIndexAssign( b, i );
            if( result )
                break;
        }
        return result;
    }


    /** ditto */
    int opApply( scope int delegate(ref size_t, ref bool) dg )
    {
        int result;

        for( size_t i = 0; i < len; ++i )
        {
            bool b = opIndex( i );
            result = dg( i, b );
            opIndexAssign( b, i );
            if( result )
                break;
        }
        return result;
    }


    unittest
    {
        BitArray a = [1,0,1];

        int i;
        foreach( b; a )
        {
            switch( i )
            {
                case 0: test( b == true );  break;
                case 1: test( b == false ); break;
                case 2: test( b == true );  break;
                default: test( false );
            }
            i++;
        }

        foreach( j, b; a )
        {
            switch( j )
            {
                case 0: test( b == true );  break;
                case 1: test( b == false ); break;
                case 2: test( b == true );  break;
                default: test( false );
            }
        }
    }

    /**
     * Compares this array to another for equality.  Two bit arrays are equal
     * if they are the same size and contain the same series of bits.
     *
     * Params:
     *  rhs = The array to compare against.
     *
     * Returns:
     *  Zero if not equal and non-zero otherwise.
     */
    int opEquals( BitArray rhs )
    {
        return compare(*(&this), rhs);
    }

    // FIXME_IN_D2: allows comparing both mutable
    // and immutable BitArray without actually defining
    // bunch of const methods

    static private int compare(in BitArray lhs_,
        in BitArray rhs_ )
    {
        // requirement for const methods propagates
        // transitively, avoid it by casting const away
        auto lhs = cast(BitArray*) &lhs_;
        auto rhs = cast(BitArray*) &rhs_;

        if( lhs.length != rhs.length )
            return 0; // not equal
        auto p1 = lhs.ptr;
        auto p2 = rhs.ptr;
        size_t n = lhs.length / 32;
        size_t i;
        for( i = 0; i < n; ++i )
        {
            if( p1[i] != p2[i] )
            return 0; // not equal
        }
        int rest = cast(int)(lhs.length & cast(size_t)31u);
        uint mask = ~((~0u)<<rest);
        return (rest == 0) || (p1[i] & mask) == (p2[i] & mask);
    }

    unittest
    {
        BitArray a = [1,0,1,0,1];
        BitArray b = [1,0,1];
        BitArray c = [1,0,1,0,1,0,1];
        BitArray d = [1,0,1,1,1];
        BitArray e = [1,0,1,0,1];

        test(a != b);
        test(a != c);
        test(a != d);
        test(a == e);
    }

    /**
     * Performs a lexicographical comparison of this array to the supplied
     * array.
     *
     * Params:
     *  rhs = The array to compare against.
     *
     * Returns:
     *  A value less than zero if this array sorts before the supplied array,
     *  zero if the arrays are equavalent, and a value greater than zero if
     *  this array sorts after the supplied array.
     */
    int opCmp( BitArray rhs )
    {
        auto len = (&this).length;
        if( rhs.length < len )
            len = rhs.length;
        uint* p1 = (&this).ptr;
        uint* p2 = rhs.ptr;
        size_t n = len / 32;
        size_t i;
        for( i = 0; i < n; ++i )
        {
            if( p1[i] != p2[i] ){
                return ((p1[i] < p2[i])?-1:1);
            }
        }
        int rest=cast(int)(len & cast(size_t) 31u);
        if (rest>0) {
            uint mask=~((~0u)<<rest);
            uint v1=p1[i] & mask;
            uint v2=p2[i] & mask;
            if (v1 != v2) return ((v1<v2)?-1:1);
        }
        return (((&this).length<rhs.length)?-1:(((&this).length==rhs.length)?0:1));
    }

    unittest
    {
        BitArray a = [1,0,1,0,1];
        BitArray b = [1,0,1];
        BitArray c = [1,0,1,0,1,0,1];
        BitArray d = [1,0,1,1,1];
        BitArray e = [1,0,1,0,1];
        BitArray f = [1,0,1,0];

        test( a >  b );
        test( a >= b );
        test( a <  c );
        test( a <= c );
        test( a <  d );
        test( a <= d );
        test( a == e );
        test( a <= e );
        test( a >= e );
        test( f >  b );
    }

    /**
     * Convert this array to a void array.
     *
     * Returns:
     *  This array represented as a void array.
     */
    void[] opCast()
    {
        return cast(void[])ptr[0 .. dim];
    }


    unittest
    {
        BitArray a = [1,0,1,0,1];
        void[] v = cast(void[])a;

        test( v.length == a.dim * uint.sizeof );
    }

    /**
     * Support for index operations, much like the behavior of built-in arrays.
     *
     * Params:
     *  pos = The desired index position.
     *
     * In:
     *  pos must be less than the length of this array.
     *
     * Returns:
     *  The value of the bit at pos.
     */
    bool opIndex( size_t pos )
    {
        verify(pos < len);
        return cast(bool)bt( cast(size_t*)ptr, pos );
    }


    /**
     * Generates a copy of this array with the unary complement operation
     * applied.
     *
     * Returns:
     *  A new array which is the complement of this array.
     */
    BitArray opCom()
    {
        auto dim = (&this).dim();

        BitArray result;

        result.length = len;
        for( size_t i = 0; i < dim; ++i )
            result.ptr[i] = ~(&this).ptr[i];
        if( len & 31 )
            result.ptr[dim - 1] &= ~(~0 << (len & 31));
        return result;
    }


    unittest
    {
        BitArray a = [1,0,1,0,1];
        BitArray b = ~a;

        test(b[0] == 0);
        test(b[1] == 1);
        test(b[2] == 0);
        test(b[3] == 1);
        test(b[4] == 0);
    }

    /**
     * Generates a new array which is the result of a bitwise and operation
     * between this array and the supplied array.
     *
     * Params:
     *  rhs = The array with which to perform the bitwise and operation.
     *
     * In:
     *  rhs.length must equal the length of this array.
     *
     * Returns:
     *  A new array which is the result of a bitwise and with this array and
     *  the supplied array.
     */
    BitArray opAnd( BitArray rhs )
    {
        verify(len == rhs.length);

        auto dim = (&this).dim();

        BitArray result;

        result.length = len;
        for( size_t i = 0; i < dim; ++i )
            result.ptr[i] = (&this).ptr[i] & rhs.ptr[i];
        return result;
    }


    unittest
    {
        BitArray a = [1,0,1,0,1];
        BitArray b = [1,0,1,1,0];

        BitArray c = a & b;

        test(c[0] == 1);
        test(c[1] == 0);
        test(c[2] == 1);
        test(c[3] == 0);
        test(c[4] == 0);
    }

    /**
     * Generates a new array which is the result of a bitwise or operation
     * between this array and the supplied array.
     *
     * Params:
     *  rhs = The array with which to perform the bitwise or operation.
     *
     * In:
     *  rhs.length must equal the length of this array.
     *
     * Returns:
     *  A new array which is the result of a bitwise or with this array and
     *  the supplied array.
     */
    BitArray opOr( BitArray rhs )
    {
        verify(len == rhs.length);

        auto dim = (&this).dim();

        BitArray result;

        result.length = len;
        for( size_t i = 0; i < dim; ++i )
            result.ptr[i] = (&this).ptr[i] | rhs.ptr[i];
        return result;
    }


    unittest
    {
        BitArray a = [1,0,1,0,1];
        BitArray b = [1,0,1,1,0];

        BitArray c = a | b;

        test(c[0] == 1);
        test(c[1] == 0);
        test(c[2] == 1);
        test(c[3] == 1);
        test(c[4] == 1);
    }

    /**
     * Generates a new array which is the result of a bitwise xor operation
     * between this array and the supplied array.
     *
     * Params:
     *  rhs = The array with which to perform the bitwise xor operation.
     *
     * In:
     *  rhs.length must equal the length of this array.
     *
     * Returns:
     *  A new array which is the result of a bitwise xor with this array and
     *  the supplied array.
     */
    BitArray opXor( BitArray rhs )
    {
        verify(len == rhs.length);

        auto dim = (&this).dim();

        BitArray result;

        result.length = len;
        for( size_t i = 0; i < dim; ++i )
            result.ptr[i] = (&this).ptr[i] ^ rhs.ptr[i];
        return result;
    }

    unittest
    {
        BitArray a = [1,0,1,0,1];
        BitArray b = [1,0,1,1,0];

        BitArray c = a ^ b;

        test(c[0] == 0);
        test(c[1] == 0);
        test(c[2] == 0);
        test(c[3] == 1);
        test(c[4] == 1);
    }

    /**
     * Generates a new array which is the result of this array minus the
     * supplied array.  $(I a - b) for BitArrays means the same thing as
     * $(I a &amp; ~b).
     *
     * Params:
     *  rhs = The array with which to perform the subtraction operation.
     *
     * In:
     *  rhs.length must equal the length of this array.
     *
     * Returns:
     *  A new array which is the result of this array minus the supplied array.
     */
    BitArray opSub( BitArray rhs )
    {
        verify(len == rhs.length);

        auto dim = (&this).dim();

        BitArray result;

        result.length = len;
        for( size_t i = 0; i < dim; ++i )
            result.ptr[i] = (&this).ptr[i] & ~rhs.ptr[i];
        return result;
    }

    unittest
    {
        BitArray a = [1,0,1,0,1];
        BitArray b = [1,0,1,1,0];

        BitArray c = a - b;

        test( c[0] == 0 );
        test( c[1] == 0 );
        test( c[2] == 0 );
        test( c[3] == 0 );
        test( c[4] == 1 );
    }

    /**
     * Generates a new array which is the result of this array concatenated
     * with the supplied array.
     *
     * Params:
     *  rhs = The array with which to perform the concatenation operation.
     *
     * Returns:
     *  A new array which is the result of this array concatenated with the
     *  supplied array.
     */
    BitArray opCat( bool rhs )
    {
        BitArray result;

        result = (&this).dup;
        result.length = len + 1;
        result[len] = rhs;
        return result;
    }


    /** ditto */
    BitArray opCat_r( bool lhs )
    {
        BitArray result;

        result.length = len + 1;
        result[0] = lhs;
        for( size_t i = 0; i < len; ++i )
            result[1 + i] = (*(&this))[i];
        return result;
    }


    /** ditto */
    BitArray opCat( BitArray rhs )
    {
        BitArray result;

        result = (&this).dup();
        result ~= rhs;
        return result;
    }

    unittest
    {
        BitArray a = [1,0];
        BitArray b = [0,1,0];
        BitArray c;

        c = (a ~ b);
        test( c.length == 5 );
        test( c[0] == 1 );
        test( c[1] == 0 );
        test( c[2] == 0 );
        test( c[3] == 1 );
        test( c[4] == 0 );

        c = (a ~ true);
        test( c.length == 3 );
        test( c[0] == 1 );
        test( c[1] == 0 );
        test( c[2] == 1 );

        c = (false ~ a);
        test( c.length == 3 );
        test( c[0] == 0 );
        test( c[1] == 1 );
        test( c[2] == 0 );
    }

    /**
     * Support for index operations, much like the behavior of built-in arrays.
     *
     * Params:
     *  b   = The new bit value to set.
     *  pos = The desired index position.
     *
     * In:
     *  pos must be less than the length of this array.
     *
     * Returns:
     *  The new value of the bit at pos.
     */
    bool opIndexAssign( bool b, size_t pos )
    {
        verify(pos < len);

        if( b )
            bts( cast(size_t*)ptr, pos );
        else
            btr( cast(size_t*)ptr, pos );
        return b;
    }


    /**
     * Updates the contents of this array with the result of a bitwise and
     * operation between this array and the supplied array.
     *
     * Params:
     *  rhs = The array with which to perform the bitwise and operation.
     *
     * In:
     *  rhs.length must equal the length of this array.
     *
     * Returns:
     *  A shallow copy of this array.
     */
    BitArray opAndAssign( BitArray rhs )
    {
        verify(len == rhs.length);

        auto dim = (&this).dim();

        for( size_t i = 0; i < dim; ++i )
            ptr[i] &= rhs.ptr[i];
        return *(&this);
    }

    unittest
    {
        BitArray a = [1,0,1,0,1];
        BitArray b = [1,0,1,1,0];

        a &= b;
        test( a[0] == 1 );
        test( a[1] == 0 );
        test( a[2] == 1 );
        test( a[3] == 0 );
        test( a[4] == 0 );
    }

    /**
     * Updates the contents of this array with the result of a bitwise or
     * operation between this array and the supplied array.
     *
     * Params:
     *  rhs = The array with which to perform the bitwise or operation.
     *
     * In:
     *  rhs.length must equal the length of this array.
     *
     * Returns:
     *  A shallow copy of this array.
     */
    BitArray opOrAssign( BitArray rhs )
    {
        verify(len == rhs.length);

        auto dim = (&this).dim();

        for( size_t i = 0; i < dim; ++i )
            ptr[i] |= rhs.ptr[i];
        return *(&this);
    }


    unittest
    {
        BitArray a = [1,0,1,0,1];
        BitArray b = [1,0,1,1,0];

        a |= b;
        test( a[0] == 1 );
        test( a[1] == 0 );
        test( a[2] == 1 );
        test( a[3] == 1 );
        test( a[4] == 1 );
    }

    /**
     * Updates the contents of this array with the result of a bitwise xor
     * operation between this array and the supplied array.
     *
     * Params:
     *  rhs = The array with which to perform the bitwise xor operation.
     *
     * In:
     *  rhs.length must equal the length of this array.
     *
     * Returns:
     *  A shallow copy of this array.
     */
    BitArray opXorAssign( BitArray rhs )
    {
        verify(len == rhs.length);

        auto dim = (&this).dim();

        for( size_t i = 0; i < dim; ++i )
            ptr[i] ^= rhs.ptr[i];
        return *(&this);
    }

    unittest
    {
        BitArray a = [1,0,1,0,1];
        BitArray b = [1,0,1,1,0];

        a ^= b;
        test( a[0] == 0 );
        test( a[1] == 0 );
        test( a[2] == 0 );
        test( a[3] == 1 );
        test( a[4] == 1 );
    }

    /**
     * Updates the contents of this array with the result of this array minus
     * the supplied array.  $(I a - b) for BitArrays means the same thing as
     * $(I a &amp; ~b).
     *
     * Params:
     *  rhs = The array with which to perform the subtraction operation.
     *
     * In:
     *  rhs.length must equal the length of this array.
     *
     * Returns:
     *  A shallow copy of this array.
     */
    BitArray opSubAssign( BitArray rhs )
    {
        verify(len == rhs.length);

        auto dim = (&this).dim();

        for( size_t i = 0; i < dim; ++i )
            ptr[i] &= ~rhs.ptr[i];
        return *(&this);
    }

    unittest
    {
        BitArray a = [1,0,1,0,1];
        BitArray b = [1,0,1,1,0];

        a -= b;
        test( a[0] == 0 );
        test( a[1] == 0 );
        test( a[2] == 0 );
        test( a[3] == 0 );
        test( a[4] == 1 );
    }

    /**
     * Updates the contents of this array with the result of this array
     * concatenated with the supplied array.
     *
     * Params:
     *  rhs = The array with which to perform the concatenation operation.
     *
     * Returns:
     *  A shallow copy of this array.
     */
    BitArray opCatAssign( bool b )
    {
        length = len + 1;
        (*(&this))[len - 1] = b;
        return *(&this);
    }

    unittest
    {
        BitArray a = [1,0,1,0,1];
        BitArray b;

        b = (a ~= true);
        test( a[0] == 1 );
        test( a[1] == 0 );
        test( a[2] == 1 );
        test( a[3] == 0 );
        test( a[4] == 1 );
        test( a[5] == 1 );

        test( b == a );
    }

    /** ditto */
    BitArray opCatAssign( BitArray rhs )
    {
        auto istart = len;
        length = len + rhs.length;
        for( auto i = istart; i < len; ++i )
            (*(&this))[i] = rhs[i - istart];
        return *(&this);
    }

    unittest
    {
        BitArray a = [1,0];
        BitArray b = [0,1,0];
        BitArray c;

        c = (a ~= b);
        test( a.length == 5 );
        test( a[0] == 1 );
        test( a[1] == 0 );
        test( a[2] == 0 );
        test( a[3] == 1 );
        test( a[4] == 0 );

        test( c == a );
    }
}

version (UnitTest)
{
    import ocean.core.Test : NamedTest;
}

unittest
{
    auto t = new NamedTest("Test increase and decrease length of the BitArray");

    static immutable size_of_uint = uint.sizeof * 8;
    static immutable num_bits = (size_of_uint * 5) + 15;

    // Creates a BitArray and sets all the bits.
    scope bool_array = new bool[num_bits];
    bool_array[] = true;

    BitArray bit_array;
    bit_array = bool_array;

    // Self-verification of the BitArray.
    test(bit_array.length == bool_array.length);
    foreach (bit; bit_array)
        t.test!("==")(bit, true);

    // Increases the length of the BitArray and checks the former bits remain
    // set and the new ones are not.
    static immutable greater_length = size_of_uint * 7;
    static assert(greater_length > num_bits);
    bit_array.length = greater_length;
    foreach (pos, bit; bit_array)
    {
        if (pos < num_bits)
            t.test!("==")(bit, true);
        else
            t.test!("==")(bit, false);
    }

    // Decreases the length of the BitArray to a shorter length than the
    // initial one and checks all bits remain set.
    static immutable lower_length = size_of_uint * 5;
    static assert(lower_length < num_bits);
    bit_array.length = lower_length;
    foreach (bit; bit_array)
        t.test!("==")(bit, true);

    // Resizes back to the initial length of the BitArray to check the bits
    // reassigned after decreasing the length of the BitArray are not set.
    bit_array.length = num_bits;
    foreach (pos, bit; bit_array)
    {
        if (pos < lower_length)
            t.test!("==")(bit, true);
        else
            t.test!("==")(bit, false);
    }

    // Checks the bits are reset to zero resizing the BitArray without changing
    // its dimension (the BitArray is large enough to hold the new length).
    bit_array = [true, true, true, true];

    bit_array.length = 2;
    t.test!("==")(bit_array[0], true);
    t.test!("==")(bit_array[1], true);

    bit_array.length = 4;
    t.test!("==")(bit_array[0], true);
    t.test!("==")(bit_array[1], true);
    t.test!("==")(bit_array[2], false);
    t.test!("==")(bit_array[3], false);
}
