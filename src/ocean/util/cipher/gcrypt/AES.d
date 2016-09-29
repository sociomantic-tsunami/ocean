/*******************************************************************************

    libgcrypt with algorithm AES (Rijndael) with a 128 bit key.

    Requires linking with libgcrypt:
            -L -lgcrypt

    See_Also:
        http://csrc.nist.gov/publications/fips/fips197/fips-197.pdf

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.cipher.gcrypt.AES;

import ocean.util.cipher.gcrypt.core.Gcrypt;
import ocean.transition;


/*******************************************************************************

    Gcrypt with AES with mode ECB.

    See usage example in unittest below.

*******************************************************************************/

deprecated("Use the equivalent AES128 instead")
public alias GcryptNoIV!(Algorithm.GCRY_CIPHER_AES, Mode.GCRY_CIPHER_MODE_ECB) AES;

public alias GcryptNoIV!(Algorithm.GCRY_CIPHER_AES, Mode.GCRY_CIPHER_MODE_ECB) AES128;
public alias GcryptNoIV!(Algorithm.GCRY_CIPHER_AES192, Mode.GCRY_CIPHER_MODE_ECB) AES192;
public alias GcryptNoIV!(Algorithm.GCRY_CIPHER_AES256, Mode.GCRY_CIPHER_MODE_ECB) AES256;

version ( UnitTest )
{
    import ocean.core.Test;

    void testAES ( Cipher, istring str_key ) ( )
    {
        auto key = cast(Immut!(ubyte)[])str_key;

        // AES operates on 16-byte blocks.
        istring text = "Length divide 16";
        mstring encrypted_text, decrypted_text;

        // Create the class.
        auto cipher = new Cipher(key);

        // encryption/decryption is done in place so first copy the plain text
        // to a buffer.
        encrypted_text ~= text;

        // The actual encryption
        cipher.encrypt(encrypted_text);

        // Since decryption is done in place we copy the decrypted string to a
        // new buffer.
        decrypted_text ~= encrypted_text;

        // The decryption call.
        cipher.decrypt(decrypted_text);

        // We have now successfully encrypted and decrypted a string.
        test!("==")(text, decrypted_text);
    }
}

/// Usage example of AES with 128-bit keys
unittest
{
    // AES128 requires a key of length 16 bytes.
    const KEY = "asdfghjklqwertyu";

    testAES!(AES128, KEY)();
}

/// Usage example of AES with 192-bit keys
unittest
{
    // AES192 requires a key of length 24 bytes.
    const KEY = "abcdefghijklmnopqrstuvwx";

    testAES!(AES192, KEY);
}

/// Usage example of AES with 256-bit keys
unittest
{
    // AES256 requires a key of length 32 bytes.
    const KEY = "abcdefghijklmnopqrstuvwxyz012345";

    testAES!(AES256, KEY);
}
