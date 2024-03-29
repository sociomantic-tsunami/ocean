/******************************************************************************

        This module defines the Digest interface.

        Copyright:
            Copyright (c) 2006 Tango contributors.
            Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: Feb 2006

        Authors: Regan Heath, Oskar Linde

******************************************************************************/

module ocean.util.digest.Digest;

import ocean.meta.types.Qualifiers;

import ocean.core.Verify;

version (unittest) import ocean.core.Test;

/*******************************************************************************

        The DigestTransform interface defines the interface of message
        digest algorithms, such as MD5 and SHA. Message digests are
        secure hash functions that take a message of arbitrary length
        and produce a fix length digest as output.

        A object implementing the DigestTransform should start out initialized.
        The data is processed though calls to the update method. Once all data
        has been sent to the algorithm, the digest is finalized and computed
        with the digest method.

        The digest method may only be called once. After the digest
        method has been called, the algorithm is reset to its initial
        state.

        Using the update method, data may be processed piece by piece,
        which is useful for cases involving streams of data.

        For example:
        ---
        // create an MD5 hash algorithm
        Md5 hash = new Md5();

        // process some data
        hash.update("The quick brown fox");

        // process some more data
        hash.update(" jumps over the lazy dog");

        // conclude algorithm and produce digest
        ubyte[] digest = hash.binaryDigest();
        ---

******************************************************************************/

abstract class Digest
{
        /*********************************************************************

               Processes data

               Remarks:
                     Updates the hash algorithm state with new data

        *********************************************************************/

        abstract Digest update (const(void)[] data);

        /********************************************************************

               Computes the digest and resets the state

               Params:
                   buffer = a buffer can be supplied for the digest to be
                            written to

               Remarks:
                   If the buffer is not large enough to hold the
                   digest, a new buffer is allocated and returned.
                   The algorithm state is always reset after a call to
                   binaryDigest. Use the digestSize method to find out how
                   large the buffer has to be.

        *********************************************************************/

        abstract ubyte[] binaryDigest(ubyte[] buffer = null);

        /********************************************************************

               Returns the size in bytes of the digest

               Returns:
                 the size of the digest in bytes

               Remarks:
                 Returns the size of the digest.

        *********************************************************************/

        abstract uint digestSize();

        /*********************************************************************

               Computes the digest as a hex string and resets the state

               Params:
                   buffer = a buffer can be supplied in which the digest
                            will be written. It needs to be able to hold
                            2 * digestSize chars

               Remarks:
                    If the buffer is not large enough to hold the hex digest,
                    a new buffer is allocated and returned. The algorithm
                    state is always reset after a call to hexDigest.

        *********************************************************************/

        char[] hexDigest (char[] buffer = null)
        {
                uint ds = digestSize();

                if (buffer.length < ds * 2)
                    buffer.length = ds * 2;

                static ubyte[] buf;
                buf.length = ds;
                assumeSafeAppend(buf);
                ubyte[] ret = binaryDigest(buf);
                verify(ret.ptr == buf.ptr);

                static string hexdigits = "0123456789abcdef";
                int i = 0;

                foreach (b; buf)
                        {
                        buffer[i++] = hexdigits[b >> 4];
                        buffer[i++] = hexdigits[b & 0xf];
                        }

                return buffer;
        }
}
