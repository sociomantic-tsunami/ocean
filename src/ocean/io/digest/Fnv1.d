/******************************************************************************

    TODO: move module to ocean.util.digest

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module  ocean.io.digest.Fnv1;


/******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;
import ocean.util.digest.Digest;

import ocean.core.ByteSwap;


/******************************************************************************

    template for creating FNV magic constants and endianness, depending on
    if 32bit (uint) or 64bit (ulong) are used.

    Template_Params:
        T = Type of hash to use, should be `uint` or `ulong`, or any alias
            to them. Defaults to `hash_t`, which is a D alias to `size_t`.

*******************************************************************************/

public template Fnv1Const ( T = hash_t )
{
    /**************************************************************************

        FNV magic constants and endianness

     **************************************************************************/

    public alias T DigestType;

    static if (is (DigestType == uint))
    {
        public const DigestType PRIME = 0x0100_0193; // 32 bit prime
        public const DigestType INIT  = 0x811C_9DC5; // 32 bit inital digest
        public alias ByteSwap.swap32 toBigEnd;
    }
    else static if (is (DigestType == ulong))
    {
        public const DigestType PRIME = 0x0000_0100_0000_01B3; // 64 bit prime
        public const DigestType INIT  = 0xCBF2_9CE4_8422_2325; // 64 bit inital digest
        public alias ByteSwap.swap64 toBigEnd;
    }
    /*
    // be prepared for the day when Walter introduces cent...
    else static if (is (DigestType == ucent))
    {
        public const DigestType PRIME = 0x0000_0000_0100_0000_0000_0000_0000_013B; // 128 bit prime
        public const DigestType PRIME = 0x6C62_272E_07BB_0142_62B8_2175_6295_C58D; // 128 bit inital digest
    }
    */
    else static assert (false, "type '" ~ DigestType.stringof ~
                               "' is not supported, only uint and ulong");
}


/******************************************************************************

    Convenience aliases for 32-bit and 64-bit Fnv1 class template instances.
    Must be defined after Fnv1Const to avoid DMD errors

*******************************************************************************/

public alias Fnv1Generic!(true)         Fnv1a;
public alias Fnv1Generic!(true,  uint)  Fnv1a32;
public alias Fnv1Generic!(true,  ulong) Fnv1a64;


/******************************************************************************

    Compile time fnv1a hash function, calculates a hash value of type T where T
    must be uint or ulong.

    Convenience aliases for 32 bit (T = uint) or 64 bit (T = ulong) hashes are
    defined below. They have to appear after this template definition because
    DMD can currently (v1.075) not handle forward aliases in this case.

    Template_Params:
        T = Type of hash to use, should be `uint` or `ulong`, or any alias
            to them. Defaults to `hash_t`, which is a D alias to `size_t`.

*******************************************************************************/

public template StaticFnv1a ( T = hash_t )
{
    /***************************************************************************

        Calculates the Fnv1a hash value of type T from input.

    ***************************************************************************/

    public template Fnv1a ( istring input )
    {
        public const Fnv1a = Fnv1a!(Fnv1Const!(T).INIT, input);
    }

    /***************************************************************************

        Calculates the Fnv1a hash value of type T from input using hash as
        initial hash value.

    ***************************************************************************/

    public template Fnv1a ( T hash, istring input )
    {
        static if ( input.length )
        {
            public const Fnv1a = Fnv1a!((hash ^ input[0]) * Fnv1Const!(T).PRIME, input[1 .. $]);
        }
        else
        {
            public const Fnv1a = hash;
        }
    }
}


/******************************************************************************

    Aliases for Fnv1 32 and 64 bit magic constants.

*******************************************************************************/

public alias Fnv1Const!(uint)  Fnv132Const;
public alias Fnv1Const!(ulong) Fnv164Const;

/******************************************************************************

    Templates for compile-time FNV1a hashing.

*******************************************************************************/

public template StaticFnv1a32 ( istring input )
{
    public const StaticFnv1a32 = StaticFnv1a!(uint).Fnv1a!(input);
}

public template StaticFnv1a32 ( uint hash, istring input )
{
    public const StaticFnv1a32 = StaticFnv1a!(uint).Fnv1a!(hash, input);
}

public template StaticFnv1a64 ( istring input )
{
    public const StaticFnv1a64 = StaticFnv1a!(ulong).Fnv1a!(input);
}

public template StaticFnv1a64 ( ulong hash, istring input )
{
    public const StaticFnv1a64 = StaticFnv1a!(ulong).Fnv1a!(hash, input);
}


/******************************************************************************

    abstract Fnv1 digest class

*******************************************************************************/

public abstract class FnvDigest : Digest
{
    /**************************************************************************

        Simply returns the digest as an ulong independently of the digest size
        and reset the internal state.

        Returns:
             digest

     **************************************************************************/

    public abstract ulong ulongDigest ( );
}


/*******************************************************************************

        Fowler / Noll / Vo (FNV) 1/1a Hash Module

        Very fast hashing algorithm implementation with support for 32/64 bit
        hashes.
        This modules implements two versions of FNV1: FNV1 and FNV1a. The
        difference is extremely slight and Noll himself says:

            "Some people use FNV1a instead of FNV1 because they see slightly
            better dispersion for tiny (<4 octets) chunks of memory. Either
            FNV-1 or FNV-1a make a fine hash."

            (cited from http://www.isthe.com/chongo/tech/comp/fnv/)


        The FNV1A template parameter selects FNV1a if set to true on
        instantiation or FNV1 otherwise. It is recommended to use the
        Fnv1XX/Fnv1aXX aliases.

        Fnv1 and Fnv1a (without 32/64 suffix) use the native machine data word
        width.

        32bit ~ 3704333.44 hash/sec
        64bit ~ 1728119.76 hash/sec

        --

        Usage

        It is recommended to use these Fnv1 class convenience aliases:

         - Fnv1 for FNV1 digests of the machine's native width
         - Fnv1a for FNV1a digests of the machine's native width

         - Fnv132 for 32-bit FNV1 digests
         - Fnv1a32 for 32-bit FNV1a digests

         - Fnv164 for 64-bit FNV1 digests
         - Fnv1a64 for 64-bit FNV1a digests

        Example 1: Generating FNV1 digests using class instances

        ---

            import ocean.io.digest.Fnv1;

            auto fnv1   = new Fnv1;
            auto fnv132 = new Fnv132;
            auto fnv164 = new Fnv164;

            auto hello = "Hello World!";

            fnv1.update(hello);
            fnv132.update(hello);
            fnv164.update(hello);

            auto hash   = fnv1.hexDigest();
            auto hash32 = fnv132.hexDigest();
            auto hash64 = fnv164.hexDigest();

        ---

        Example 2: Generating FNV1a digests using the static fnv1() method

        ---

            import ocean.io.digest.Fnv;

            auto hello = "Hello World!";

            size_t hash   = Fnv1a(hello);       // size_t uses the native machine data word width
            uint   hash32 = Fnv1a32(hello);
            ulong  hash64 = Fnv1a64(hello);

        ---

        --

        We should use this hash algorithm in combination with this consistent
        hash algorithm in order to build a distributed hash table (DTH)

        http://www.audioscrobbler.net/development/ketama/
        svn://svn.audioscrobbler.net/misc/ketama/
        http://pdos.csail.mit.edu/chord/

        --

        References

        http://www.isthe.com/chongo/tech/comp/fnv/
        http://www.azillionmonkeys.com/qed/hash.html
        http://www.azillionmonkeys.com/qed/hash.c
        http://www.digitalmars.com/d/2.0/htomodule.html

        http://www.team5150.com/~andrew/blog/2007/03/breaking_superfasthash.html
        http://www.team5150.com/~andrew/blog/2007/03/when_bad_hashing_means_good_caching.html
        http://www.azillionmonkeys.com/qed/hash.html

*******************************************************************************/

public class Fnv1Generic ( bool FNV1A = false, T = hash_t ) : FnvDigest
{
    /**************************************************************************

        DigestType type alias

     **************************************************************************/

    mixin Fnv1Const!(T);

    /**************************************************************************

        Binary digest length and hexadecimal digest string length constants

     **************************************************************************/

    public const DIGEST_LENGTH = DigestType.sizeof;
    public const HEXDGT_LENGTH = DIGEST_LENGTH * 2;

    public alias char[HEXDGT_LENGTH] HexDigest;

    /**************************************************************************

        This alias for chainable methods

     **************************************************************************/

    public alias typeof (this) This;

    /**************************************************************************

        Endianness aware integer to byte array converter

        Usage:

        ---

             Fnv32.BinConvert bc;

             ubyte[] binstr = bc(0xAFFE4711);

             // binstr now is [0xAF, 0xFE, 0x47, 0x11]

        ---

     **************************************************************************/

     public union BinConvert
     {
         public alias ubyte[DIGEST_LENGTH] BinString;

         /* members */

         public BinString array;

         public DigestType value;

         /* cast "value" from integer type "DigestType" to binary string type "BinString"
            considering machine byte order (endianness) */

         public ubyte[] opCall ( DigestType value )
         {
             this.value = value;

             version (LittleEndian) toBigEnd(array);

             return array.dup;
         }
     };


    /**************************************************************************

        class properties

     **************************************************************************/

    private DigestType digest = this.INIT;


    /**************************************************************************

        Tango DigestType class methods

     **************************************************************************/


    /**************************************************************************

        Processes data

        Remarks:
              Updates the hash algorithm state with new data

     **************************************************************************/

    public override This update ( Const!(void)[] data )
    {
        this.digest = this.fnv1(data, this.digest);

        return this;
    }


    /**************************************************************************

        Computes the digest and resets the state

        Params:
            buffer = a buffer can be supplied for the digest to be
                     written to

        Remarks:
            This method is endianness-aware: The returned array has always the
            least-order byte at byte [0] (big endian).

            If the buffer is not large enough to hold the
            digest, a new buffer is allocated and returned.
            The algorithm state is always reset after a call to
            binaryDigest. Use the digestSize method to find out how
            large the buffer has to be.

    ***************************************************************************/

    public override ubyte[] binaryDigest( ubyte[] buffer = null )
    {
        scope(exit) this.reset();

        BinConvert bc;

        bc(this.digest);

        if ( buffer )
        {
            buffer.length = this.digestSize();

            foreach (i, d; bc.array)
            {
                buffer[i] = d;
            }
        }

        return buffer? buffer: bc.array.dup;
    }


    /**************************************************************************

        Returns the size in bytes of the digest

        Returns:
          the size of the digest in bytes

        Remarks:
          Returns the size of the digest.

    ***************************************************************************/

    public override uint digestSize ( )
    {
        return this.DIGEST_LENGTH;
    }


    /**************************************************************************

        extension class methods (in addition to the DigestType standard methods)

     **************************************************************************/


    /**************************************************************************

        Resets the state

        Returns:
             this instance

     ***************************************************************************/

    public This reset ( )
    {
        this.digest = this.INIT;

        return this;
    }


    /**************************************************************************

        Simply returns the digest

        Returns:
             digest

     **************************************************************************/

    public DigestType getDigest ( )
    {
        return this.digest;
    }


    /**************************************************************************

        Simply returns the digest as an ulong independently of the digest size
        and reset the internal state.

        Returns:
             digest

     **************************************************************************/

    public override ulong ulongDigest ( )
    {
        ulong d = this.digest;
        this.reset();
        return d;
    }


    /**************************************************************************

        Core methods

     **************************************************************************/



    /**************************************************************************

        Calculates a FNV1/FNV1a digest from data. data are processed in
        octet/byte-wise manner.

        Usage:

        ---

             import ocean.io.digest.Fnv;

             auto data = "sociomantic";

             uint  digest32 = Fnv32.fnv1(data);
             ulong digest64 = Fnv64.fnv1(data);

        ---

        Params:
             data =   data to digest
             digest = initial digest; defaults to the magic 32 bit or 64 bit
                      initial value, according to DigestType

        Returns:
             resulting digest

     **************************************************************************/

    public static DigestType fnv1 ( U ) ( U data, DigestType digest = INIT )
    {
        Const!(ubyte)[] data_;

        static if (is (Unqual!(U) : ubyte[]))
        {
            data_ = data;
        }
        else static if (is (U V : V[]))
        {
            static if (V.sizeof == 1)
            {
                data_ = cast(Const!(ubyte)[])data;
            }
            else
            {
                data_ = (cast(Const!(ubyte)*)data.ptr)[0 .. data.length * V.sizeof];
            }
        }
        else
        {
            data_ = cast(Const!(ubyte)[])((cast(Const!(void)*)&data)[0 .. data.sizeof]);
        }

        foreach (d; data_)
        {
            digest = fnv1_core(d, digest);
        }

        return digest;
    }

    public alias fnv1 opCall;


    /**************************************************************************

        Calculates a FNV1/FNV1a digest from data and generates a hexdecimal
        string representation of the digest. data are processed in
        octet/byte-wise manner.

        Usage:

        ---

             import ocean.io.digest.Fnv;

             Fnv32.HexDigest digest32;
             Fnv64.HexDigest digest64;

             auto data = "sociomantic";

             digest32 = Fnv32.fnv1(data, digest32);
             digest64 = Fnv64.fnv1(data, digest32);

        ---

        Params:
             data    = data to digest
             hexdgst = string buffer
             digest  = initial digest; defaults to the magic 32 bit or 64 bit
                       initial value, according to DigestType

        Returns:
             hexdecimal string representation of resulting digest

     **************************************************************************/

    public static char[] fnv1_hex ( U ) ( U data, char[] hexdgst, DigestType digest = INIT )
    {
        digest = fnv1(data, digest);

        foreach_reverse (ref h; hexdgst)
        {
            h = "0123456789abcdef"[digest & 0xF];

            digest >>= 4;
        }

        return hexdgst;
    }


    /**************************************************************************

        FNV1/FNV1a core; calculates a digest of one octet d

        Params:
             d      = data to digest
             digest = initial digest

        Returns:
             resulting digest

     **************************************************************************/

    public static DigestType fnv1_core ( ubyte d, DigestType digest )
    {
        static if (FNV1A)
        {
            return (digest ^ d) * PRIME;
        }
        else
        {
            return (digest * PRIME) ^ d;
        }
    }


    /***************************************************************************

        Creates a combined hash of all the provided parameters.
        The previous hashed value is used as the initial state for the next.

        Template_Params:
            Vals = Tuple of value types, inferred.

        Params:
            vals = the values to be used for hashing

        Returns:
            returns the combined hash

    ***************************************************************************/

    public static hash_t combined ( Vals... ) ( Vals vals )
    {
        hash_t hash = INIT;

        foreach (val; vals)
        {
            hash = fnv1(val, hash);
        }

        return hash;
    }
}


/**************************************************************************

    unit test


    Test data for FNV1/FNV1a hash algorithm

    Data taken from Landon Curt Noll's FNV test program source code:

        http://www.isthe.com/chongo/src/fnv/test_fnv.c

    found at his FNV web page:

        http://www.isthe.com/chongo/tech/comp/fnv/


    The original code was released as public domain by chongo <Landon Curt
    Noll>:
    http://web.archive.org/web/20101105131957/http://www.isthe.com/chongo/src/fnv/test_fnv.c

    C to D port by David Eckardt, sociomantic labs, October 2009

**************************************************************************/


version ( UnitTest )
{
    // Uncomment the next line to see UnitTest output
    // version = UnitTestVerbose;

    private istring errmsg ( istring func, istring str, bool is_text )
    {
        auto errmsg = "unit test failed for " ~ func;

        if (is_text)
        {
            errmsg ~= ": \"" ~ str ~ "\"";
        }

        return errmsg;
    }
}

unittest
{
    struct TestData
    {
        /*
         * 32-bit FNV1 digests of "string" below as integer, binary data string
         * and hexadecimal text string
         */
        uint    fnv1_32;
        ubyte[] fnv1_32_bin;
        istring  fnv1_32_hex;

        /*
         * 32-bit FNV1a digests of "string" below as integer, binary data string
         * and hexadecimal text string
         */
        uint    fnv1a_32;
        ubyte[] fnv1a_32_bin;
        istring  fnv1a_32_hex;

        /*
         * 64-bit FNV1 digests of "string" below as integer, binary data string
         * and hexadecimal text string
         */
        ulong   fnv1_64;
        ubyte[] fnv1_64_bin;
        istring  fnv1_64_hex;

        /*
         * 64-bit FNV1a digests of "string" below as integer, binary data string
         * and hexadecimal text string
         */
        ulong   fnv1a_64;
        ubyte[] fnv1a_64_bin;
        istring  fnv1a_64_hex;

        /*
         * is_text == true indicates that the content of "string" is safe to
         * write to a text output (text file, console...).
         */
        bool   is_text;

        // string of which the digests above are computed from
        istring str;
    }

    const TestData[] testdata =
    [
        {0xc5f1d7e9, [0xc5, 0xf1, 0xd7, 0xe9], "c5f1d7e9", 0x512b2851, [0x51, 0x2b, 0x28, 0x51], "512b2851", 0x43c94e2c8b277509, [0x43, 0xc9, 0x4e, 0x2c, 0x8b, 0x27, 0x75, 0x09], "43c94e2c8b277509", 0x33b96c3cd65b5f71, [0x33, 0xb9, 0x6c, 0x3c, 0xd6, 0x5b, 0x5f, 0x71], "33b96c3cd65b5f71",  true, "391581216093391581216093391581216093391581216093391581216093391581216093391581216093391581216093391581216093391581216093"},
        {0x32c1f439, [0x32, 0xc1, 0xf4, 0x39], "32c1f439", 0x76823999, [0x76, 0x82, 0x39, 0x99], "76823999", 0x3cbfd4e4ea670359, [0x3c, 0xbf, 0xd4, 0xe4, 0xea, 0x67, 0x03, 0x59], "3cbfd4e4ea670359", 0xd845097780602bb9, [0xd8, 0x45, 0x09, 0x77, 0x80, 0x60, 0x2b, 0xb9], "d845097780602bb9",  true, "391581*2^216093-1391581*2^216093-1391581*2^216093-1391581*2^216093-1391581*2^216093-1391581*2^216093-1391581*2^216093-1391581*2^216093-1391581*2^216093-1391581*2^216093-1"},
        {0x7fd3eb7d, [0x7f, 0xd3, 0xeb, 0x7d], "7fd3eb7d", 0xc0586935, [0xc0, 0x58, 0x69, 0x35], "c0586935", 0xc05887810f4d019d, [0xc0, 0x58, 0x87, 0x81, 0x0f, 0x4d, 0x01, 0x9d], "c05887810f4d019d", 0x84d47645d02da3d5, [0x84, 0xd4, 0x76, 0x45, 0xd0, 0x2d, 0xa3, 0xd5], "84d47645d02da3d5", false, "\x05\xf9\x9d\x03\x4c\x81\x05\xf9\x9d\x03\x4c\x81\x05\xf9\x9d\x03\x4c\x81\x05\xf9\x9d\x03\x4c\x81\x05\xf9\x9d\x03\x4c\x81\x05\xf9\x9d\x03\x4c\x81\x05\xf9\x9d\x03\x4c\x81\x05\xf9\x9d\x03\x4c\x81\x05\xf9\x9d\x03\x4c\x81\x05\xf9\x9d\x03\x4c\x81"},
        {0x81597da5, [0x81, 0x59, 0x7d, 0xa5], "81597da5", 0xf3415c85, [0xf3, 0x41, 0x5c, 0x85], "f3415c85", 0x14468ff93ac22dc5, [0x14, 0x46, 0x8f, 0xf9, 0x3a, 0xc2, 0x2d, 0xc5], "14468ff93ac22dc5", 0x83544f33b58773a5, [0x83, 0x54, 0x4f, 0x33, 0xb5, 0x87, 0x73, 0xa5], "83544f33b58773a5", false, "FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210"},
        {0x05eb7a25, [0x05, 0xeb, 0x7a, 0x25], "05eb7a25", 0x0ae4ff65, [0x0a, 0xe4, 0xff, 0x65], "0ae4ff65", 0xebed699589d99c05, [0xeb, 0xed, 0x69, 0x95, 0x89, 0xd9, 0x9c, 0x05], "ebed699589d99c05", 0x9175cbb2160836c5, [0x91, 0x75, 0xcb, 0xb2, 0x16, 0x08, 0x36, 0xc5], "9175cbb2160836c5", false, "\xfe\xdc\xba\x98\x76\x54\x32\x10\xfe\xdc\xba\x98\x76\x54\x32\x10\xfe\xdc\xba\x98\x76\x54\x32\x10\xfe\xdc\xba\x98\x76\x54\x32\x10\xfe\xdc\xba\x98\x76\x54\x32\x10\xfe\xdc\xba\x98\x76\x54\x32\x10\xfe\xdc\xba\x98\x76\x54\x32\x10\xfe\xdc\xba\x98\x76\x54\x32\x10\xfe\xdc\xba\x98\x76\x54\x32\x10\xfe\xdc\xba\x98\x76\x54\x32\x10"},
        {0x9c0fa1b5, [0x9c, 0x0f, 0xa1, 0xb5], "9c0fa1b5", 0x58b79725, [0x58, 0xb7, 0x97, 0x25], "58b79725", 0x6d99f6df321ca5d5, [0x6d, 0x99, 0xf6, 0xdf, 0x32, 0x1c, 0xa5, 0xd5], "6d99f6df321ca5d5", 0xc71b3bc175e72bc5, [0xc7, 0x1b, 0x3b, 0xc1, 0x75, 0xe7, 0x2b, 0xc5], "c71b3bc175e72bc5",  true, "EFCDAB8967452301EFCDAB8967452301EFCDAB8967452301EFCDAB8967452301EFCDAB8967452301EFCDAB8967452301EFCDAB8967452301EFCDAB8967452301EFCDAB8967452301EFCDAB8967452301"},
        {0x53ccb1c5, [0x53, 0xcc, 0xb1, 0xc5], "53ccb1c5", 0xdea43aa5, [0xde, 0xa4, 0x3a, 0xa5], "dea43aa5", 0x0cd410d08c36d625, [0x0c, 0xd4, 0x10, 0xd0, 0x8c, 0x36, 0xd6, 0x25], "0cd410d08c36d625", 0x636806ac222ec985, [0x63, 0x68, 0x06, 0xac, 0x22, 0x2e, 0xc9, 0x85], "636806ac222ec985", false, "\xef\xcd\xab\x89\x67\x45\x23\x01\xef\xcd\xab\x89\x67\x45\x23\x01\xef\xcd\xab\x89\x67\x45\x23\x01\xef\xcd\xab\x89\x67\x45\x23\x01\xef\xcd\xab\x89\x67\x45\x23\x01\xef\xcd\xab\x89\x67\x45\x23\x01\xef\xcd\xab\x89\x67\x45\x23\x01\xef\xcd\xab\x89\x67\x45\x23\x01\xef\xcd\xab\x89\x67\x45\x23\x01\xef\xcd\xab\x89\x67\x45\x23\x01"},
        {0xfabece15, [0xfa, 0xbe, 0xce, 0x15], "fabece15", 0x2bb3be35, [0x2b, 0xb3, 0xbe, 0x35], "2bb3be35", 0xef1b2a2c86831d35, [0xef, 0x1b, 0x2a, 0x2c, 0x86, 0x83, 0x1d, 0x35], "ef1b2a2c86831d35", 0xb6ef0e6950f52ed5, [0xb6, 0xef, 0x0e, 0x69, 0x50, 0xf5, 0x2e, 0xd5], "b6ef0e6950f52ed5",  true, "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF"},
        {0x4ad745a5, [0x4a, 0xd7, 0x45, 0xa5], "4ad745a5", 0xea777a45, [0xea, 0x77, 0x7a, 0x45], "ea777a45", 0x3b349c4d69ee5f05, [0x3b, 0x34, 0x9c, 0x4d, 0x69, 0xee, 0x5f, 0x05], "3b349c4d69ee5f05", 0xead3d8a0f3dfdaa5, [0xea, 0xd3, 0xd8, 0xa0, 0xf3, 0xdf, 0xda, 0xa5], "ead3d8a0f3dfdaa5", false, "\x01\x23\x45\x67\x89\xab\xcd\xef\x01\x23\x45\x67\x89\xab\xcd\xef\x01\x23\x45\x67\x89\xab\xcd\xef\x01\x23\x45\x67\x89\xab\xcd\xef\x01\x23\x45\x67\x89\xab\xcd\xef\x01\x23\x45\x67\x89\xab\xcd\xef\x01\x23\x45\x67\x89\xab\xcd\xef\x01\x23\x45\x67\x89\xab\xcd\xef\x01\x23\x45\x67\x89\xab\xcd\xef\x01\x23\x45\x67\x89\xab\xcd\xef"},
        {0xe5bdc495, [0xe5, 0xbd, 0xc4, 0x95], "e5bdc495", 0x8f21c305, [0x8f, 0x21, 0xc3, 0x05], "8f21c305", 0x55248ce88f45f035, [0x55, 0x24, 0x8c, 0xe8, 0x8f, 0x45, 0xf0, 0x35], "55248ce88f45f035", 0x922908fe9a861ba5, [0x92, 0x29, 0x08, 0xfe, 0x9a, 0x86, 0x1b, 0xa5], "922908fe9a861ba5",  true, "1032547698BADCFE1032547698BADCFE1032547698BADCFE1032547698BADCFE1032547698BADCFE1032547698BADCFE1032547698BADCFE1032547698BADCFE1032547698BADCFE1032547698BADCFE"},
        {0x23b3c0a5, [0x23, 0xb3, 0xc0, 0xa5], "23b3c0a5", 0x5c9d0865, [0x5c, 0x9d, 0x08, 0x65], "5c9d0865", 0xaa69ca6a18a4c885, [0xaa, 0x69, 0xca, 0x6a, 0x18, 0xa4, 0xc8, 0x85], "aa69ca6a18a4c885", 0x6d4821de275fd5c5, [0x6d, 0x48, 0x21, 0xde, 0x27, 0x5f, 0xd5, 0xc5], "6d4821de275fd5c5", false, "\x10\x32\x54\x76\x98\xba\xdc\xfe\x10\x32\x54\x76\x98\xba\xdc\xfe\x10\x32\x54\x76\x98\xba\xdc\xfe\x10\x32\x54\x76\x98\xba\xdc\xfe\x10\x32\x54\x76\x98\xba\xdc\xfe\x10\x32\x54\x76\x98\xba\xdc\xfe\x10\x32\x54\x76\x98\xba\xdc\xfe\x10\x32\x54\x76\x98\xba\xdc\xfe\x10\x32\x54\x76\x98\xba\xdc\xfe\x10\x32\x54\x76\x98\xba\xdc\xfe"},
        {0xfa823dd5, [0xfa, 0x82, 0x3d, 0xd5], "fa823dd5", 0xfa823dd5, [0xfa, 0x82, 0x3d, 0xd5], "fa823dd5", 0x1fe3fce62bd816b5, [0x1f, 0xe3, 0xfc, 0xe6, 0x2b, 0xd8, 0x16, 0xb5], "1fe3fce62bd816b5", 0x1fe3fce62bd816b5, [0x1f, 0xe3, 0xfc, 0xe6, 0x2b, 0xd8, 0x16, 0xb5], "1fe3fce62bd816b5", false, "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"},
        {0x0c6c58b9, [0x0c, 0x6c, 0x58, 0xb9], "0c6c58b9", 0x21a27271, [0x21, 0xa2, 0x72, 0x71], "21a27271", 0x0289a488a8df69d9, [0x02, 0x89, 0xa4, 0x88, 0xa8, 0xdf, 0x69, 0xd9], "0289a488a8df69d9", 0xc23e9fccd6f70591, [0xc2, 0x3e, 0x9f, 0xcc, 0xd6, 0xf7, 0x05, 0x91], "c23e9fccd6f70591", false, "\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07"},
        {0xe2dbccd5, [0xe2, 0xdb, 0xcc, 0xd5], "e2dbccd5", 0x83c5c6d5, [0x83, 0xc5, 0xc6, 0xd5], "83c5c6d5", 0x15e96e1613df98b5, [0x15, 0xe9, 0x6e, 0x16, 0x13, 0xdf, 0x98, 0xb5], "15e96e1613df98b5", 0xc1af12bdfe16b5b5, [0xc1, 0xaf, 0x12, 0xbd, 0xfe, 0x16, 0xb5, 0xb5], "c1af12bdfe16b5b5",  true, "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"},
        {0xdb7f50f9, [0xdb, 0x7f, 0x50, 0xf9], "db7f50f9", 0x813b0881, [0x81, 0x3b, 0x08, 0x81], "813b0881", 0xe6be57375ad89b99, [0xe6, 0xbe, 0x57, 0x37, 0x5a, 0xd8, 0x9b, 0x99], "e6be57375ad89b99", 0x39e9f18f2f85e221, [0x39, 0xe9, 0xf1, 0x8f, 0x2f, 0x85, 0xe2, 0x21], "39e9f18f2f85e221", false, "\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f"}
     ];

    scope Fnv1a32 fnv1a32 = new Fnv1a32;
    scope Fnv1a64 fnv1a64 = new Fnv1a64;

    foreach (tdat; testdata)
    {
        /**********************************************************************

             core methods test

         **********************************************************************/

        assert (Fnv1a32.fnv1(tdat.str) == tdat.fnv1a_32, errmsg("Fnv1a32.fnv1", tdat.str, tdat.is_text));
        assert (Fnv1a64.fnv1(tdat.str) == tdat.fnv1a_64, errmsg("Fnv1a64.fnv1", tdat.str, tdat.is_text));

        /**********************************************************************

            class methods test

         **********************************************************************/

        assert (fnv1a32.update(tdat.str).hexDigest == tdat.fnv1a_32_hex, errmsg("Fnv1a32.hexDigest", tdat.str, tdat.is_text));
        assert (fnv1a64.update(tdat.str).hexDigest == tdat.fnv1a_64_hex, errmsg("Fnv1a64.hexDigest", tdat.str, tdat.is_text));
    }


    assert ( StaticFnv1a32!("myString") == Fnv1a32("myString"[]), "CompileTime Fnv1a32 failed");
    assert ( StaticFnv1a32!("TEST") == Fnv1a32("TEST"[]), "CompileTime Fnv1a32 failed");


    istring d1 = "ABC";
    int d2 = 123;
    ulong d3 = 12354;

    auto chash = Fnv1a.combined(d1, d2, d3);

    auto mhash = Fnv1a(d3, Fnv1a(d2, Fnv1a(d1)));

    assert (chash == mhash, "Combined hash failed");
}

