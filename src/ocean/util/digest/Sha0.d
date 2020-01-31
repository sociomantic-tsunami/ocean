/*******************************************************************************

        This module implements the SHA-0 Algorithm described by Secure
        Hash Standard, FIPS PUB 180

        Copyright:
            Copyright (c) 2006 Tango contributors.
            Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: Feb 2006

        Authors: Regan Heath, Oskar Linde

*******************************************************************************/

module ocean.util.digest.Sha0;

import ocean.meta.types.Qualifiers;

import ocean.util.digest.Sha01;

version (unittest) import ocean.core.Test;

public  import ocean.util.digest.Digest;

/*******************************************************************************

*******************************************************************************/

final class Sha0 : Sha01
{
        /***********************************************************************

                Construct an Sha0

        ***********************************************************************/

        this() { }

        /***********************************************************************

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
                        if (t >= 16) expand(W,s);
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

        final static protected void expand(uint[] W, uint s)
        {
                W[s] = W[(s+13)&mask] ^ W[(s+8)&mask] ^ W[(s+2)&mask] ^ W[s];
        }


}


/*******************************************************************************

*******************************************************************************/

unittest
{
    static istring[] strings = [
        "",
        "abc",
        "message digest",
        "abcdefghijklmnopqrstuvwxyz",
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
        "12345678901234567890123456789012345678901234567890123456789012345678901234567890"
    ];

    static istring[] results = [
        "f96cea198ad1dd5617ac084a3d92c6107708c0ef",
        "0164b8a914cd2a5e74c4f7ff082c4d97f1edf880",
        "c1b0f222d150ebb9aa36a40cafdc8bcbed830b14",
        "b40ce07a430cfd3c033039b9fe9afec95dc1bdcd",
        "79e966f7a3a990df33e40e3d7f8f18d2caebadfa",
        "4aa29d14d171522ece47bee8957e35a41f3e9cff",
    ];

    Sha0 h = new Sha0();

    foreach (i, s; strings)
    {
        h.update(s);
        char[] d = h.hexDigest();
        test(d == results[i],":("~s~")("~d~")!=("~results[i]~")");
    }
}
