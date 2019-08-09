/*******************************************************************************

    A module containing a generic http server that redirects the requests to
    a list of delegates

    Copyright:
        Copyright (c) 2009-2019 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.net.http.HttpServer;

import ocean.core.Enforce;
import ocean.net.http.consts.StatusCodes;
import ocean.net.http.consts.HttpMethod;
import ocean.net.http.TaskHttpConnectionHandler;
import ocean.net.http.HttpRequest;
import ocean.net.http.HttpResponse;
import ocean.net.http.HttpConst;
import ocean.net.server.SelectListener;
import ocean.task.Scheduler;
import ocean.util.log.Logger;
import ocean.sys.socket.InetAddress;
import ocean.sys.socket.IPSocket;
import ocean.sys.socket.AddressIPSocket;

/// The http handler type
alias HttpHandler = HttpResponseCode delegate(HttpRequest, out const(char)[]);

/// The Http configuration
public struct HttpConfig
{
    /// Address used for listening for new connections
    public string address;

    /// Port used for listening for new connections
    public ushort port;
}

/// Http server that handle generic requests using a list of handlers
public class HttpServer
{
    /// Logger
    protected Logger log;

    /// The ipv4 socket used by the web server
    private AddressIPSocket!(false) socket;

    /// The ipv4 address used to setup the socket
    private InetAddress!(false) address;

    /// Http server used to serve prometheus stats and other inputs if it's needed
    alias HttpServerListener = SelectListener!(HttpRequestHandler, HttpHandler[]);

    /// ditto
    private HttpServerListener http_server;

    /// The list of request handlers
    private HttpHandler[] handlers;

    /**************************************************************************

        Constructor

        Params:
            handlers = The list of http handlers that the server will use

    **************************************************************************/

    public this ( HttpHandler[] handlers )
    {
        this.log = Log.lookup("ocean.net.http.HttpServer");
        this.handlers = handlers;
    }

    /**************************************************************************

        Start the http server

        Params:
            config = The http configuration

    **************************************************************************/

    public void start ( HttpConfig config )
    {
        log.info("Listening on {}:{}", config.address, config.port);
        auto listen_address = address(config.address, config.port);
        enforce(listen_address !is null, "Can't listen for TCP connections.");

        this.socket = new AddressIPSocket!();
        this.http_server = new HttpServerListener(listen_address, this.socket, this.handlers);
        log.info("Waiting HTTP requests on {}:{}", config.address, config.port);

        theScheduler.epoll.register(this.http_server);
    }

    /// Stop listening for new requests
    public void terminate ( )
    {
        this.http_server.terminate();
        theScheduler.epoll.unregister(this.http_server);
    }
}

/// Handle the list of requests in order until one of them returns something
/// else than `Not Found`
private class HttpRequestHandler : TaskHttpConnectionHandler
{
    /// The http handler list
    private HttpHandler[] handlers;

    /// Log instance
    private Logger log;

    /**************************************************************************

        Constructor

        Params:
            finalizer = finalizer callback of the select listener

    **************************************************************************/

    public this ( FinalizeDg finalizer, HttpHandler[] handlers )
    {
        super(finalizer, new HttpRequest(true), new HttpResponse,
            [ HttpMethod.Get, HttpMethod.Put, HttpMethod.Post,
              HttpMethod.Delete, HttpMethod.Options ]);
        this.handlers = handlers;

        this.log = Log.lookup("ocean.net.http.HttpServer.HttpRequestHandler");
    }

    /**************************************************************************

        Method that handles the HTTP requests it will call each handlers until


        Params:
            response = the response message that will be sent to the client

        Returns:
            HttpResponseCode.OK if the request was successfully handled, or
            HttpResponseCode.BadRequest in case of an error

    **************************************************************************/

    override public HttpResponseCode handleRequest ( out const(char)[] response )
    {
        log.trace("Got HTTP request");

        try
        {
            foreach ( handler; this.handlers )
            {
                auto status = handler(this.request, response);

                if ( status != HttpResponseCode.NotFound )
                {
                    return status;
                }
            }
        }
        catch ( Exception e )
        {
            log.error("Can't handle the request: `{}` `{}` `{}`", this.request.uri_string, this.request.msg_body, e.message);
            response = e.message;

            return HttpResponseCode.BadRequest;
        }

        return HttpResponseCode.NotFound;
    }

    /**************************************************************************

        Tells the request message body length.

        This method should be overridden when a request message body is
        expected. It is invoked when the message header is completely parsed.
        The default behavior is expecting no request message body.

        Returns:
            the request message body length in bytes (0 indicates that no
            request message body is expected)

     **************************************************************************/

    override protected size_t request_msg_body_length ( )
    {
        size_t size;

        try
        {
            this.request.getUnsigned("Content-Length", size);
        }
        catch ( Exception e )
        {
            log.error("{}", e.message);
        }

        return size;
    }
}

/// Usage example for the HttpServer class
unittest
{
    void main ()
    {
        HttpResponseCode iDoNothing( HttpRequest, out const(char)[] )
        {
            return HttpResponseCode.NotFound;
        }

        HttpResponseCode iDoSomething( HttpRequest, out const(char)[] response )
        {
            response = "I did something";
            return HttpResponseCode.OK;
        }

        auto config = HttpConfig("0.0.0.0", 8080);
        auto server = new HttpServer([ &iDoNothing, &iDoSomething ]);

        server.start(config);
    }
}
