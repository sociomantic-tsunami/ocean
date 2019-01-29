/******************************************************************************

    C binding to OpenSSL v1.0.x

    The OpenSSL library is very large. This binding includes only a tiny
    fraction of the available functions.

    copyright: Copyright (c) 2018 dunnhumby Germany GmbH. All rights reserved

*******************************************************************************/

module ocean.net.ssl.openssl.OpenSsl;


import core.stdc.config : c_ulong, c_long;
import ocean.transition;


extern (C):

/*******************************************************************************

    Opaque struct which contains function pointers for SSLv2 or
    SSLv3/TLSv1 functions. This is roughly equivalent to a virtual function
    table, but implemented in plain C.

*******************************************************************************/

public struct ssl_method_st;


/*******************************************************************************

    Opaque struct which implements an SSL connection

*******************************************************************************/

public struct SSL;


/*******************************************************************************

    Opaque struct which implements an SSL connection context

*******************************************************************************/

public struct SSL_CTX;


/*******************************************************************************

    Opaque struct which implements an X509 certificate

*******************************************************************************/

public struct X509;


/*******************************************************************************

    The context used wile verifying an X509 certificate

*******************************************************************************/

public struct X509_STORE_CTX;


/*******************************************************************************

    Opaque struct which holds RSA encryption parameters

*******************************************************************************/

public struct RSA;


/*******************************************************************************

    Opaque struct which holds a message digest

*******************************************************************************/

public struct EVP_MD;


/*******************************************************************************

    Opaque struct which holds a message digest context

*******************************************************************************/

public struct EVP_MD_CTX;


/*******************************************************************************

    Opaque struct which holds a private key

*******************************************************************************/

public struct EVP_PKEY;


/*******************************************************************************

    Opaque struct which holds a private key context

*******************************************************************************/

public struct EVP_PKEY_CTX;


/*******************************************************************************

    Opaque struct which holds a digest encryption engine

*******************************************************************************/

public struct ENGINE;


/*******************************************************************************

    Retrieve the function pointers for SSLv3, or v2 if v3 is unavailable

    Returns;
        A struct with all of the function pointers pointing to the SSL v3
        functions, falling back to v2 if v3 is unavailable

*******************************************************************************/

public ssl_method_st* SSLv23_method ();


/*******************************************************************************

    Initialize the SSL library by registering algorithms

    Returns:
        Always returns 1.

*******************************************************************************/

public int SSL_library_init ();


/*******************************************************************************

    Registers the error strings for all libcrypto and libssl function

*******************************************************************************/

public void  SSL_load_error_strings ();


/*******************************************************************************

    Obtains a human-readable error message

    Params:
        e = the error code

    Returns:
        A human-readable string representing the error code.

*******************************************************************************/

public Const!(char *) ERR_reason_error_string (c_ulong e);


/*******************************************************************************

    Empties the current thread's error queue.

*******************************************************************************/

public void ERR_clear_error ();


/*******************************************************************************

    Returns the earliest error code from the thread's error queue and
    removes the entry. This function can be called repeatedly until there
    are no more error codes to return.

*******************************************************************************/

public c_ulong ERR_get_error ();


/*******************************************************************************

    Obtains the result code for a TLS/SSL I/O operation.

    Gets a result code for a preceding call to SSL_connect, SSL_accept,
    SSL_do_handshake, SSL_read, SSL_read_ex, SSL_peek, SSL_peek_ex,
    SSL_write, or SSL_writex.

    The OpenSSL interface is rather brittle.
    The current thread's error queue must be empty before the call is made,
    and no other OpenSSL calls should be made before calling SSL_get_error.

    Params:
        ssl = the ssl object which was used to perform the call
        ret = the value which was returned by the call.

*******************************************************************************/

public int SSL_get_error (Const!(SSL)* ssl, int ret);


/*******************************************************************************

    Creates a new SSL object for a connection.

    The new structure inherits the settings of the underlying context ctx.

    Params:
        ctx = the SSL context

    Returns:
        an allocated SSL object, or null if creation failed.

*******************************************************************************/

public SSL* SSL_new (SSL_CTX* ctx);


/*******************************************************************************

    Sets the file descriptor for the SSL object

    The new structure inherits the settings of the underlying context ctx.

    Params:
        ssl = the SSL object
        fd = the file descriptor to be used for I/O operations

    Returns:
        1 on success, 0 if the operation failed.

*******************************************************************************/

public int SSL_set_fd (SSL* ssl, int fd);


/*******************************************************************************

    Sets the SSL object to work in client mode

    Params:
        ssl = the ssl object

*******************************************************************************/

public void SSL_set_connect_state (SSL* ssl);


/*******************************************************************************

    Sets the SSL object to work in server mode

    Params:
        ssl = the ssl object

*******************************************************************************/

public void SSL_set_accept_state (SSL* ssl);


/*******************************************************************************

    Start an SSL handshake

    If the object is blocking, the function will return only once the
    handshake is complete. If it is non-blocking, it will return with a
    negative value which specifies the next action required.

    Params:
        ssl = the ssl object

    Returns:
        1 if the handshake succeeded. Any value <= 0 should be passed to
        SSL_get_error to find the reason why the connection is not complete.

*******************************************************************************/

public int SSL_do_handshake (SSL* ssl);


/*******************************************************************************

    Creates a new  SSL_CTX object as framework to establish TLS/SSL or DTLS
    enabled connections.

    The object must be freed using SSL_CTX_free. It is reference counted,
    so it will only be deleted when the reference count drops to zero.

    Params:
        meth = the SSL/TLS connection methods to use

    Returns:
        an allocated SSL_CTX object, or null if creation failed.

*******************************************************************************/

public SSL_CTX* SSL_CTX_new (Const!(ssl_method_st)* meth);


/*******************************************************************************

    Frees memory and resources associated with the SSL_CTX object.

    Params:
        ctx = SSL_CTX object to be released

*******************************************************************************/

public void SSL_CTX_free (SSL_CTX* ctx);


/*******************************************************************************

    Writes bytes to an SSL connection

    Params:
        ssl = the SSL connection
        buf = buffer containing bytes to be written
        num = the number of bytes to be written

    Returns:
        the number of bytes written to the SSL connection, or 0 if the
        connection was closed, or a negative value if an error occurred or
        if action must be taken by the calling process.

*******************************************************************************/

public int SSL_write (SSL *ssl, Const!(void*) buf, int num);


/*******************************************************************************

    Read bytes from an SSL connection

    Params:
        ssl = the SSL connection
        buf = buffer containing bytes to be written
        num = the number of bytes to be written

    Returns:
        the number of bytes written to the SSL connection, or 0 if the
        connection was closed, or a negative value if an error occurred or
        action must be taken by the calling process.

*******************************************************************************/

public int SSL_read (SSL* ssl, void* buf, int num);


/*******************************************************************************

    Sets the verification parameters for an SSL context

    Params:
        ctx = the SSL context to be set
        mode = the verification flags to use. For a client, this must be
            SSL_VERIFY_NONE or SSL_VERIFY_PEER.
        callback = the verification callback to use when mode is set to
            SSL_VERIFY_PEER, or null to use the default callback

*******************************************************************************/

public void SSL_CTX_set_verify (SSL_CTX* ctx, int mode,
    int function (int, X509_STORE_CTX*) callback);


/*******************************************************************************

    Sets the maxiumum depth for certificate chain verification

    Params:
        ctx = the SSL context for which the depth should be set
        depth = The maximum depth to be allowed

*******************************************************************************/

public void SSL_CTX_set_verify_depth (SSL_CTX* ctx, int depth);


/*******************************************************************************

    Specifies the locations for ctx, at which CA certificates for
    verification purposes are located. The certificates available via
    CAfile and CApath are trusted.

    When looking up CA certificates, the OpenSSL library will first search
    the certificates in CAfile, then those in CApath.

    Params:
        ctx = the CTX
        CAfile = pointer to a file of CA certificates in PEM format, or
            null. The file can containe several CA certificates.
        CApath = a directory containing CA certificates in PEM format

    Returns:
        0 if the operation fails, 1 if the operation was successful

*******************************************************************************/

public int SSL_CTX_load_verify_locations (SSL_CTX* ctx,
    Const!(char*) CAfile, Const!(char*) CApath);


/*******************************************************************************

    Get the result of peer certficate verification

    Params:
        ssl = the SSL object which obtained the peer certificate

    Returns:
        X509_V_OK if the verification succeeded or no peer certificate was
        presented, ot an error code if the verification failed.

*******************************************************************************/

public c_long SSL_get_verify_result (Const!(SSL)* ssl);


/*******************************************************************************

    Sets the list of available ciphers

    Sets the list of available ciphers (TLS v1.2 and below). For TLSv1.3,
    this function has no effect; call SSL_set_ciphersuites instead.

    Params:
        ssl = the SSL object to set the cipher list for
        str = a colon-delimited sequence of cipher names

    Returns:
        1 if any cipher could be selected, 0 on complete failure

*******************************************************************************/

public int SSL_set_cipher_list (SSL* ssl, Const!(char*) str);


/*******************************************************************************

    Internal function used to manipulate settings of an SSL object.
    Should never be called directly.

    Params:
        ctx = the SSL object to manipulate
        cmd = the command to execute
        larg = an integer argument to the command
        parg = a pointer argument to the command

    Returns:
        an integer whose meaning depends on the value of cmd

*******************************************************************************/

private c_long SSL_ctrl (SSL* ssl,int cmd, c_long larg, void* parg);


/*******************************************************************************

    Internal function used to manipulate settings of an SSL Context object.
    Should never be called directly.

    Params:
        ctx = the SSL context to manipulate
        cmd = the command to execute
        larg = an integer argument to the command
        parg = a pointer argument to the command

    Returns:
        an integer whose meaning depends on the value of cmd

*******************************************************************************/

private c_long SSL_CTX_ctrl (SSL_CTX* ctx, int cmd, c_long larg, void* parg);


/*******************************************************************************

    Allocates and initializes an X509 structure

    Returns:
        The newly-allocated structure, or null if allocation fails, in which
        case ERR_get_error can be used to obtain the error code.

*******************************************************************************/

public X509* X509_new ();


/*******************************************************************************

    Frees an X509 structure

    Params:
        a = the X509 object to free

*******************************************************************************/

public void X509_free (X509* a);


/*******************************************************************************

    Gets the X509 certificate of the peer

    Params:
        s = the SSL object

    Returns:
        A pointer to the X509 certificate which the peer presented

*******************************************************************************/

public X509* SSL_get_peer_certificate (Const!(SSL)* s);


/*******************************************************************************

    Sets up the digest context for generating a signature

    For some key types and parameters the random number generator must be
    seeded or the operation will fail.

    Params:
        ctx = context, must have been created with EVP_MD_CTX_new()
        pctx = if not null, then the pkey context will be copied here
        type = the message digest algorithm that will be used
        e = the digest engine to use. May be null for some algorithms
        pkey = the private key

    Returns:
        1 on success, 0 or negative for failure, -2 if the operation is not
        supported by the publuc key algorithm

*******************************************************************************/

public int EVP_DigestSignInit (EVP_MD_CTX* ctx, EVP_PKEY_CTX** pctx,
                    Const!(EVP_MD)* type, ENGINE* e, EVP_PKEY* pkey);


/*******************************************************************************

    Hashes data into a digest context, to update a signature

    This function can be called multiple times on the same ctx to hash
    additional data.

    Params:
        ctx = the digest context containing the hash
        d = pointer to the start of the data to be hashed
        cnt = the number of bytes of data to be hashed

    Returns:
        1 on success. 0 for failure

*******************************************************************************/

public int EVP_DigestUpdate (EVP_MD_CTX* ctx, Const!(void)* d, size_t cnt);


/*******************************************************************************

    Generates a signature for the data in the message digest context

    Typically this function will be called twice, firstly to determine the
    length of the signature, and secondly to retrieve the signature.

    Params:
        ctx = the message digest context
        signature = buffer where the signature should be written, or null
        sig_len = the length of the buffer, if sig is not null.
        e = the engine to use
        pkey = the private key

    Returns:
        1 on success. 0 or negative for failure

*******************************************************************************/

public int EVP_DigestSignFinal (EVP_MD_CTX* ctx, Const!(void)* signature,
    size_t* sig_len);


/*******************************************************************************

    Allocates, initializes and returns a message digest context.

    Returns:
        An initialized message digest context

*******************************************************************************/

public EVP_MD_CTX* EVP_MD_CTX_create ();


/*******************************************************************************

    Cleans up digest context ctx and frees up the space allocated to it.
    Should be called only on a context created using EVP_MD_CTX_create().

    Params:
        ctx = the context to be destroyed

*******************************************************************************/

public void EVP_MD_CTX_destroy (EVP_MD_CTX *ctx);


/*******************************************************************************

    Allocates an empty EVP_PKEY structure, which is used to store public and
    private keys

    Returns:
        An empty key with a reference count of 1, or null if an error
        occurred.

*******************************************************************************/

public EVP_PKEY* EVP_PKEY_new ();


/*******************************************************************************

    Frees an EVP_PKEY structure

    Decrements the reference count of key, and frees if it the reference
    count has dropped to zero.

    Params:
        key = the key to be freed

*******************************************************************************/

public void EVP_PKEY_free (EVP_PKEY* key);


/*******************************************************************************

    Sets the key referenced by pkey to rsa

    Params:
        pkey = the key to be set
        rsa = the rsa key to use

    Returns:
        1 on success, 0 on failure

*******************************************************************************/

public int EVP_PKEY_set1_RSA (EVP_PKEY* pkey, RSA* rsa);


/*******************************************************************************

    Returns an EVP_MD structure for the SHA256 digest algorithm

    Returns:
        A pointer to the EVP_MD structure.

*******************************************************************************/

public Const!(EVP_MD)* EVP_sha256 ();


/*******************************************************************************

    Allocates and initializes an RSA structure

    Returns:
        the initialized structure, or null if allocation fails.

*******************************************************************************/

public RSA* RSA_new ();


/*******************************************************************************

    Frees an RSA structure

    Params:
        rsa = the RSA structure to be freed

    Returns:
        1 on success. No other return values are documented.

*******************************************************************************/

public void RSA_free (RSA* rsa);


/*******************************************************************************

    Decodes a PKCS#1 RSAPrivateKey structure

    This function should never be called directly. The documentation
    includes three pages of warnings, caveats, and bugs, noting that unless
    great care is taken with the parameters, this function causes segfaults
    and/or internal memory corruption.

    Use decodeRSAPrivateKey() instead.

*******************************************************************************/

private RSA* d2i_RSAPrivateKey (RSA** ptr_to_ptr_which_must_be_null,
    Const!(void)** ptr_to_ptr_which_gets_corrupted, c_long len);



/*******************************************************************************

    SSL error codes

*******************************************************************************/

public enum
{
    SSL_ERROR_NONE = 0,
    SSL_ERROR_SSL  = 1,
    SSL_ERROR_WANT_READ = 2,
    SSL_ERROR_WANT_WRITE = 3,
    SSL_ERROR_WANT_X509_LOOKUP = 4,
    SSL_ERROR_SYSCALL = 5,
    SSL_ERROR_ZERO_RETURN = 6,
    SSL_ERROR_WANT_CONNECT = 7,
    SSL_ERROR_WANT_ACCEPT = 8
}


/*******************************************************************************

    Enum used by SSL_CTX_set_verify

*******************************************************************************/

public enum
{
    SSL_VERIFY_NONE = 0,
    SSL_VERIFY_PEER = 1
}


/*******************************************************************************

    Options used by SSL_CTX_set_options

*******************************************************************************/

public enum : ulong
{
    SSL_OP_ALL = 0x80000BFFL, /// Various workarounds for broken implementations
    SSL_OP_NO_SSLv2 = 0x01000000,  /// Do not use SSL v2
    SSL_OP_NO_SSLv3 = 0x02000000,   /// Do not use SSL v3.
    SSL_OP_NO_COMPRESSION = 0x00020000  /// Do not use compression
}


extern (D):

/*******************************************************************************

    Adds the options to the SSL context. Options already set before are not
    cleared.

    Params:
        ctx = the SSL context
        op = the option flags to set.

    Returns:
        The new options bitmask, after adding options.

*******************************************************************************/

public c_long SSL_CTX_set_options (SSL_CTX* ctx, c_long op)
{
    static immutable SSL_CTRL_OPTIONS = 32;

    return SSL_CTX_ctrl(ctx, SSL_CTRL_OPTIONS, op, null);
}


/*******************************************************************************

    Decodes a PKCS#1 RSAPrivateKey structure, creating an RSA object

    Params:
        key = the bytes to decode

    Returns:
        A decoded structure, or null if an error occurs.

*******************************************************************************/

public RSA * decodeRSAPrivateKey (Const!(void)[] key)
{
    // If this isn't null, memory corruption will happen

    RSA * rsa = null;

    // This variable gets corrupted by the call

    auto keyptr = key.ptr;

    return d2i_RSAPrivateKey(&rsa, &keyptr, key.length);
}
