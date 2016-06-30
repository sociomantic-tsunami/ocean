/**
 * This module contains a collection of bit-level operations.
 *
 * Copyright:
 *     Public Domain
 *     Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
 *     All rights reserved.
 *
 * License:
 *     Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
 *     See LICENSE_TANGO.txt for details.
 *
 * Authors: Sean Kelly
 *
 */
module ocean.core.BitManip;

public import core.bitop;

/**
 * Reverses the order of bits in a 64-bit integer.
 */
ulong bitswap ( ulong x )
{
    version( D_InlineAsm_X86_64 )
    {
        asm
        {
            // Author: Tiago Gasiba.
            mov RAX, x;
            mov RDX, RAX;
            shr RAX, 1;
            mov RCX, 0x5555_5555_5555_5555L;
            and RDX, RCX;
            and RAX, RCX;
            shl RDX, 1;
            or  RAX, RDX;

            mov RDX, RAX;
            shr RAX, 2;
            mov RCX, 0x3333_3333_3333_3333L;
            and RDX, RCX;
            and RAX, RCX;
            shl RDX, 2;
            or  RAX, RDX;

            mov RDX, RAX;
            shr RAX, 4;
            mov RCX, 0x0f0f_0f0f_0f0f_0f0fL;
            and RDX, RCX;
            and RAX, RCX;
            shl RDX, 4;
            or  RAX, RDX;
            bswap RAX;
        }
    }
    else
    {
        // swap odd and even bits
        x = ((x >> 1) & 0x5555_5555_5555_5555L) | ((x & 0x5555_5555_5555_5555L) << 1);
        // swap consecutive pairs
        x = ((x >> 2) & 0x3333_3333_3333_3333L) | ((x & 0x3333_3333_3333_3333L) << 2);
        // swap nibbles
        x = ((x >> 4) & 0x0f0f_0f0f_0f0f_0f0fL) | ((x & 0x0f0f_0f0f_0f0f_0f0fL) << 4);
        // swap bytes
        x = ((x >> 8) & 0x00FF_00FF_00FF_00FFL) | ((x & 0x00FF_00FF_00FF_00FFL) << 8);
        // swap shorts
        x = ((x >> 16) & 0x0000_FFFF_0000_FFFFL) | ((x & 0x0000_FFFF_0000_FFFFL) << 16);
        // swap ints
        x = ( x >> 32              ) | ( x               << 32);
        return x;
    }
}

unittest
{
    assert( bitswap( 0b1000000000000000000000010000000000000000100000000000000000000001 )
            == 0b1000000000000000000000010000000000000000100000000000000000000001 );
    assert( bitswap( 0b1110000000000000000000010000000000000000100000000000000000000001 )
            == 0b1000000000000000000000010000000000000000100000000000000000000111 );
}
