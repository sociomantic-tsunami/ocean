/*******************************************************************************

    libgcrypt with algorithm AES (Rijndael) with a 128 bit key.

    Requires linking with libgcrypt:
            -L -lgcrypt

    See_Also:
        http://csrc.nist.gov/publications/fips/fips197/fips-197.pdf

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
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

public alias GcryptNoIV!(Algorithm.GCRY_CIPHER_AES, Mode.GCRY_CIPHER_MODE_ECB) AES128;

/// Usage example of AES with 128-bit keys
unittest
{
    // AES128 requires a key of length 16 bytes.
    static immutable KEY = "asdfghjklqwertyu";

    testAES!(AES128, KEY)();
}

public alias GcryptNoIV!(Algorithm.GCRY_CIPHER_AES192, Mode.GCRY_CIPHER_MODE_ECB) AES192;

/// Usage example of AES with 192-bit keys
unittest
{
    // AES192 requires a key of length 24 bytes.
    static immutable KEY = "abcdefghijklmnopqrstuvwx";

    testAES!(AES192, KEY);
}

public alias GcryptNoIV!(Algorithm.GCRY_CIPHER_AES256, Mode.GCRY_CIPHER_MODE_ECB) AES256;

/// Usage example of AES with 256-bit keys
unittest
{
    // AES256 requires a key of length 32 bytes.
    static immutable KEY = "abcdefghijklmnopqrstuvwxyz012345";

    testAES!(AES256, KEY);
}

/*******************************************************************************

    Gcrypt with AES with mode CBC.

    See usage example in unittest below.

*******************************************************************************/

public alias GcryptWithIV!(Algorithm.GCRY_CIPHER_AES, Mode.GCRY_CIPHER_MODE_CBC) AES128_CBC;

/// Usage example of AES-CBC with 128-bit keys
unittest
{
    // AES128-CBC requires a key of length 16 bytes.
    static immutable KEY = "asdfghjklqwertyu";

    // AES128-CBC requires an IV of length 16 bytes.
    static immutable IV = "0123456789ABCDEF";

    testAES_IV!(AES128_CBC, KEY, IV);
}

public alias GcryptWithIV!(Algorithm.GCRY_CIPHER_AES192, Mode.GCRY_CIPHER_MODE_CBC) AES192_CBC;

/// Usage example of AES-CBC with 192-bit keys
unittest
{
    // AES192-CBC requires a key of length 24 bytes.
    static immutable KEY = "abcdefghijklmnopqrstuvwx";

    // AES192-CBC requires an IV of length 16 bytes.
    static immutable IV = "0123456789ABCDEF";

    testAES_IV!(AES192_CBC, KEY, IV);
}

public alias GcryptWithIV!(Algorithm.GCRY_CIPHER_AES256, Mode.GCRY_CIPHER_MODE_CBC) AES256_CBC;

/// Usage example of AES-CBC with 256-bit keys
unittest
{
    // AES256-CBC requires a key of length 32 bytes.
    static immutable KEY = "abcdefghijklmnopqrstuvwxyz012345";

    // AES256-CBC requires an IV of length 16 bytes.
    static immutable IV = "0123456789ABCDEF";

    testAES_IV!(AES256_CBC, KEY, IV);
}

version ( UnitTest )
{
    import ocean.core.Test;

    void testAES ( Cipher, istring str_key ) ( )
    {
        auto key = cast(Immut!(ubyte)[])str_key;

        // Test that only keys of the provided length are allowed
        Cipher.testFixedKeyLength(key);

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

    void testAES_IV ( Cipher, istring str_key, istring str_iv ) ( )
    {
        auto key = cast(Immut!(ubyte)[])str_key;
        auto iv = cast(Immut!(ubyte)[])str_iv;

        // Test that only keys of the provided length are allowed
        Cipher.testFixedKeyLength(key);

        // AES operates on 16-byte blocks;
        istring text = "Length divide 16";
        mstring encrypted_text, decrypted_text;

        // Create the class.
        auto cipher = new Cipher(key);

        // encryption/decryption is done in place so first copy the plain text
        // to a buffer
        encrypted_text ~= text;

        // The actual encryption
        cipher.encrypt(encrypted_text, iv);

        // Since decryption is done in place we copy the decrypted string to a
        // new buffer.
        decrypted_text ~= encrypted_text;

        // The decryption call.
        cipher.decrypt(decrypted_text, iv);

        // We have now successfully encrypted and decrypted a string.
        test!("==")(text, decrypted_text);
    }
}
