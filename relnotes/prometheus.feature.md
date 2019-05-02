### Add a client for sending stats to prometheus

`integrationtest.prometheusstats.main`,
`ocean.util.app.DaemonApp`,
`ocean.util.prometheus.collector.Collector`,
`ocean.util.prometheus.collector.CollectorRegistry`,
`ocean.util.prometheus.collector.StatFormatter`,
`ocean.util.prometheus.server.PrometheusHandler`,
`ocean.util.prometheus.server.PrometheusListener`

Prometheus sends HTTP GET requests to an application at `/metrics` endpoint to
pull stats from it. This feature adds a listener for these requests, and a
handler to response with stats to prometheus.

Also introduced here are classes that interface between the handler and a
client application, such that the handler is able to invoke callbacks that
collect stats from the client application upon receiving requests from
prometheus.

The `DaemonApp` class now has two functions, namely, `collectSystemStats` and
`collectGCStats`, to allow existing implementations to initially incorporate
system and GC stats into Prometheus' stat collection with ease.

In general, the steps to start stat collection using Prometheus would be:

    a. Create a `CollectorRegistry` instance with all the delegates, fetching
       your desired stats.
    b. Create a `PrometheusListener` instance with your desired socket address
       and the `CollectorRegistry` instance (created in step a).
    c. Register the `PrometheusListener` instance (created in step b) with your
       epoll dispatcher, using the `PrometheusListener.registerEventHandling`
       method.

To stop the listener, the method `PrometheusListener.shutdown` should suffice
(along with de-registering from epoll, if needed).

For a detailed and functional example, please refer to the system test module,
`integrationtest.prometheusstats.main` and the unittest in module
`ocean.util.prometheus.server.PrometheusListener`.
