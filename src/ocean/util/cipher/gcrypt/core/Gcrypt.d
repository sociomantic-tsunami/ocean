/*******************************************************************************

    Templates for gcrypt algorithms

    Requires linking with libgcrypt:
            -L-lgcrypt

    See_Also:
        https://gnupg.org/documentation/manuals/gcrypt/index.html

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

        Bear in mind this module provides bindings to an external library that
        has its own license, which might be more restrictive. Please check the
        external library license to see which conditions apply for linking.

*******************************************************************************/

module ocean.util.cipher.gcrypt.core.Gcrypt;

import ocean.core.Verify;
import ocean.meta.types.Qualifiers;
import ocean.util.cipher.gcrypt.c.gcrypt;

version (unittest)
{
    import ocean.core.Test;
}


/*******************************************************************************

    Alias for the libgcrypt algorithm

*******************************************************************************/

public alias gcry_cipher_algos Algorithm;

/*******************************************************************************

    Alias for the libgcrypt modes

*******************************************************************************/

public alias gcry_cipher_modes Mode;


/*******************************************************************************

    Reusable exception class

*******************************************************************************/

public class GcryptException : Exception
{
    import ocean.core.Exception;
    import ocean.text.util.StringC;
    import ocean.util.cipher.gcrypt.c.gcrypt;

    /***************************************************************************

        Mixin the reusable exception parts

    ***************************************************************************/

    mixin ReusableExceptionImplementation!();

    /***************************************************************************

        Throw if variable error indicates an error. The exception message is
        set to contain the error from libgcrypt.

        Params:
            error = error code from gcrypt
            file = file from which this exception can be thrown
            line = line from which this exception can be thrown

        Throws:
            this if error != 0

    ***************************************************************************/

    public void throwIfGcryptError ( gcry_error_t error,
                                     istring file = __FILE__,
                                     int line = __LINE__  )
    {
        if ( error )
        {
            this.setGcryptErrorMsg(error, file, line);
            throw this;
        }
    }

    /***************************************************************************

        Throw if len != expected, with exception message explaining
        the issue.

        Params:
            id = identifier for message formatting
            len = actual length
            expected = expected length
            file = file from which this exception can be thrown
            line = line from which this exception can be thrown

        Throws:
            this if iv_length != block_size

    ***************************************************************************/

    public void throwIfLenMismatch ( cstring id, size_t len,
                                     size_t expected,
                                     istring file = __FILE__,
                                     int line = __LINE__  )
    {
        if ( len != expected )
        {
            this.set(id, file, line)
                .append(` length is: `)
                .append(len)
                .append(` but needs to be `)
                .append(expected);
            throw this;
        }
    }

    /***************************************************************************

        Throws a new instance of this class if `error` indicates an error. The
        exception message is set to contain the error from libgcrypt.

        Params:
            error = error code from gcrypt
            file = file from which this exception can be thrown
            line = line from which this exception can be thrown

        Throws:
            a new instance of this class if error != 0

    ***************************************************************************/

    public static void throwNewIfGcryptError ( gcry_error_t error,
                                               istring file = __FILE__,
                                               int line = __LINE__ )
    {
        if (error)
        {
            auto e = new typeof(this);
            e.setGcryptErrorMsg(error, file, line);
            throw e;
        }
    }

    /***************************************************************************

        Set the exception message to contain the error from libgcrypt.

        Params:
            error = error code from gcrypt
            file = file from which this exception can be thrown
            line = line from which this exception can be thrown

    ***************************************************************************/

    private void setGcryptErrorMsg ( gcry_error_t error,
                                     istring file = __FILE__,
                                     int line = __LINE__  )
    {
        this.set(`Error: "`, file, line)
            .append(StringC.toDString(gcry_strerror(error)))
            .append(`" Source: "`)
            .append(StringC.toDString(gcry_strsource(error)))
            .append(`"`);
    }
}

/*******************************************************************************

    Gcrypt algorithm base class template.

    Params:
        algorithm = algorithm which this class uses for en/decryption
        mode  = algorithm mode which this class uses for en/decryption

    (The algorithm and mode are provided as template arguments, rather than
    run-time arguments to the constructor, because it's useful to provide static
    methods which return information about the algorithm (required_key_len(),
    for example).)

*******************************************************************************/

private class GcryptBase ( Algorithm algorithm, Mode mode )
{
    /***************************************************************************

        Gcrypt handle. Set by the call to gcry_cipher_open() in the ctor, if
        successful.

    ***************************************************************************/

    protected gcry_cipher_hd_t handle;

    /***************************************************************************

        Reusable exception

    ***************************************************************************/

    protected GcryptException exception;

    /***************************************************************************

        Constructs the class and sets gcrypt to use the specified algorithm,
        mode, and key.

        Params:
            key = the key to use.

        Throws:
            A GcryptException if gcrypt fails to open or the key fails to be set

    ***************************************************************************/

    public this ( in void[] key )
    {
        this.exception = new GcryptException;

        with ( gcry_ctl_cmds )
        {
            // We don't need secure memory
            auto err = gcry_control(GCRYCTL_DISABLE_SECMEM, 0);
            this.exception.throwIfGcryptError(err);

            err = gcry_control(GCRYCTL_INITIALIZATION_FINISHED, 0);
            this.exception.throwIfGcryptError(err);
        }

        // Open gcrypt with specified algorithm and mode
        uint flags = 0;
        auto err = gcry_cipher_open(&this.handle, algorithm, mode, flags);
        this.exception.throwIfGcryptError(err);

        // Set the key, since we don't call gcrypt's reset function we only need
        // to do this once.
        this.setKey(key);
    }

    /***************************************************************************

        Destructor; closes gcrypt

    ***************************************************************************/

    ~this ( )
    {
        if ( this.handle !is null )
            this.close();
    }

    /***************************************************************************

        Returns:
            required length of encryption key (in bytes) for this algorithm.
            If the algorithm supports multiple key lengths, the maximum
            supported value is returned.

    ***************************************************************************/

    public static size_t required_key_len ( )
    out ( blk_len )
    {
        assert(blk_len != 0);
    }
    body
    {
        return gcry_cipher_get_algo_keylen(algorithm);
    }

    /***************************************************************************

        Returns:
            required length of one block (in bytes) for this algorithm

    ***************************************************************************/

    public static size_t required_blk_len ( )
    out ( key_len )
    {
        assert(key_len != 0);
    }
    body
    {
        return gcry_cipher_get_algo_blklen(algorithm);
    }

    /***************************************************************************

        Relinquishes the gcrypt instance used internally. It is not possible to
        use any methods of this instance after calling this method -- only call
        this when you are certain that you're finished.

    ***************************************************************************/

    public void close ( )
    {
        gcry_cipher_close(this.handle);
        this.handle = null;
    }

    /***************************************************************************

        Set the key to use.

        Params:
            key = the encryption key

        Throws:
            A GcryptException if the key failed to be set

    ***************************************************************************/

    protected void setKey ( in void[] key )
    {
        auto err = gcry_cipher_setkey(this.handle, key.ptr, key.length);
        this.exception.throwIfGcryptError(err);
    }

    /***************************************************************************

        Unittests for the class. Note that as this class is a template, the
        unittests will not be run unless it is instantiated (see modules in
        ocean.util.cipher.gcrypt).

    ***************************************************************************/

    version (unittest)
    {
        /***********************************************************************

            Helper function to generate a void[] of the specified length, filled
            with bytes of incrementing value.

            Params:
                length = number of bytes to generate

            Returns:
                void[] containing the specified number of bytes, with
                incrementing values

        ***********************************************************************/

        private static void[] generateString ( size_t length )
        {
            auto str = new ubyte[length];
            ubyte i;
            foreach ( ref v; str )
            {
                v = i++;
            }
            return str;
        }

        /***********************************************************************

            Helper function to generate a void[] suitable for use as a key in
            unittests.

            Returns:
                void[] of the correct length for a key

        ***********************************************************************/

        public static void[] generateKey ( )
        {
            return generateString(typeof(this).required_key_len);
        }

        /***********************************************************************

            Helper function to generate a char[] suitable for use as a message
            to encrypt in unittests. For compatibility with certain algorithms,
            a message of the defined block-length is generated.

            Returns:
                char[] of the correct length

        ***********************************************************************/

        public static char[] generateMessage ( )
        {
            auto length = typeof(this).required_blk_len;
            auto str = new char[length];
            char i = 'a';
            foreach ( ref v; str )
            {
                v = i++;
            }
            return str;
        }

        /***********************************************************************

            Tests that the algorithm accepts a key of the correct length and
            rejects keys of invalid lengths.

            Some algorithms have possible key length (e.g. 128 or 256 bits),
            while other algorithms have ranges of key length (e.g. Blowfish
            allows for keys from 32 to 448 bits).
            For algorithms with a fixed key length, it is recommended to call
            this function from an unittest.

            Params:
                key = Key to use for test.
                      This function will ensure that a larger and smaller key
                      (by 1) triggers an error, while the provided key doesn't.
                      Make sure to pass a key which is not weak (e.g. a default
                      initialized slice), as gcrypt errors on them.

        ***********************************************************************/

        public static void testFixedKeyLength (const(ubyte)[] key)
        {
            // Too short should fail
            testThrown!(GcryptException)(new typeof(this)(key[0 .. $-1]));

            // Too long should fail
            key.length = key.length + 1;
            testThrown!(GcryptException)(new typeof(this)(key));
            key.length = key.length - 1;

            scope works = new typeof(this)(key);
        }
    }
}

/*******************************************************************************

    Gcrypt algorithm template for algorithms with initialization vectors.

    Params:
        algorithm = algorithm which this class uses for en/decryption
        mode = algorithm mode which this class uses for en/decryption

*******************************************************************************/

public class GcryptWithIV ( Algorithm algorithm, Mode mode )
    : GcryptBase!(algorithm, mode)
{
    /***************************************************************************

        Constructor

        Params:
            key = the key to use.

        Throws:
            A GcryptException if gcrypt fails to open or the key fails to be set

    ***************************************************************************/

    public this ( in void[] key )
    {
        super(key);
    }

    /***************************************************************************

        Encrypt the content of buffer in place.

        Params:
            buffer = the content to be encrypted in place
            iv = the initialisation vector to use

        Throws:
            if setting the init vector or the encryption fails

    ***************************************************************************/

    public void encrypt ( mstring buffer, in void[] iv )
    {
        verify(this.handle !is null);

        if ( !buffer.length )
            return;

        this.setInitVector(iv);

        auto err =
            gcry_cipher_encrypt(this.handle, buffer.ptr, buffer.length, null, 0);
        this.exception.throwIfGcryptError(err);
    }

    /***************************************************************************

        Decrypt the content of buffer in place.

        Params:
            buffer = the content to be decrypted in place
            iv = the initialisation vector to use

        Throws:
            if setting the init vector or the decryption fails

    ***************************************************************************/

    public void decrypt ( mstring buffer, in void[] iv )
    {
        verify(this.handle !is null);

        if ( !buffer.length )
            return;

        this.setInitVector(iv);

        auto err =
            gcry_cipher_decrypt(this.handle, buffer.ptr, buffer.length, null, 0);
        this.exception.throwIfGcryptError(err);
    }

    /***************************************************************************

        Returns:
            required length of initialisation vector (in bytes) for this
            algorithm. Note that, if called for an algorithm which does not
            require an IV, the return value will be undefined.

    ***************************************************************************/

    public static size_t required_iv_len ( )
    out ( iv_len )
    {
        assert(iv_len != 0);
    }
    body
    {
        return gcry_cipher_get_algo_blklen(algorithm);
    }

    /***************************************************************************

        Set the initialization vector to use.

        Params:
            iv = the initialization vector

        Throws:
            A GcryptException if the initialization vector failed to be set

    ***************************************************************************/

    protected void setInitVector ( in void[] iv )
    {
        this.exception.throwIfLenMismatch("iv", iv.length, this.required_iv_len);

        auto err = gcry_cipher_setiv(this.handle, iv.ptr, iv.length);
        this.exception.throwIfGcryptError(err);
    }

    /***************************************************************************

        IV-using algorithm-specific unittest resources

    ***************************************************************************/

    version (unittest)
    {
        /***********************************************************************

            Helper function to generate a void[] suitable for use as an IV in
            unittests.

            Returns:
                void[] of the correct length for an IV

        ***********************************************************************/

        public static void[] generateIV ( )
        {
            return generateString(typeof(this).required_iv_len);
        }
    }

    /***************************************************************************

        Test that only initialisation vectors of the correct length are
        acceptable.

    ***************************************************************************/

    unittest
    {
        auto key = generateKey();
        auto iv = generateIV();

        auto crypt = new typeof(this)(key);

        auto buf = generateMessage();

        // Too short should fail
        testThrown!(GcryptException)(crypt.encrypt(buf, iv[0 .. $-1]));

        // Too long should fail
        iv.length = iv.length + 1;
        testThrown!(GcryptException)(crypt.encrypt(buf, iv));
        iv.length = iv.length - 1;

        // The correct length should succeed
        crypt.encrypt(buf, iv);
    }

    /***************************************************************************

        Test encrypting and decrypting a short value.

    ***************************************************************************/

    unittest
    {
        auto key = generateKey();
        auto iv = generateIV();

        auto crypt = new typeof(this)(key);

        auto original = generateMessage();
        mstring buf;
        buf ~= original;

        // Encrypt buf in place
        crypt.encrypt(buf, iv);
        test!("!=")(buf, original);

        // Decrypt buf in place
        crypt.decrypt(buf, iv);
        test!("==")(buf, original);
    }

    /***************************************************************************

        Test that setting an IV does affect the outcome of encryption.

    ***************************************************************************/

    unittest
    {
        auto key = generateKey();

        auto crypt = new typeof(this)(key);

        auto original = generateMessage();
        mstring buf;
        buf ~= original;

        // Encrypt buf in place
        auto iv = generateIV();
        crypt.encrypt(buf, iv);

        // Encrypt with a different IV and test that is not the same as before
        mstring buf2;
        buf2 ~= original;
        auto iv2 = generateIV();
        foreach ( ref b; cast(ubyte[])iv2 )
        {
            b++;
        }
        crypt.encrypt(buf2, iv2);

        test!("!=")(buf, buf2);
    }
}

/*******************************************************************************

    Gcrypt algorithm template for algorithms without initialization vectors.

    Params:
        algorithm = algorithm which this class uses for en/decryption
        mode = algorithm mode which this class uses for en/decryption

*******************************************************************************/

public class GcryptNoIV ( Algorithm algorithm, Mode mode )
    : GcryptBase!(algorithm, mode)
{
    /***************************************************************************

        Constructor

        Params:
            key = the key to use.

        Throws:
            A GcryptException if gcrypt fails to open or the key fails to be set

    ***************************************************************************/

    public this ( in void[] key )
    {
        super(key);
    }

    /***************************************************************************

        Encrypt the content of buffer in place.

        Params:
            buffer = the content to be encrypted in place

        Throws:
            if the encryption fails

    ***************************************************************************/

    public void encrypt ( mstring buffer )
    {
        verify(this.handle !is null);

        if ( !buffer.length )
            return;

        auto err =
            gcry_cipher_encrypt(this.handle, buffer.ptr, buffer.length, null, 0);
        this.exception.throwIfGcryptError(err);
    }

    /***************************************************************************

        Decrypt the content of buffer in place.

        Params:
            buffer = the content to be decrypted in place

        Throws:
            if the decryption fails

    ***************************************************************************/

    public void decrypt ( mstring buffer )
    {
        verify(this.handle !is null);

        if ( !buffer.length )
            return;

        auto err =
            gcry_cipher_decrypt(this.handle, buffer.ptr, buffer.length, null, 0);
        this.exception.throwIfGcryptError(err);
    }

    /***************************************************************************

        Test encrypting and decrypting a short value.

    ***************************************************************************/

    unittest
    {
        auto key = generateKey();

        auto crypt = new typeof(this)(key);

        auto original = generateMessage();
        mstring buf;
        buf ~= original;

        // Encrypt buf in place
        crypt.encrypt(buf);
        test!("!=")(buf, original);

        // Decrypt buf in place
        crypt.decrypt(buf);
        test!("==")(buf, original);
    }

    /***************************************************************************

        Test that encrypting a value after setting an IV gives the same result
        as not setting an IV. For these algorithms, the IV should not be used.

    ***************************************************************************/

    unittest
    {
        auto key = generateKey();

        auto crypt = new typeof(this)(key);

        auto original = generateMessage();
        mstring buf;
        buf ~= original;

        // Encrypt buf in place
        crypt.encrypt(buf);

        // Generate and set an IV
        auto iv = generateMessage();
        gcry_cipher_setiv(crypt.handle, iv.ptr, iv.length);

        // Encrypt another buf in place and test that is the same as before
        mstring buf2;
        buf2 ~= original;
        crypt.encrypt(buf2);

        test!("==")(buf, buf2);
    }
}
