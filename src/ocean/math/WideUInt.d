/*******************************************************************************

    Struct emulating a large (bigger than ulong) non-negative integer of fixed
    range (defined via template argument).  `ulong` but still fixed in size
    (defined via template argument).

    Copyright:
        Copyright (c) 2017 sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.math.WideUInt;

import ocean.transition;
import ocean.core.Test;
import ocean.core.Enforce;

import core.stdc.math;
import ocean.math.IEEE : feqrel;

/*******************************************************************************

    Struct emulating a large (bigger than ulong) non-negative integer of fixed
    range (defined via template argument).  `ulong` but still fixed in size
    (defined via template argument).

    Such struct is a value type with stable binary layout for a given size which
    is the primary goal of this implementation. Performance may be eventually
    improved if necessity arises, right now implementation is intentionally
    simplistic and naive.

    Internally wide integer is represented by a static array of `uint` values
    such that concatenating their binary representation together results in long
    binary sequence representing actual stored number.

    Params:
        N = amount of uint-size words to use as a backing storage for the
            number

*******************************************************************************/

public struct WideUInt ( size_t N )
{
    static assert (
        N > 2,
        "For 'N <= 2' using 'uint' or 'ulong' directly is suggested"
    );

    /***************************************************************************

       Binary representation of the number can be formed by putting binary
       representation of each individual word in `payload` side by
       side starting from the `payload[$-1]`.

       `uint` is chosen as individual word type because multiplying two `uint`
       words will result in `ulong` at most, making possible to use basic
       integer arithmetic to implement most of wide integer arithmetic.

    ***************************************************************************/

    private uint[N] payload;

    version (D_Version2)
    {
        /***********************************************************************

            Constructor from a regular ulong

        ***********************************************************************/

        mixin("
        this ( ulong value )
        {
            this.assign(value);
        }
        ");
    }

    /***************************************************************************

        Returns:
            amount of meaningful decimal digits in currently stored value

    ***************************************************************************/

    public size_t decimal_digits ( )
    {
        if ((&this).opEquals(0))
            return 1;

        WideUInt copy = *(&this);

        size_t count;
        while (copy != 0)
        {
            copy.divideBy(10);
            ++count;
        }
        return count;
    }

    unittest
    {
        WideUInt num = 0;
        test!("==")(num.decimal_digits(), 1);

        num = 42;
        test!("==")(num.decimal_digits(), 2);

        num = ulong.max;
        test!("==")(num.decimal_digits(), 20);

        num.multiplyBy(100);
        test!("==")(num.decimal_digits(), 22);
    }

    /***************************************************************************

        Inefficient allocating string conversion useful for tests and
        prototyping.

        Returns:
            string representation

    ***************************************************************************/

    public istring toString ( )
    {
        mstring result;
        (&this).toString((cstring s) { result ~= s; });
        return assumeUnique(result);
    }

    unittest
    {
        WideUInt num = 0;
        test!("==")(num.toString(), "0");

        num = 42;
        test!("==")(num.toString(), "42");

        num.payload[2] = 1;
        test!("==")(num.toString(), "18446744073709551658");

        num = 0;
        num.payload[2] = 1;
        test!("==")(num.toString(), "18446744073709551616");
    }

    /***************************************************************************

        Sink based string conversion

        Params:
            sink = delegate to call with resulting string

    ***************************************************************************/

    public void toString ( scope void delegate (cstring) sink )
    {
        auto n = (&this).decimal_digits();
        static mstring buffer;
        buffer.length = n;
        enableStomping(buffer);

        WideUInt copy = *(&this);
        for (ptrdiff_t idx = n-1; idx >= 0; --idx)
        {
            auto remainder = copy.divideBy(10);
            buffer[idx] = cast(char) ('0' + remainder);
        }

        sink(buffer);
    }

    /***************************************************************************

        Enables assignment from a plain integer type

        Params:
            rhs = value to assign

    ***************************************************************************/

    public void opAssign ( ulong rhs )
    {
        (&this).assign(rhs);
    }

    unittest
    {
        WideUInt i;
        i = 42;
        test!("==")(i.payload[0], 42);
        i = ulong.max;
        test!("==")(i.payload[0], uint.max);
        test!("==")(i.payload[1], uint.max);
    }

    unittest
    {
        WideUInt a = 42;
        WideUInt b = 43;
        a = b;
        test!("==")(a, 43);
    }

    /***************************************************************************

        Enables equality comparison with a plain integer type

        Params:
            rhs = value to compare to

        Returns:
            value as defined by `opEquals` spec

    ***************************************************************************/

    public equals_t opEquals ( ulong rhs )
    {
        if ((&this).payload[0] != (rhs & uint.max))
            return false;

        if ((&this).payload[1] != (rhs >> 32))
            return false;

        foreach (ref word; (&this).payload[2 .. N])
        {
            if (word != 0)
                return false;
        }

        return true;
    }

    unittest
    {
        WideUInt i;

        i = 42;
        test!("==")(i, 42);

        i = ulong.max / 2;
        test!("==")(i, ulong.max / 2);
        test!("!=")(i, ulong.max);

        i.payload[$-1] = 42;
        test!("!=")(i, 42);

        i.payload[0] = 0;
        test!("!=")(i, 42);
    }

    /***************************************************************************

        Enables equality comparison with WideUInt of the same size

        Params:
            rhs = value to compare against

        Returns:
            value as defined by `opEquals` spec

    ***************************************************************************/

    public equals_t opEquals ( WideUInt rhs )
    {
        return (&this).payload[] == rhs.payload[];
    }

    unittest
    {
        WideUInt a, b;
        test!("==")(a, b);
        foreach (size_t i, ref elem; a.payload)
        {
            a.payload[i] = 1337;
            b.payload[i] = 1337;
        }
        test!("==")(a, b);
        a.payload[$-1] = 0;
        test!("!=")(a, b);
    }

    /***************************************************************************

        Enables ordering comparison with WideUInt of the same size

        Params:
            rhs = value to compare against

        Returns:
            value as defined by `opCmp` spec

    ***************************************************************************/

    mixin(genOpCmp("
    {
        ptrdiff_t idx = N-1;
        while (idx > 0)
        {
            if (this.payload[idx] != 0 || rhs.payload[idx] != 0)
                break;
            --idx;
        }

        auto a = this.payload[idx];
        auto b = rhs.payload[idx];
        return a < b ? -1 : (a > b ? 1 : 0);
    }
    "));

    unittest
    {
        WideUInt num1, num2;
        num1.payload[1] = 1;
        num2.payload[2] = 1;
        test(num1 < num2);
        test(num2 > num1);
    }

    /***************************************************************************

        Increment current value by one fitting in uint

        Params:
            rhs = value to increment with. Limited to `uint` for now to simplify
                internal arithmetic.

        Throws:
            WideUIntRangeException if this WideUInt value range was to be
            exceeded

    ***************************************************************************/

    public void opAddAssign ( uint rhs )
    {
        if (add((&this).payload[0], rhs))
            enforce(.wideint_exception, (&this).checkAndInc(1));
    }

    unittest
    {
        WideUInt num = 0;
        for (auto i = 0; i < 1000; ++i)
            num += (1 << 31);
        test!("==")(num.payload[0], 0);
        test!("==")(num.payload[1], 500);
    }

    /***************************************************************************

        Mutates current number in-place, dividing it by `rhs` and calculating
        remainder.

        Params:
            rhs = number to divide by

        Returns:
            remainder of division

    ***************************************************************************/

    public uint divideBy ( uint rhs )
    out (remainder)
    {
        assert(remainder < rhs);
    }
    body
    {
        ulong remainder = 0;

        for (ptrdiff_t idx = (&this).payload.length - 1; idx >= 0; --idx)
        {
            remainder = (remainder << 32) + (&this).payload[idx];
            ulong result = remainder / rhs;
            remainder -= rhs * result;
            assert(result <= uint.max);
            (&this).payload[idx] = cast(uint) result;
        }

        assert(remainder <= uint.max);
        return cast(uint) remainder;
    }

    unittest
    {
        WideUInt num = 56 * 47;
        test!("==")(0, num.divideBy(47));
        test!("==")(num.payload[0], 56);

        num.payload[0] = 1337;
        num.payload[1] = 100;
        test!("==")(1337, num.divideBy(1 << 31));
        test!("==")(num.payload[0], 200);
    }

    /***************************************************************************

        Mutates this number in place multiplying it by a regular integer

        Params:
            rhs = value to multiply by

        Throws:
            WideUIntRangeException if resulting value can't fit in current
            WideUInt value range

    ***************************************************************************/

    public void multiplyBy ( uint rhs )
    {
        ulong overflow = 0;

        for (size_t i = 0; i < (&this).payload.length; ++i)
        {
            overflow += cast(ulong)((&this).payload[i]) * rhs;
            (&this).payload[i] = cast(uint) (overflow & uint.max);
            overflow >>= 32;
        }

        enforce(.wideint_exception, overflow == 0);
    }

    unittest
    {
        WideUInt num = 1_000_000_000;
        num.multiplyBy(1_000_000_000);
        test!("==")(num.toString(), "1000000000000000000");
    }

    /***************************************************************************

        Returns:
            Double precision floating point value which is nearest to this
            number.  Uses the same semantics as conversion from ulong to double.

    ***************************************************************************/

    public double toDouble ( )
    {
        // find most significant word with non-zero value
        int idx = (&this).payload.length-1;
        while ((&this).payload[idx] == 0 && idx > 0)
            --idx;

        // if stored value <= ulong.max, just use plain cast
        if (idx < 2)
        {
            ulong value = (&this).payload[1];
            value <<= 32;
            value |= (&this).payload[0];
            return cast(double) value;
        }

        // else calculate floating point value from 3 most significant words
        double MAXWORD = pow(2.0, 32.0);
        return (((&this).payload[idx] * MAXWORD + (&this).payload[idx-1])
                * MAXWORD + (&this).payload[idx-2])
            * ldexp(1.0, (idx-2)*32);
    }

    unittest
    {
        WideUInt num = 123456789;
        test!("is")(num.toDouble(), 123_456_789.0);

        for (int i = 0; i < 3; ++i)
            num.multiplyBy(1_000_000_000);

        test(feqrel(num.toDouble(), 123_456_789e+27) == double.mant_dig);
    }

    /***************************************************************************

        Helper utility to increment word under index `idx`, calling itself
        recursively for following words if wraparound happens.

        Params:
            idx = index of word in the internal payload to increment by 1

        Returns:
            'false' if whole WideUInt has overflown (== error)

    ***************************************************************************/

    private bool checkAndInc ( size_t idx )
    {
        if (idx >= N)
            return false;

        uint after = ++(&this).payload[idx];
        if (after == 0)
            return (&this).checkAndInc(idx+1);

        return true;
    }

    unittest
    {
        WideUInt num = uint.max;
        test(num.checkAndInc(0));
        test(num.payload[0] == 0);
        test(num.payload[1] == 1);

        num.payload[$-1] = uint.max;
        test(!num.checkAndInc(num.payload.length - 1));
    }

    /***************************************************************************

        Trivial helper to initialize to least significant words of the number
        from ulong.

    ***************************************************************************/

    private void assign ( ulong value )
    {
        (&this).payload[] = 0;
        (&this).payload[0] = cast(uint) value;
        (&this).payload[1] = cast(uint) (value >> 32);
    }

    /***************************************************************************

        Helper utility that adds two uint integers checking for wraparound

        Params:
            a = reference to integer to increment
            b = number to add

        Returns:
            'true' if wraparound/overflow has happenned, 'false' otherwise

    ***************************************************************************/

    static private bool add ( ref uint a, uint b )
    {
        bool flag;

        version (D_InlineAsm_X86_64)
        {
            asm
            {
                add   dword ptr [RSI], EDI;
                setb  flag;
            }
        }
        else
        {
            uint result = a + b;
            flag = result < a;
            a = result;
        }

        return flag;
    }

    unittest
    {
        uint a = uint.max;
        test( add(a, 1));
        test!("==")(a, 0);

        a = 1000;
        test(!add(a, 1337));
        test!("==")(a, 2337UL);

        a = 0;
        test(!add(a, uint.max));
        test!("==")(a, uint.max);
    }
}

///
unittest
{
    WideUInt!(4) counter;
    counter = 10000000000000000000U;
    counter.multiplyBy(10);
    ++counter;
    test!("==")(counter.toString(), "100000000000000000001");
}

unittest
{
    WideUInt!(4) num = ulong.max;
    test!("==")(num.toString(), "18446744073709551615");
    num.multiplyBy(2);
    test!("==")(num.toString(), "36893488147419103230");
    num.divideBy(2);
    test!("==")(num.toString(), "18446744073709551615");

    num = 0;
    num.payload[2] = 1; // ulong.max + 1
    test!("==")(num.toString(), "18446744073709551616");
}

/*******************************************************************************

    Exception of this class is thrown when WideUInt overflow is about to happen

*******************************************************************************/

public class WideUIntRangeException : Exception
{
    import ocean.core.Exception : DefaultExceptionCtor;
    mixin DefaultExceptionCtor;
}

// shared between different WideUInt!(N) instances
private static WideUIntRangeException wideint_exception;

static this ( )
{
    wideint_exception = new WideUIntRangeException(
        "Operation would result in WideUInt overflow");
}
