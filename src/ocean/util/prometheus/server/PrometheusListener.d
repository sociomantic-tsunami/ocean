/*******************************************************************************

    Contains a listener for scrape requests by Prometheus.

    Please refer to the unittest in this module for an example. A more elaborate
    example can be found in `integrationtest.prometheusstats.main`.

    Copyright:
        Copyright (c) 2019 dunnhumby Germany GmbH.
        All rights reserved

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

*******************************************************************************/

module ocean.util.prometheus.server.PrometheusListener;

import ocean.io.select.EpollSelectDispatcher;
import ocean.net.server.SelectListener;
import ocean.util.prometheus.collector.CollectorRegistry;
import ocean.util.prometheus.server.PrometheusHandler;

/*******************************************************************************

    A listener for Prometheus' stat scrape.

    Once instantiated with the set of callbacks that collect stats for given
    stats and labels, the callbacks will be called for every incoming prometheus
    request, and the accumulated stats will be appended to the response message.

    Derives from `SelectListener` with four generic parameters, the last three
    of which are used to instantiate the handler used by this listener.

*******************************************************************************/

public class PrometheusListener :
    SelectListener!(PrometheusHandler, CollectorRegistry, EpollSelectDispatcher,
        size_t)
{
    import core.sys.posix.sys.socket : sockaddr, time_t;
    import ocean.io.select.client.TimerEvent : TimerEvent;
    import ocean.net.http.HttpConnectionHandler : HttpConnectionHandler;
    import ocean.sys.socket.model.ISocket : ISocket;
    import ocean.text.convert.Formatter : sformat;
    import ocean.util.log.Logger : Logger, Log;

    import ocean.transition;

    /// A static logger for logging information about connections.
    private static Logger log;
    static this ( )
    {
        PrometheusListener.log =
            Log.lookup("ocean.util.prometheus.server.PrometheusListener");
    }

    /// A buffer used for logging information about connections.
    private mstring connection_log_buf;

    /***************************************************************************

        Constructor

        Creates the server socket and registers it for incoming connections.

        Params:
            address            = The address of the socket.
            socket             = The server socket.
            collector_registry = The CollectorRegistry instance, containing
                                 references to the collection callbacks.
            epoll              = The EpollSelectDispatcher instance to use in
                                 response handler(s).
            stack_size         = The fiber stack size to use. Defaults to
                                 `HttpConnectionHandler.default_stack_size`.

    ***************************************************************************/

    public this ( sockaddr* address, ISocket socket,
        CollectorRegistry collector_registry, EpollSelectDispatcher epoll,
        size_t stack_size = HttpConnectionHandler.default_stack_size )
    {
        super(address, socket, collector_registry, epoll, stack_size);
    }

    /***************************************************************************

        Registers the listener with a given epoll, so that it can be activated
        in the latter's event loop.

        Params:
            epoll = The epoll to register the server with.

    ***************************************************************************/

    public void registerEventHandling ( EpollSelectDispatcher epoll )
    {
        epoll.register(this);
    }

    /***************************************************************************

        Logs the information about connections to the log file.

        Overriden from the base instance to specify the logger's name to be
        this module's fully-qualified name.

    ***************************************************************************/

    override public void connectionLog ( )
    {
        auto conns = this.poolInfo;

        PrometheusListener.log.info("Connection pool: {} busy, {} idle",
            conns.num_busy, conns.num_idle);

        foreach ( i, conn; conns )
        {
            this.connection_log_buf.length = 0;
            sformat(this.connection_log_buf, "{}: ", i);

            conn.formatInfo(this.connection_log_buf);

            PrometheusListener.log.info(this.connection_log_buf);
        }
    }
}

version (UnitTest)
{
    import ocean.stdc.posix.sys.socket;
    import ocean.sys.socket.IPSocket;
    import ocean.util.prometheus.collector.Collector;
}

/// Test and demonstrate instantiation of a `PrometheusListener` object
unittest
{
    class ExampleStats
    {
        import core.sys.posix.unistd;
        import ocean.sys.Stats : CpuMemoryStats;

        CpuMemoryStats system_stats;

        struct Labels
        {
            pid_t pid;
        }

        this ( ) { this.system_stats = new CpuMemoryStats(); }

        void collect ( Collector collector )
        {
            // CpuMemoryStats.collect() returns a struct whose fields we want
            // to collect via Prometheus.
            collector.collect(this.system_stats.collect(), Labels( getpid() ));
        }

        void collectp ( Collector collector )
        {
            collector.collect(this.system_stats.collect(), Labels( getppid() ));
        }
    }

    auto epoll = new EpollSelectDispatcher();

    auto example = new ExampleStats();
    auto registry = new CollectorRegistry(
        [&example.collect, &example.collectp]);

    IPSocket!().InetAddress srv_address;
    sockaddr* socket_addrress = srv_address("127.0.0.1", 8080);
    auto listener = new PrometheusListener(socket_addrress, new IPSocket!(),
        registry, epoll);

    // The following line registers the server with the dispatcher, which in
    // effect makes it operational, subject to the latter's scheduling.
    // (Commented out here to not start a server instance in a unit test.)

    // listener.registerEventHandling(epoll);
}
