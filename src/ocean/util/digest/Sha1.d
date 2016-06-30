/*******************************************************************************

        This module implements the SHA-1 Algorithm described by Secure Hash
        Standard, FIPS PUB 180-1, and RFC 3174 US Secure Hash Algorithm 1
        (SHA1). D. Eastlake 3rd, P. Jones. September 2001.

        Copyright:
            Copyright (c) 2006 Tango contributors.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: Feb 2006

        Authors: Regan Heath, Oskar Linde

*******************************************************************************/

module ocean.util.digest.Sha1;

import ocean.transition;

import ocean.util.digest.Sha01;

public  import ocean.util.digest.Digest;

/*******************************************************************************

*******************************************************************************/

final class Sha1 : Sha01
{
        /***********************************************************************

                Construct a Sha1 hash algorithm context

        ***********************************************************************/

        this() { }

        /***********************************************************************

                Performs the cipher on a block of data

                Params:
                input = the block of data to cipher

                Remarks:
                The actual cipher algorithm is carried out by this method on
                the passed block of data. This method is called for every
                blockSize() bytes of input data and once more with the remaining
                data padded to blockSize().

        ***********************************************************************/

        final protected override void transform(ubyte[] input)
        {
                uint A,B,C,D,E,TEMP;
                uint[16] W;
                uint s;

                bigEndian32(input,W);
                A = context[0];
                B = context[1];
                C = context[2];
                D = context[3];
                E = context[4];

                for(uint t = 0; t < 80; t++) {
                        s = t & mask;
                        if (t >= 16)
                                expand(W,s);
                        TEMP = rotateLeft(A,5) + f(t,B,C,D) + E + W[s] + K[t/20];
                        E = D; D = C; C = rotateLeft(B,30); B = A; A = TEMP;
                }

                context[0] += A;
                context[1] += B;
                context[2] += C;
                context[3] += D;
                context[4] += E;
        }

        /***********************************************************************

        ***********************************************************************/

        final static void expand (uint[] W, uint s)
        {
                W[s] = rotateLeft(W[(s+13)&mask] ^ W[(s+8)&mask] ^ W[(s+2)&mask] ^ W[s],1);
        }

}


/*******************************************************************************

*******************************************************************************/

unittest
{
    static istring[] strings = [
            "abc",
            "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
            "a",
            "0123456701234567012345670123456701234567012345670123456701234567"
    ];

    static istring[] results = [
            "a9993e364706816aba3e25717850c26c9cd0d89d",
            "84983e441c3bd26ebaae4aa1f95129e5e54670f1",
            "34aa973cd4c4daa4f61eeb2bdbad27316534016f",
            "dea356a2cddd90c7a7ecedc5ebb563934f460452"
    ];

    static int[] repeat = [
            1,
            1,
            1000000,
            10
    ];

    Sha1 h = new Sha1();

    foreach (i, s; strings)
    {
        for(int r = 0; r < repeat[i]; r++)
            h.update(s);

        char[] d = h.hexDigest();
        assert(d == results[i],":("~s~")("~d~")!=("~results[i]~")");
    }
}
