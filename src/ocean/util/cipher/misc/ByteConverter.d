/**
 * This file is part of the dcrypt project.
 *
 * Copyright:
 *     Copyright (C) dcrypt contributors 2009.
 *     Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
 *     All rights reserved.
 *
 * License:
 *     Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
 *     See LICENSE_TANGO.txt for details.
 *
 * Authors: Thomas Dixon
 *
 */

module ocean.util.cipher.misc.ByteConverter;

import ocean.transition;

version ( UnitTest )
{
    import ocean.core.Test;
}

/** Converts between integral types and unsigned byte arrays */
struct ByteConverter
{
    private const istring hexits = "0123456789abcdef";

    /** Conversions between little endian integrals and bytes */
    struct LittleEndian
    {
        /**
         * Converts the supplied array to integral type T
         *
         * Params:
         *     x_ = The supplied array of bytes (ubytes, bytes, chars, whatever)
         *
         * Returns:
         *     A integral of type T created with the supplied bytes placed
         *     in the specified byte order.
         */
        static T to (T) (Const!(void)[] x_)
        {
            auto x = cast(Const!(ubyte)[])x_;

            T result = ((x[0] & 0xff)       |
                       ((x[1] & 0xff) << 8));

            static if (T.sizeof >= int.sizeof)
            {
                result |= ((x[2] & 0xff) << 16) |
                          ((x[3] & 0xff) << 24);
            }

            static if (T.sizeof >= long.sizeof)
            {
                result |= (cast(T)(x[4] & 0xff) << 32) |
                          (cast(T)(x[5] & 0xff) << 40) |
                          (cast(T)(x[6] & 0xff) << 48) |
                          (cast(T)(x[7] & 0xff) << 56);
            }

            return result;
        }

        /**
         * Converts the supplied integral to an array of unsigned bytes.
         *
         * Params:
         *     input = Integral to convert to bytes
         *
         * Returns:
         *     Integral input of type T split into its respective bytes
         *     with the bytes placed in the specified byte order.
         */
        static ubyte[] from (T) (Const!(T) input)
        {
            ubyte[] output = new ubyte[T.sizeof];

            output[0] = cast(ubyte)(input);
            output[1] = cast(ubyte)(input >> 8);

            static if (T.sizeof >= int.sizeof)
            {
                output[2] = cast(ubyte)(input >> 16);
                output[3] = cast(ubyte)(input >> 24);
            }

            static if (T.sizeof >= long.sizeof)
            {
                output[4] = cast(ubyte)(input >> 32);
                output[5] = cast(ubyte)(input >> 40);
                output[6] = cast(ubyte)(input >> 48);
                output[7] = cast(ubyte)(input >> 56);
            }

            return output;
        }
    }

    /** Conversions between big endian integrals and bytes */
    struct BigEndian
    {

        static T to (T) (Const!(void)[] x_)
        {
            auto x = cast(Const!(ubyte)[])x_;

            static if (is(T == ushort) || is(T == short))
            {
                return cast(T) (((x[0] & 0xff) << 8) |
                                 (x[1] & 0xff));
            }
            else static if (is(T == uint) || is(T == int))
            {
                return cast(T) (((x[0] & 0xff) << 24) |
                                ((x[1] & 0xff) << 16) |
                                ((x[2] & 0xff) << 8)  |
                                 (x[3] & 0xff));
            }
            else static if (is(T == ulong) || is(T == long))
            {
                return cast(T) ((cast(T)(x[0] & 0xff) << 56) |
                                (cast(T)(x[1] & 0xff) << 48) |
                                (cast(T)(x[2] & 0xff) << 40) |
                                (cast(T)(x[3] & 0xff) << 32) |
                                ((x[4] & 0xff) << 24) |
                                ((x[5] & 0xff) << 16) |
                                ((x[6] & 0xff) << 8)  |
                                 (x[7] & 0xff));
            }
        }

        static ubyte[] from(T)(T input)
        {
            ubyte[] output = new ubyte[T.sizeof];

            static if (T.sizeof == long.sizeof)
            {
                output[0] = cast(ubyte)(input >> 56);
                output[1] = cast(ubyte)(input >> 48);
                output[2] = cast(ubyte)(input >> 40);
                output[3] = cast(ubyte)(input >> 32);
                output[4] = cast(ubyte)(input >> 24);
                output[5] = cast(ubyte)(input >> 16);
                output[6] = cast(ubyte)(input >> 8);
                output[7] = cast(ubyte)(input);
            }
            else static if (T.sizeof == int.sizeof)
            {
                output[0] = cast(ubyte)(input >> 24);
                output[1] = cast(ubyte)(input >> 16);
                output[2] = cast(ubyte)(input >> 8);
                output[3] = cast(ubyte)(input);
            }
            else static if (T.sizeof == short.sizeof)
            {
                output[0] = cast(ubyte)(input >> 8);
                output[1] = cast(ubyte)(input);
            }

            return output;
        }
    }

    /**
     * Takes an array and converts each byte to its hex representation.
     *
     * Params:
     *     input_ = the array of bytes to represent
     *
     * Returns:
     *     A newed char[] containing the hex digits representing the
     *     input
     */

    static mstring hexEncode(Const!(void)[] input_)
    {
        mstring buffer;

        return(hexEncode(input_, buffer));
    }

    /**
     * Takes an array and converts each byte to its hex representation.
     *
     * Params:
     *     input_ = the array of bytes to represent
     *     output = the buffer into which the results will be written
     *
     * Returns:
     *     A slice of output containing the hex digits representing the
     *     input
     */

    static mstring hexEncode(Const!(void)[] input_, ref mstring output)
    {
        auto input = cast(Const!(ubyte)[])input_;
        // make sure our buffer is big enough (2 hex digits per byte).
        output.length = input.length * 2;

        int i = 0;
        foreach (ubyte j; input)
        {
            output[i++] = hexits[j>>4];
            output[i++] = hexits[j&0xf];
        }

        return output;
    }

    unittest
    {
        mstring buffer;

        test!("==")(hexEncode(cast(ubyte[])([
                        0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef
                    ]), buffer), "0123456789abcdef"[]);
        // check the right amount of memory was allocated
        test!("==")(buffer.length, 16);
    }

    static ubyte[] hexDecode(cstring input)
    {
        cstring inputAsLower = stringToLower(input);
        ubyte[] output = new ubyte[input.length>>1];

        static ubyte[char] hexitIndex;
        for (ubyte i = 0; i < hexits.length; i++)
            hexitIndex[hexits[i]] = i;

        for (int i = 0, j = 0; i < output.length; i++)
        {
            output[i] = cast(ubyte) (hexitIndex[inputAsLower[j++]] << 4);
            output[i] |= hexitIndex[inputAsLower[j++]];
        }

        return output;
    }

    private static mstring stringToLower(cstring input)
    {
        mstring output = new char[input.length];

        foreach (int i, char c; input)
            output[i] = cast(ubyte) ((c >= 'A' && c <= 'Z') ? c+32 : c);

        return output;
    }
}
