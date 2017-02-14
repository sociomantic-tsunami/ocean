/******************************************************************************

    HTTP connection handler base class for use with the SelectListener

    Fiber based HTTP server base class, derived from IFiberConnectionHandler.

    To build a HTTP server, create a HttpConnectionHandler subclass which
    implements handleRequest() and use that subclass as connection handler in
    the SelectListener.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.net.http.HttpConnectionHandler;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.transition;
import ocean.net.http.HttpRequest,
       ocean.net.http.HttpResponse,
       ocean.net.http.HttpException;

import ocean.net.http.HttpConst: HttpResponseCode;
import ocean.net.http.consts.HttpMethod: HttpMethod;
import ocean.net.http.consts.HeaderFieldNames;

import ocean.net.server.connection.IFiberConnectionHandler,
       ocean.io.select.protocol.fiber.model.IFiberSelectProtocol;

import ocean.sys.socket.AddressIPSocket;
import ocean.sys.ErrnoException;
import ocean.core.Enforce;

/******************************************************************************/

abstract class HttpConnectionHandler : IFiberConnectionHandler
{
    /**************************************************************************

        Type aliases as convenience for a subclass

     **************************************************************************/

    protected alias .HttpResponseCode                   HttpResponseCode;
    protected alias .HttpRequest                        HttpRequest;
    protected alias .HttpResponse                       HttpResponse;
    protected alias .HttpMethod                         HttpMethod;
    protected alias .HttpException                      HttpException;
    protected alias .HttpServerException                HttpServerException;
    protected alias .ErrnoException                     ErrnoException;
    protected alias .IFiberSelectProtocol.IOError       IOError;
    protected alias .IFiberSelectProtocol.IOWarning     IOWarning;

    /**************************************************************************

        HTTP request message parser and response message generator

     **************************************************************************/

    protected HttpRequest   request;
    protected HttpResponse  response;

    /**************************************************************************

        Reused exception instance; may be thrown by a subclass as well.

     **************************************************************************/

    protected HttpException             http_exception;

    /**************************************************************************

        Maximum number of requests through the same connection when using
        persistent connections; 0 disables using persistent connections.

     **************************************************************************/

    protected uint keep_alive_maxnum = 0;

    /**************************************************************************

        Status code for the case when a required message header parameters are
        missing.

     **************************************************************************/

    protected auto default_exception_status_code = HttpResponseCode.InternalServerError;

    /**************************************************************************

        Supported HTTP methods, set in the constructor (only checked for element
        existence; the actal value is irrelevant)

     **************************************************************************/

    private bool[HttpMethod] supported_methods;

     /**************************************************************************

        Constructor

        Uses the default request message parser/response generator settings.
        That means, the request parser will be set up for request methods
        without a message body, such as GET or HEAD (in contrast to POST or PUT
        which have a message body).

        Params:
            dispatcher        = select dispatcher instance to register to
            finalizer         = called when the connection is shut down
                                (optional, may be null)
            stack_size        = fiber stack size, use
                                HttpConnectionHandler.default_stack_size for the
                                default value
            supported_methods = list of supported HTTP methods

     **************************************************************************/

    protected this ( EpollSelectDispatcher dispatcher, FinalizeDg finalizer,
                     size_t stack_size,
                     HttpMethod[] supported_methods ... )
    {
        this(dispatcher, finalizer, stack_size,
             new HttpRequest, new HttpResponse, supported_methods);
    }

    /**************************************************************************

        Constructor

        Params:
            dispatcher        = select dispatcher instance to register to
            request           = request message parser
            response          = response message generator
            finalizer         = called when the connection is shut down
                                (optional, may be null)
            supported_methods = list of supported HTTP methods
            stack_size        = fiber stack size, use
                                HttpConnectionHandler.default_stack_size for the
                                default value

     **************************************************************************/

    protected this ( EpollSelectDispatcher dispatcher, FinalizeDg finalizer,
                     size_t stack_size,
                     HttpRequest request, HttpResponse response,
                     HttpMethod[] supported_methods ... )
    {

        super(dispatcher, stack_size, new AddressIPSocket!(), finalizer);

        this.request  = request;
        this.response = response;
        this.http_exception = request.http_exception;

        foreach (method; supported_methods)
        {
            this.supported_methods[method] = true;
        }

        this.supported_methods.rehash;
    }


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Called immediately when this instance is deleted.
            (Must be protected to prevent an invariant from failing.)

        ***********************************************************************/

        protected override void dispose ( )
        {
            super.dispose();

            delete this.request;
            delete this.response;
        }
    }

    /***************************************************************************

        Connection handler method.

    ***************************************************************************/

    final protected override void handle ( )
    {
        bool keep_alive = false;

        uint n = 0;

        try
        {
            do try try
            {
                HttpResponseCode status;

                cstring response_msg_body;

                try
                {
                    this.receiveRequest();

                    keep_alive = n? n < this.keep_alive_maxnum :
                                    this.keep_alive_maxnum && this.keep_alive;

                    n++;

                    status = this.handleRequest(response_msg_body);
                }
                catch (HttpParseException e)
                {
                    this.handleHttpException(e);
                    /*
                     * On request parse error this connection cannot stay alive
                     * because when the request was not completely parsed, its
                     * end and therefore the beginning of the next request is
                     * unknown, so the server-client communication is broken.
                     */
                    break;
                }
                catch (HttpException e)
                {
                    keep_alive &= this.handleHttpException(e);
                    status      = e.status;
                }
                catch (HttpServerException e)
                {
                    keep_alive &= this.handleHttpServerException(e);
                    status      = this.default_exception_status_code;
                }

                this.sendResponse(status, response_msg_body, keep_alive);
            }
            finally
            {
                this.onResponseSent();
            }
            finally
            {
                this.request.reset();
            }
            while (keep_alive);
        }
        catch (IOError e)
        {
            this.notifyIOException(e, true);
        }
        catch (IOWarning e)
        {
            this.notifyIOException(e, false);
        }
    }

    /**************************************************************************

        Resettable interface method; resets the request.

     **************************************************************************/

    public override void reset ( )
    {
        super.reset();

        this.request.reset();
    }

    /**************************************************************************

        Handles the request.

        Params:
            response_msg_body = body of the response body

        Returns:
            HTTP status code

     **************************************************************************/

    abstract protected HttpResponseCode handleRequest ( out cstring response_msg_body );

    /***************************************************************************

        Called after handleRequest() has returned and when the response message
        buffer is no longer referenced or after handleRequest() has thrown an
        exception.
        A subclass may override this method to release resources. This is useful
        especially when a large number of persistent connections is open where
        each connection is only used sporadically.

    ***************************************************************************/

    protected void onResponseSent ( ) { }

    /**************************************************************************

        Receives the HTTP request message.

        Throws:
            - HttpParseException on request message parse error,
            - HttpException if the request contains parameter values that are
              invalid, of range or not supported (unsupported HTTP version or
              method, for example),
            - HeaderParameterException if a required header parameter is missing
              or has an invalid value (a malformated number, for example),
            - IOWarning  when a socket read/write operation results in an
              end-of-flow or hung-up condition,
            - IOError when an error event is triggered for a socket.

     **************************************************************************/

    private void receiveRequest ( )
    {
        super.reader.readConsume((void[] data)
        {
             size_t consumed = this.request.parse(cast (char[]) data, this.request_msg_body_length);

             return this.request.finished? consumed : data.length + 1;
        });

        enforce(this.http_exception.set(HttpResponseCode.NotImplemented),
                this.request.method in this.supported_methods);
    }

    /**************************************************************************

        Sends the HTTP response message.

        Params:
            status            = HTTP status
            response_msg_body = response message body, if any
            keep_alive        = tell the client that this connection will
                                    - true: stay persistent or
                                    - false: be closed
                                after the response message has been sent.

        Throws:
            IOError on socket I/O error.

     **************************************************************************/

    private void sendResponse ( HttpResponseCode status, cstring response_msg_body, bool keep_alive )
    {
        with (this.response)
        {
            http_version = this.request.http_version;

            set(HeaderFieldNames.General.Names.Connection, keep_alive? "keep-alive" : "close");

            super.writer.send(render(status, response_msg_body)).flush();
        }
    }

    /**************************************************************************

        Tells the request message body length.
        This method should be overridden when a request message body is
        expected. It is invoked when the message header is completely parsed.
        The default behaviour is expecting no request message body.

        Returns:
            the request message body length in bytes (0 indicates that no
            request message body is expected)

        Throws:
            HttpException (use the http_exception member) with status set to
                - status.RequestEntityTooLarge to reject a request whose message
                  body is too long or
                - an appropriate status to abort request processing and
                  immediately send the response if the message body length
                  cannot be determined, e.g. because required request header
                  parameters are missing.

     **************************************************************************/

    protected size_t request_msg_body_length ( )
    {
        return 0;
    }

    /**************************************************************************

        Handles HTTP server exception e which was thrown while parsing the
        request message or from handleRequest() or request_msg_body_length() and
        is not a HttpException.
        A subclass may override this method to be notified when an exception is
        thrown and decide whether the connection may stay persistent or should
        be closed after the response has been sent.
        The default behaviour is allowing the connection to stay persistent.

        Params:
            e = HTTP server exception e which was thrown while parsing the
                request message or from handleRequest() or
                request_msg_body_length() and is not a HttpException.

        Returns:
            true if the connection may stay persistent or false if it must be
            closed after the response has been sent.

     **************************************************************************/

    protected bool handleHttpServerException ( HttpServerException e )
    {
        return true;
    }

    /**************************************************************************

        Handles HTTP exception e which was thrown while parsing the request
        message or from handleRequest() or request_msg_body_length().
        A subclass may override this method to be notified when an exception is
        thrown and decide whether the connection may stay persistent or should
        be closed after the response has been sent.
        The default behaviour is allowing the connection being persistent unless
        the status code indicated by the exception is 413: "Request Entity Too
        Large".

        Params:
            e = HTTP server exception e which was thrown while parsing the
                request message or from handleRequest() or
                request_msg_body_length(). e.status reflects the response status
                code and may be changed when overriding this method.

        Returns:
            true if the connection may stay persistent or false if it should be
            closed after the response has been sent.

     **************************************************************************/

    protected bool handleHttpException ( HttpException e )
    {
        return e.status != e.status.RequestEntityTooLarge;
    }

    /**************************************************************************

        Called when an IOWarning or IOError is caught. May be overridden by a
        subclass to be notified.

        An IOWarning is thrown when a socket read/write operation results in an
        end-of-flow or hung-up condition, an IOError when an error event is
        triggered for a socket.

        Params:
            e        = caught IOWarning or IOError
            is_error = true: e was an IOError, false: e was an IOWarning

     **************************************************************************/

    protected void notifyIOException ( ErrnoException e, bool is_error ) { }

    /**************************************************************************

        Detects whether the connection should stay persistent or not.

        Returns:
            true if the connection should stay persistent or false if not

     **************************************************************************/

    private bool keep_alive ( )
    {
        switch (this.request.http_version)
        {
            case this.request.http_version.v1_1:
                return !this.request.matches("connection", "close");

            case this.request.http_version.v1_0:
            default:
                return this.request.matches("connection", "keep-alive");
        }
    }
}
