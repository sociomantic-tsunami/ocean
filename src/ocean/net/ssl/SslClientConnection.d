/******************************************************************************

    Task-based implementation of an SSL connection

    copyright: Copyright (c) 2018 dunnhumby Germany GmbH. All rights reserved


    Usage example: See documented unittest of X.

*******************************************************************************/

module ocean.net.ssl.SslClientConnection;

import ocean.net.ssl.openssl.OpenSsl;
import ocean.text.util.StringC;
import ocean.meta.types.Qualifiers;



/***************************************************************************

    Global context used for all SSL connections

***************************************************************************/

private SSL_CTX * globalSslContext;



/***************************************************************************

    Class representing a single SSL client connection.
    Can only be called from inside a Task.

***************************************************************************/

public class SslClientConnection
{
    private import core.sys.posix.netdb : AF_UNSPEC, SOCK_STREAM;

    static import ocean.core.ExceptionDefinitions;

    private import ocean.io.select.protocol.task.TaskSelectClient;

    private import ocean.sys.socket.AddrInfo;

    private import ocean.sys.socket.model.ISocket;

    private import ocean.sys.Epoll: epoll_event_t;

    private alias epoll_event_t.Event Event;


    /***************************************************************************

        Exception class thrown on errors.

    ***************************************************************************/

    public static class SslException :
        ocean.core.ExceptionDefinitions.IOException
    {
        import ocean.core.Exception: ReusableExceptionImplementation;

        mixin ReusableExceptionImplementation!() ReusableImpl;

        /*******************************************************************

            Sets the exception instance.

            Params:
                file_path = path of the file
                func_name = name of the method that failed
                msg = message description of the error
                file = file where exception is thrown
                line = line where exception is thrown

        *******************************************************************/

        public typeof(this) set ( cstring host_path,
                istring func_name,
                cstring msg,
                istring file = __FILE__, long line = __LINE__)
        {
            this.error_num = error_num;
            this.func_name = func_name;

            this.ReusableImpl.set(this.func_name, file, line)
                .fmtAppend(": {} {} on {}", this.func_name, msg, host_path);

            return this;
        }
    }


    /***************************************************************************

        A minimal implementation of ISocket

    ***************************************************************************/

    private static class SimpleSocket : ISocket
    {
        public this ()
        {
            super (addrinfo.sizeof);
        }

        public override void formatInfo ( ref char[] buf, bool io_error )
        {

        }
    }

    /***************************************************************************

        The socket which is used for the connection

    ***************************************************************************/

    private SimpleSocket socket;


    /***************************************************************************

        The SSL connection

    ***************************************************************************/

    private SSL * sslHandle;


    /***************************************************************************

        SelectClient used for blocking the calling Task

    ***************************************************************************/

    private TaskSelectClient select_client;


    /***************************************************************************

        Instance of AddrInfor used for resolving host names

    ***************************************************************************/

    private AddrInfo addr_info;


    /***********************************************************************

        Reusable exception instance

    ***********************************************************************/

    private SslException exception;


    /***************************************************************************

        Constructor

    ***************************************************************************/

    public this ( )
    {
        this.addr_info = new AddrInfo();

        this.socket = new SimpleSocket();

        this.select_client = new TaskSelectClient(this.socket,
            &this.socket.error);

        this.exception = new SslException;
    }


    /***************************************************************************

        Create an SSL connection. Blocks the calling task until the handshake
        is complete.

        Params:
            host_name = the name of the host
            host_port = the port to use (eg "443" for an HTTPS connection)

        Throws:
            IOException if the connection failed

    ***************************************************************************/

    public void connect ( cstring host_name, cstring host_port )
    {
        // Resolve the host

        // We should be able to use AddrInfo.getIp but cannot because it doesn't
        // support AF_UNSPEC.

        auto addr_err = this.addr_info.get(host_name, host_port, AF_UNSPEC,
            SOCK_STREAM, 0);

        if ( addr_err != 0 )
        {
            this.ssl_error(host_name, "connect", gai_strerror(addr_err));
        }

        this.socket.socket(addr_info.info().ai_family,
            addr_info.info().ai_socktype | SocketFlags.SOCK_NONBLOCK,
            addr_info.info().ai_protocol);

        if ( !socket.connect(addr_info.info().ai_addr) )
        {
            this.error(host_name, "socket.connect", "Failed to connect");
        }

        this.sslHandle = SSL_new(globalSslContext);

        if ( !this.sslHandle )
        {
            this.error(host_name, "connect", "sslNew failed");
        }

        if (!SSL_set_fd(this.sslHandle, this.socket.fileHandle))
        {
            this.error(host_name, "connect", "sslSetFd failed");
        }

        // Set it into "connect" state, ie it is a client, not a server.
        // (For a server, SSL_set_accept_state would be called instead).

        SSL_set_connect_state(this.sslHandle);

        ERR_clear_error();

        int r;

        while ( (r = SSL_do_handshake(this.sslHandle)) != 1 )
        {
            int err = SSL_get_error(this.sslHandle, r);

            if ( err ==  SSL_ERROR_WANT_WRITE )
            {
                this.select_client.ioWait(Event.EPOLLOUT);
            }
            else if (err == SSL_ERROR_WANT_READ)
            {
                this.select_client.ioWait(Event.EPOLLIN);
            }
            else
            {
                this.error(host_name, "connect", "Handshake failed");
            }
        }
    }


    /***************************************************************************

        Write a string to the SSL connection

        The calling task is blocked until the write has completed.

        Params:
            request = the string to send

        Throws:
            IOException if the write failed

    ***************************************************************************/

    public void write ( cstring request )
    {
        int w;

        while ( (w = SSL_write(this.sslHandle, request.ptr,
            cast(int)request.length)) <= 0 )
        {
            auto err = SSL_get_error(this.sslHandle, w);

            // At any time, a renegotiation is possible, so a call to SSL_write
            // can also cause read operations.

            if ( err ==  SSL_ERROR_WANT_WRITE )
            {
                this.select_client.ioWait(Event.EPOLLOUT);
            }
            else if (err == SSL_ERROR_WANT_READ)
            {
                this.select_client.ioWait(Event.EPOLLIN);
            }
            else
            {
                // The write failed

                this.ssl_error("", "write", ERR_reason_error_string(err));
            }
        }

        if ( w != request.length )
        {
            this.error("", "write", "Mismatch in number of bytes written");

        }
    }


    /***************************************************************************

        Reads a string from the SSL connection

        The calling task is blocked until the read has completed.

        Params:
            buffer = array to store the string

        Returns:
            a slice into buffer of the bytes which were read.

        Throws:
            IOException if the read failed

    ***************************************************************************/

    public mstring read ( mstring buffer )
    {
        this.select_client.ioWait(Event.EPOLLIN);

        ERR_clear_error();

        int r;

        while ( (r = SSL_read(this.sslHandle, buffer.ptr,
            cast(int)buffer.length)) <= 0 )
        {
            auto err = SSL_get_error(this.sslHandle, r);

            // At any time, a renegotiation is possible, so a call to SSL_read
            // can also cause write operations.

            if ( err ==  SSL_ERROR_WANT_WRITE )
            {
                this.select_client.ioWait(Event.EPOLLOUT);
            }
            else if (err == SSL_ERROR_WANT_READ)
            {
                this.select_client.ioWait(Event.EPOLLIN);
            }
            else
            {
                // The read failed

                this.ssl_error("", "read", ERR_reason_error_string(err));
            }

        }
        return buffer[0 .. r];
    }


    /***************************************************************************

        Validate the X509 certificate.

        The relevant documents are RFC 5280 and RFC 6125.

        Params:
            host_name = the name of the host

        Throws:
            IOException if validation fails

    ***************************************************************************/

    public void validateCertificate (cstring host_name)
    {
        // Step 1. Verify that a server certificate was presented during
        // negotiation.

        if (X509* cert = SSL_get_peer_certificate(this.sslHandle))
        {
            X509_free(cert); // Free the certificate immediately
        }
        else
        {
            this.error(host_name, "SSL_get_peer_certificate",
                "No certificate was presented");
        }

        // Step 2: Verify the library default validation

        auto res = SSL_get_verify_result(this.sslHandle);

        if (res != 0)
        {
            this.ssl_error(host_name, "SSL_get_verify_result",
                ERR_reason_error_string(res));
        }

        // Step 3: hostname verification.
        // This was only necessary before OpenSSL 1.1.0.

        // Even if all three checks succeed, to properly ensure a secure
        // connection would require something like Trust-On-First-Use, as used
        // by SSH.
    }


    /*******************************************************************

        Throw a reusable IOException, with the provided
        message, function name and error code.

        Params:
            host_name = the host which was connected to
            func_name = name of the method that failed
            msg = message description of the error
            file = file where exception is thrown
            line = line where exception is thrown

    *******************************************************************/

    public void error ( cstring host_name, istring func_name,
            istring msg = "", istring file = __FILE__, long line = __LINE__ )
    {
        throw this.exception.set(host_name, func_name, msg, file, line);
    }


    /*******************************************************************

        Throw a reusable IOException, with the provided
        message, function name and error code.

        Params:
            host_name = the host which was connected to
            func_name = name of the method that failed
            msg = Pointer to a C string desribing the error
            file = file where exception is thrown
            line = line where exception is thrown

    *******************************************************************/

    public void ssl_error ( cstring host_name, istring func_name,
            const(char*) c_msg, istring file = __FILE__, long line = __LINE__ )
    {
        throw this.exception.set(host_name, func_name, StringC.toDString(c_msg),
            file, line);
    }
}



/*******************************************************************************

    Initializes SSL and creates a global SSL_CTX object

    This function must be called before any SSL clients can be created

    Params:
        ca_path = a directory containing CA certificates in PEM format
        ca_file = pointer to a file of CA certificates in PEM format, or
                null. The file can containe several CA certificates.

    Returns:

        0 if successful, otherwise returns an error code

*******************************************************************************/


public ulong initializeSslAndCreateCtx ( const(char *) ca_path,
    const(char *) ca_file = null )
{
    globalSslContext = null;

    // Initialize SSL

    SSL_library_init();

    // Load  both libssl and libcrypto strings

    SSL_load_error_strings();


    // Load the SSL v2 or v3 function table

    auto method = SSLv23_method();

    if ( !method )
    {
        return ERR_get_error();
    }

    // Create an SSL context to use for all future SSL operations

    globalSslContext = SSL_CTX_new(method);

    if ( !globalSslContext )
    {
        return ERR_get_error();
    }

    SSL_CTX_set_verify(globalSslContext, SSL_VERIFY_PEER, null);

    SSL_CTX_set_verify_depth(globalSslContext, 5);

    // Remove the most problematic options. Because SSLv2 and SSLv3 have been
    // removed, a TLSv1.0 handshake is used. Clients created from this context
    // will accept TLSv1.0 and above. An added benefit of TLS 1.0 and above
    // are TLS extensions like Server Name Indicatior (SNI).
    long flags = SSL_OP_ALL | SSL_OP_NO_SSLv2 | SSL_OP_NO_SSLv3
        | SSL_OP_NO_COMPRESSION;
    long old_opts = SSL_CTX_set_options(globalSslContext, flags);

    // I found that SSL_get_verify_results returns error 20
    // ("unable to get local issuer certificate")
    // unless it has the path to the directory where CA keys are stored

    if ( !SSL_CTX_load_verify_locations(globalSslContext, ca_file,
        ca_path) )
    {
        // Technically, this isn't a fatal error, but many subsequent
        // operations will fail

        return ERR_get_error();
    }

    // Success

    return 0;
}



/*******************************************************************************

    Usage Exmple:

    Here is the fundamental code for an HTTPS client.
    A proper HTTP client would need to parse the HTTP response header to
    determine how many bytes should be read; this example will always trigger
    an error after the final bytes are read.

*******************************************************************************/
unittest
{
    // Check that the code compiles.

    void test_ssl_compilation ()
    {
        .initializeSslAndCreateCtx("/etc/ssl/certs\0".ptr);

        auto client = new SslClientConnection;

        auto host = "en.wikipedia.org";
        auto url_path = "/wiki/D_(programming_language)";

        try
        {
            client.connect(host, "443");
            client.validateCertificate(host);

            auto request = "GET " ~ url_path ~ " HTTP/1.1\r\nHost: "
                ~ host ~ "\r\nConnection:close\r\n\r\n";

            client.write(request);

            char[500] buffer;

            while (true)
            {
                auto result = client.read(buffer);

                // The HTTP response header will arrive first, followed
                // by the data (a web page in this example)
            }
        }
        catch (SslClientConnection.SslException e)
        {
        }
        return;
    }
}
