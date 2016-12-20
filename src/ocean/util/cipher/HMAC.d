/*******************************************************************************

    Provides a HMAC implementation

    Usage example:

    ---

        import ocean.util.cipher.HMAC;
        import ocean.util.digest.Sha1;

        auto sha = new Sha1;
        auto hmac = new HMAC(sha);

        const secret_key = "0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b";
        hmac.init(secret_key);

        const ubyte[] data = [23, 23, 23, 23]; // some data to encode
        hmac.update(data);

        auto encoded = hmac.digest;

        // To reuse the hmac object, init() must be called again.

    ---

    Copyright:
        Copyright (C) dcrypt contributors 2008.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

    Version: Jan 2010: Initial release

    Authors: Thomas Dixon, Mathias L. Baumann

*******************************************************************************/

deprecated module ocean.util.cipher.HMAC;
pragma(msg, "ocean.util.cipher is deprecated, use ocean.util.cipher.gcrypt instead.");



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.Exception;

import ocean.util.cipher.misc.ByteConverter;

import ocean.util.cipher.misc.Bitwise;

import ocean.util.digest.MerkleDamgard;



/******************************************************************************

    HMAC Exception

*******************************************************************************/

class HMACException : Exception
{
    mixin DefaultExceptionCtor;
}


/*******************************************************************************

    Implementation of Keyed-Hash Message Authentication Code (HMAC)

    Conforms: RFC 2104
     References: http://www.faqs.org/rfcs/rfc2104.html

*******************************************************************************/

public class HMAC
{
    /***************************************************************************

        Hashing algorithm (passed to constructor).

    ***************************************************************************/

    private MerkleDamgard hash;


    /***************************************************************************

        Internal buffers.

    ***************************************************************************/

    private ubyte[] ipad, opad;


    /***************************************************************************

        Flag set to true when the init() method is called. The update() method
        requires that the instance is initialized.

    ***************************************************************************/

    private bool initialized;


    /***************************************************************************

        Constructor. Creates a new instance of an HMAC object

        Params:
            hash = the hash algorithm to use (i.E. new Sha1(); )

    ***************************************************************************/

    public this ( MerkleDamgard hash)
    {
        this.hash = hash;
        this.hash.reset();

        this.ipad = new ubyte[this.blockSize];
        this.opad = new ubyte[this.blockSize];
    }


    /***************************************************************************

        Initializes the HMAC object

        Params:
            k        = the key to initialize from
            buffer = buffer to use (the buffer is resized to the digest length)

    ***************************************************************************/

    public void init ( in ubyte[] k, ref ubyte[] buffer )
    {
        Const!(ubyte)[] key;
        buffer.length = this.hash.digestSize();

        this.hash.reset();

        if (k.length > this.blockSize)
        {
            this.hash.update(k);
            key = this.hash.binaryDigest(buffer)[0 .. this.hash.digestSize()];
        }
        else
        {
            key = k;
        }

        this.ipad[] = 0x36;
        this.opad[] = 0x5c;

        foreach (uint i, ubyte j; key)
        {
            this.ipad[i] ^= j;
            this.opad[i] ^= j;
        }

        this.reset();

        this.initialized = true;
    }


    /***************************************************************************

        Add more data to process

        Params:
            input = the data

        Throws:
            if the instance has not been initialized (with the init() method).

    ***************************************************************************/

    public void update ( ubyte[] input )
    {
        if (!this.initialized)
            throw new HMACException(this.name()~": HMAC not initialized.");

        this.hash.update(input);
    }


    /***************************************************************************

        Returns the name of the algorithm

        Returns:
            Returns the name of the algorithm

    ***************************************************************************/

    public istring name()
    {
        return "HMAC-" ~ this.hash.toString;
    }


    /***************************************************************************

        Resets the state

    ***************************************************************************/

    public void reset()
    {
        this.hash.reset();
        this.hash.update(this.ipad);
    }


    /***************************************************************************

        Returns the blocksize

    ***************************************************************************/

    public uint blockSize()
    {
        return this.hash.blockSize;
    }


    /***************************************************************************

        Returns the size in bytes of the digest

    ***************************************************************************/

    public uint macSize()
    {
        return this.hash.digestSize;
    }


    /***************************************************************************

        Computes the digest and returns it

        Params:
            buffer = buffer to use (the buffer is resized to the digest length)

    ***************************************************************************/

    public ubyte[] digest ( ref ubyte[] buffer )
    {
        buffer.length = this.hash.digestSize();

        ubyte[] t = this.hash.binaryDigest(buffer)[0 .. this.hash.digestSize()];
        this.hash.update(this.opad);
        this.hash.update(t);

        ubyte[] r = this.hash.binaryDigest(buffer)[0 .. this.hash.digestSize()];

        this.reset();

        return r;
    }


    /***************************************************************************

        Computes the digest and returns it as hex.

        This method allocates a new buffer on every call to hold the return
        value.

        Params:
            buffer = buffer to use (the buffer is resized to the digest length)

        Returns:
            the digest in hex representation

    ***************************************************************************/

    public mstring hexDigest ( ref ubyte[] buffer )
    {
        return ByteConverter.hexEncode(this.digest(buffer));
    }

    /***************************************************************************

        Computes the digest and returns it as hex

        Params:
            buffer = buffer to use (the buffer is resized to the digest length)
            output = reusable buffer to store the hex representation (may be
                resized)

        Returns:
            a slice over ouput containing the digest in hex representation

     ***************************************************************************/

    public mstring hexDigest ( ref ubyte[] buffer, ref mstring output)
    {
        return ByteConverter.hexEncode(this.digest(buffer), output);
    }
}



/***************************************************************************

    UnitTest

***************************************************************************/

version (UnitTest)
{
    import ocean.util.digest.Sha1;
}

unittest
{
    static istring[] test_keys = [
        "0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b",
        "4a656665", // Jefe?
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"~
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"~
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"~
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    ];

    static istring[] test_inputs = [
        "4869205468657265",
        "7768617420646f2079612077616e7420666f72206e6f7468696e673f",
        "dd",
        "54657374205573696e67204c6172676572205468616e20426c6f63"~
        "6b2d53697a65204b6579202d2048617368204b6579204669727374"
    ];

    static int[] test_repeat = [
        1, 1, 50, 1
    ];

    static istring[] test_results = [
        "b617318655057264e28bc0b6fb378c8ef146be00",
        "effcdf6ae5eb2fa2d27416d5f184df9c259a7c79",
        "125d7342b9ac11cd91a39af48aa17b4f63f175d3",
        "aa4ae5e15272d00e95705637ce8a3b55ed402112"
    ];

    ubyte[] buffer;

    HMAC h = new HMAC(new Sha1());
    foreach (i, k; test_keys)
    {
        h.init(ByteConverter.hexDecode(k), buffer);
        for (int j = 0; j < test_repeat[i]; j++)
            h.update(ByteConverter.hexDecode(test_inputs[i]));
        auto mac = h.hexDigest(buffer);
        assert(mac == test_results[i],
                h.name~": ("~mac~") != ("~test_results[i]~")");
    }
}
