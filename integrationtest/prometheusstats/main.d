/*******************************************************************************

    Test-suite for stat collection using prometheus.

    This test uses a TCP socket connection to `localhost:8080`.

    Copyright: Copyright (c) 2019 dunnhumby Germany GmbH. All rights reserved

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module integrationtest.prometheusstats.main;

import ocean.transition;

import ocean.io.select.EpollSelectDispatcher;
import ocean.task.Task;
import ocean.task.Scheduler;
import ocean.text.convert.Formatter;
import ocean.sys.socket.IPSocket;
import ocean.sys.ErrnoException;
import core.stdc.errno;
import core.stdc.stdlib;

import ocean.util.prometheus.collector.Collector;
import ocean.util.prometheus.collector.CollectorRegistry;
import ocean.util.prometheus.server.PrometheusListener;

import ocean.io.Stdout;

/// A class containing structs representing stats and their labels, a method
/// that can be added to the CollectorRegistry, followed by a textual
/// representation of the stats mock-collected here.
class PrometheusStats
{
    ///
    struct Statistics
    {
        ulong up_time_s;
        size_t count;
        float ratio;
        double fraction;
        real very_real;
    }

    ///
    struct Labels
    {
        hash_t id;
        cstring job;
        float perf;
    }

    ///
    void collect ( Collector collector )
    {
        collector.collect(
            Statistics(3600, 347, 3.14, 6.023, 0.43),
            Labels(1_235_813, "ocean", 3.14159));
    }

    ///
    static istring collection_text =
        "up_time_s {id=\"1235813\",job=\"ocean\",perf=\"3.14159\"} 3600\n" ~
        "count {id=\"1235813\",job=\"ocean\",perf=\"3.14159\"} 347\n" ~
        "ratio {id=\"1235813\",job=\"ocean\",perf=\"3.14159\"} 3.14\n" ~
        "fraction {id=\"1235813\",job=\"ocean\",perf=\"3.14159\"} 6.023\n" ~
        "very_real {id=\"1235813\",job=\"ocean\",perf=\"3.14159\"} 0.43\n";
}

/// HTTP client task. It sends one HTTP GET request to the prometheus endpoint
/// and receives a respone that should contain the expected stats, as provided
/// in `PrometheusStats.collection_text`.
class ClientTask: Task
{
    import Finder = ocean.core.array.Search;
    import ocean.core.Test: test;
    import ocean.io.select.protocol.task.TaskSelectTransceiver;
    import ocean.io.select.protocol.generic.ErrnoIOException: SocketError;

    public Exception to_report;

    private TaskSelectTransceiver tst;

    private IPSocket!() socket;
    private SocketError socket_err;
    private IPSocket!().InetAddress srv_address;

    private mstring response_msg;

    ///
    this ( IPSocket!().InetAddress srv_address )
    {
        this.socket = new IPSocket!();
        this.socket_err = new SocketError(socket);

        this.tst = new TaskSelectTransceiver(socket, socket_err, socket_err);

        this.srv_address = srv_address;
    }

    ///
    override void run ( )
    {
        try
        {
            this.socket_err.enforce(
                this.socket.tcpSocket(true) >= 0, "", "socket");

            connect(this.tst, delegate (IPSocket!() socket) {
                return !socket.connect(this.srv_address.addr);
            });

            this.tst.write(
                "GET /metrics HTTP/1.1\r\nHost: oceantest.net\r\n\r\n");

            this.tst.readConsume(&this.consume);
            test!("==")(this.response_msg, PrometheusStats.collection_text);
        }
        catch (Exception ex)
        {
            this.to_report = ex;
        }
    }

    ///
    size_t consume ( void[] data )
    {
        cstring header_end = "\r\n\r\n";
        auto header_end_idx = Finder.find(cast(char[])data, header_end);

        if (header_end_idx == data.length)
        {
            return data.length + 1;
        }

        sformat(this.response_msg, "{}",
            cast(char[])data[header_end_idx + 4 .. $]);
        return 0;
    }
}

/*******************************************************************************

    Runs the server, which listens to one request on the prometheus endpoint,
    and exits.

    Returns:
        `EXIT_SUCCESS`

*******************************************************************************/

version(UnitTest) {} else
int main ( )
{
    initScheduler(SchedulerConfiguration.init);

    auto stats = new PrometheusStats();
    auto registry = new CollectorRegistry([&stats.collect]);

    IPSocket!().InetAddress srv_address;

    auto listener = new PrometheusListener(srv_address("127.0.0.1", 8080),
        new IPSocket!(), registry, theScheduler.epoll);

    auto client = new ClientTask(srv_address);
    client.terminationHook = delegate {
        theScheduler.epoll.unregister(listener);
    };

    listener.registerEventHandling(theScheduler.epoll);
    theScheduler.schedule(client);
    theScheduler.eventLoop();

    if (client.to_report !is null)
    {
        throw client.to_report;
    }

    return EXIT_SUCCESS;
}
