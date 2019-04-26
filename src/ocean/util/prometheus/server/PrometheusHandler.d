/*******************************************************************************

    An HTTP response handler for Prometheus' requests, used in
    `PrometheusListener`.

    Responds to GET requests only.

    Copyright:
        Copyright (c) 2019 dunnhumby Germany GmbH.
        All rights reserved

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

*******************************************************************************/

module ocean.util.prometheus.server.PrometheusHandler;

import ocean.net.http.HttpConnectionHandler;

/// ditto
public class PrometheusHandler : HttpConnectionHandler
{
    import ocean.io.select.EpollSelectDispatcher : EpollSelectDispatcher;
    import ocean.net.http.HttpRequest : HttpRequest;
    import ocean.net.http.HttpConst: HttpResponseCode;
    import ocean.net.http.consts.HttpMethod: HttpMethod;
    import ocean.text.convert.Formatter : sformat;
    import ocean.transition;
    import ocean.util.log.Logger : Logger, Log;
    import ocean.util.prometheus.collector.CollectorRegistry :
        CollectorRegistry;

    /// A static logger for logging information about connections.
    private static Logger log;
    static this ( )
    {
        this.log = Log.lookup("ocean.util.prometheus.server.PrometheusHandler");
    }

    /// A CollectorRegistry instance that refers to the callbacks that need to
    /// be called for stat collection.
    private CollectorRegistry collector_registry;

    /// A buffer to hold error messages, if any exception while stat collection
    /// is encountered.
    private mstring err_buf;

    /***************************************************************************

        Constructor.

        Initializes an HTTP request handler instance for GET requests at the
        `/metrics` endpoint.

        Params:
            finalizer          = Finalizer callback of the select listener.
            collector_registry = The CollectorRegistry instance, containing
                                 references to the collection callbacks.
            epoll              = The EpollSelectDispatcher instance used here.
            stack_size         = The fiber stack size to use. Defaults to
                                 `HttpConnectionHandler.default_stack_size`.

    ***************************************************************************/

    public this ( FinalizeDg finalizer, CollectorRegistry collector_registry,
        EpollSelectDispatcher epoll,
        size_t stack_size = HttpConnectionHandler.default_stack_size )
    {
        super(epoll, finalizer, stack_size, [HttpMethod.Get]);
        this.collector_registry = collector_registry;
    }

    /***************************************************************************

        Handles responses for incoming HTTP requests. Responds with stats when
        the request endpoint is `/metrics`.
        For all other endpoints, returns `HttpResponseCode.NotImplemented`.
        If stat collection throws an error, responds with
        `HttpResponseCode.InternalServerError`, with the exception message as
        the response message body;

        Params:
            response_msg_body = Body of the response body.

        Returns:
            HTTP status code

    ***************************************************************************/

    override protected HttpResponseCode handleRequest (
        out cstring response_msg_body )
    {
        if (this.request.uri_string() != "/metrics")
        {
            PrometheusHandler.log.info(
                "Received request at an unhandled endpoint: {}",
                this.request.uri_string());
            return HttpResponseCode.NotImplemented;
        }

        try
        {
            response_msg_body = this.collector_registry.collect();
            return HttpResponseCode.OK;
        }
        catch (Exception ex)
        {
            err_buf.length = 0;
            enableStomping(err_buf);

            sformat(err_buf, "{}({}):{}", ex.file, ex.line, ex.message());

            PrometheusHandler.log.error(err_buf);
            response_msg_body = err_buf;

            return HttpResponseCode.InternalServerError;
        }
    }

    /***************************************************************************

        Logs an warning or error message when an IOWarning or IOError,
        respectively, is caught.

        An IOWarning is thrown when a socket read/write operation results in an
        end-of-flow or hung-up condition, an IOError when an error event is
        triggered for a socket.

        Params:
            e        = caught IOWarning or IOError
            is_error = true: e was an IOError, false: e was an IOWarning

     **************************************************************************/

    override protected void notifyIOException (
        ErrnoException e, bool is_error )
    {
        if (is_error)
        {
            PrometheusHandler.log.error("IOError encountered : {}({}):{}",
                e.file, e.line, e.message());
        }
        else
        {
            PrometheusHandler.log.warn("IOWarning encountered : {}({}):{}",
                e.file, e.line, e.message());
        }
    }
}
