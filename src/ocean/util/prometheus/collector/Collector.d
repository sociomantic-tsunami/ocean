/*******************************************************************************

    Contains methods that collect stats from primitive data members of structs
    or classes to respond to Prometheus queries with.

    The metric designs specified by Prometheus
    (`https://prometheus.io/docs/concepts/metric_types/`) have not been
    implemented yet. So, as of now, this collector can process only primitive
    data-type members from a struct or a class. However, the current Prometheus
    stat collection framework could be enhanced to support metrics with a very
    little effort.

    In Prometheus' data model, the stats that are measured are called Metrics,
    and the dimensions along which stats are measured are called Labels.

    Metrics can be any measurable value, e.g., CPU or memory consumption.

    Labels resemble key-value pairs, where the key is referred to as a label's
    name, and the value as a label's value. A label name would refer to the name
    of a dimension across which we want to measure stats. Correspondingly, a
    label value would refer to a point along the said dimension. A stat can have
    more than one label, if it is intended to be measured across multiple
    dimensions.

    Stats with labels look like the following example
    `
    promhttp_metric_handler_requests_total{code="200"} 3
    promhttp_metric_handler_requests_total{code="500"} 0
    promhttp_metric_handler_requests_total{code="503"} 0
    `
    Here `promhttp_metric_handler_requests_total` is the metric, `code` is
    the label name, `"200"`, `"500"` and `"503"` are the label values, and `3`,
    `0` and `0` are the respective metric values.

    On the data visualization side of Prometheus, fetching stats using queries
    is analogous to calling functions. A metric name is analogous to a function
    name, and a label is analogous to a function parameter. Continuing with the
    above example, the following query will return `3`:
    `
    promhttp_metric_handler_requests_total {code="200"}
    `

    (For detailed information about Prometheus-specific terminology, e.g.,
    Metrics and Labels, please refer to
    `https://prometheus.io/docs/concepts/data_model/#metric-names-and-labels`.)

    This module contains a class which can be used to collect metrics as well as
    labels from composite-type values, and format them in a way acceptable for
    Prometheus.

    Copyright:
        Copyright (c) 2019 dunnhumby Germany GmbH.
        All rights reserved

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

*******************************************************************************/

module ocean.util.prometheus.collector.Collector;

/*******************************************************************************

    This class provides methods to collect metrics with no label, one label, or
    multiple labels, using overloaded definitions of the `collect` method.

    Once the desired stats have been collected, the accumulated response
    string can be collected using the `getCollection` method.

    Additionally, the `reset` method can be used to reset stat
    collection, when the desired stats have been collected from a Collector
    instance.

*******************************************************************************/

public class Collector
{
    import core.stdc.time;
    import Traits = ocean.core.Traits;
    import ocean.math.IEEE;
    import ocean.text.convert.Formatter;
    import ocean.transition;
    import StatFormatter = ocean.util.prometheus.collector.StatFormatter;

    /// A buffer used for storing collected stats. Is cleared when the `reset`
    /// method is called.
    private mstring collect_buf;

    /***************************************************************************

        Returns:
            The stats collected since the last call to the `reset` method, in a
            textual respresentation that can be readily added to a response
            message body.
            The specifications of the format of the collected stats can be found
            at `https://prometheus.io/docs/instrumenting/exposition_formats/`.

    ***************************************************************************/

    public cstring getCollection ( )
    {
        return this.collect_buf;
    }

    /// Reset the length of the stat collection buffer to 0.
    public void reset ( )
    {
        this.collect_buf.length = 0;
        enableStomping(this.collect_buf);
    }

    /***************************************************************************

        Collect stats from the data members of a struct or a class and prepare
        them to be fetched upon the next call to `getCollection`. The
        specifications of the format of the collected stats can be found at
        `https://prometheus.io/docs/instrumenting/exposition_formats/`.

        Params:
            ValuesT = The struct or class type to fetch the stat names from.
            values  = The struct or class to fetch stat values from.

    ***************************************************************************/

    public void collect ( ValuesT ) ( ValuesT values )
    {
        static assert (is(ValuesT == struct) || is(ValuesT == class),
            "'values' parameter must be a struct or a class.");

        StatFormatter.formatStats(values, this.collect_buf);
    }

    /***************************************************************************

        Collect stats from the data members of a struct or a class, annotate
        them with a given label name and value, and prepare them to be fetched
        upon the next call to `getCollection`.
        The specifications of the format of the collected stats can be found
        at `https://prometheus.io/docs/instrumenting/exposition_formats/`.

        Params:
            LabelName = The name of the label to annotate the stats with.
            ValuesT   = The struct or class type to fetch the stat names from.
            LabelT    = The type of the label's value.
            values    = The struct or class to fetch stat values from.
            label_val = The label value to annotate the stats with.

    ***************************************************************************/

    public void collect ( istring LabelName, ValuesT, LabelT ) (
        ValuesT values, LabelT label_val )
    {
        static assert (is(ValuesT == struct) || is(ValuesT == class),
            "'values' parameter must be a struct or a class.");

        StatFormatter.formatStats!(LabelName)(values, label_val,
            this.collect_buf);
    }

    /***************************************************************************

        Collect stats from the data members of a struct or a class, annotate
        them with labels from the data members of another struct or class, and
        prepare them to be fetched upon the next call to `getCollection`.
        The specifications of the format of the collected stats can be found
        at `https://prometheus.io/docs/instrumenting/exposition_formats/`.

        Params:
            ValuesT = The struct or class type to fetch the stat names from.
            LabelsT = The struct or class type to fetch the label names from.
            values  = The struct or class to fetch stat values from.
            labels  = The struct or class holding the label values to annotate
                      the stats with.

    ***************************************************************************/

    public void collect ( ValuesT, LabelsT ) ( ValuesT values, LabelsT labels )
    {
        static assert (is(ValuesT == struct) || is(ValuesT == class),
            "'values' parameter must be a struct or a class.");
        static assert (is(LabelsT == struct) || is(LabelsT == class),
            "'labels' parameter must be a struct or a class.");

        StatFormatter.formatStats(values, labels, this.collect_buf);
    }
}

version (UnitTest)
{
    import ocean.core.Test;
    import ocean.transition;

    struct Statistics
    {
        ulong up_time_s;
        size_t count;
        float ratio;
        double fraction;
        real very_real;

        // The following should not be collected as stats
        int delegate ( int ) a_delegate;
        void function ( ) a_function;
    }

    struct Labels
    {
        hash_t id;
        cstring job;
        float perf;
    }
}

/// Test collecting populated stats, but without any label.
unittest
{
    auto test_collector = new Collector();
    test_collector.collect(Statistics(3600, 347, 3.14, 6.023, 0.43));

    test!("==")(test_collector.getCollection(),
        "up_time_s 3600\ncount 347\nratio 3.14\nfraction 6.023\n" ~
        "very_real 0.43\n");
}

/// Test collecting populated stats with one label
unittest
{
    auto test_collector = new Collector();
    test_collector.collect!("id")(
        Statistics(3600, 347, 3.14, 6.023, 0.43), 123.034);

    test!("==")(test_collector.getCollection(),
        "up_time_s {id=\"123.034\"} 3600\ncount {id=\"123.034\"} 347\n" ~
        "ratio {id=\"123.034\"} 3.14\nfraction {id=\"123.034\"} 6.023\n" ~
        "very_real {id=\"123.034\"} 0.43\n");
}

/// Test collecting stats having initial values with multiple labels
unittest
{
    auto test_collector = new Collector();
    test_collector.collect(Statistics(3600, 347, 3.14, 6.023, 0.43),
        Labels(1_235_813, "ocean", 3.14159));

    test!("==")(test_collector.getCollection(),
        "up_time_s {id=\"1235813\",job=\"ocean\",perf=\"3.14159\"} 3600\n" ~
        "count {id=\"1235813\",job=\"ocean\",perf=\"3.14159\"} 347\n" ~
        "ratio {id=\"1235813\",job=\"ocean\",perf=\"3.14159\"} 3.14\n" ~
        "fraction {id=\"1235813\",job=\"ocean\",perf=\"3.14159\"} 6.023\n" ~
        "very_real {id=\"1235813\",job=\"ocean\",perf=\"3.14159\"} 0.43\n");
}

/// Test resetting collected stats
unittest
{
    auto test_collector = new Collector();
    test_collector.collect!("id")(Statistics.init, 123);

    test!("==")(test_collector.getCollection(),
        "up_time_s {id=\"123\"} 0\ncount {id=\"123\"} 0\n" ~
        "ratio {id=\"123\"} 0\nfraction {id=\"123\"} 0\n" ~
        "very_real {id=\"123\"} 0\n");

    test_collector.reset();

    test!("==")(test_collector.getCollection(), "");
}

// Test collecting stats having initial values, but without any label.
unittest
{
    auto test_collector = new Collector();
    test_collector.collect(Statistics.init);

    test!("==")(test_collector.getCollection(),
        "up_time_s 0\ncount 0\nratio 0\nfraction 0\nvery_real 0\n");
}

// Test collecting stats having initial values with one label
unittest
{
    auto test_collector = new Collector();
    test_collector.collect!("id")(Statistics.init, 123);

    test!("==")(test_collector.getCollection(),
        "up_time_s {id=\"123\"} 0\ncount {id=\"123\"} 0\n" ~
        "ratio {id=\"123\"} 0\nfraction {id=\"123\"} 0\n" ~
        "very_real {id=\"123\"} 0\n");
}

// Test collecting stats having initial values with multiple labels
unittest
{
    auto test_collector = new Collector();
    test_collector.collect(Statistics.init, Labels.init);

    test!("==")(test_collector.getCollection(),
        "up_time_s {id=\"0\",job=\"\",perf=\"0\"} 0\n" ~
        "count {id=\"0\",job=\"\",perf=\"0\"} 0\n" ~
        "ratio {id=\"0\",job=\"\",perf=\"0\"} 0\n" ~
        "fraction {id=\"0\",job=\"\",perf=\"0\"} 0\n" ~
        "very_real {id=\"0\",job=\"\",perf=\"0\"} 0\n");
}

// Test accumulation of collected stats
unittest
{
    auto test_collector = new Collector();
    test_collector.collect!("id")(Statistics.init, 123);

    test!("==")(test_collector.getCollection(),
        "up_time_s {id=\"123\"} 0\ncount {id=\"123\"} 0\n" ~
        "ratio {id=\"123\"} 0\nfraction {id=\"123\"} 0\n" ~
        "very_real {id=\"123\"} 0\n");

    test_collector.collect!("id")(
        Statistics(3600, 347, 3.14, 6.023, 0.43), 123.034);

    test!("==")(test_collector.getCollection(),
        "up_time_s {id=\"123\"} 0\ncount {id=\"123\"} 0\n" ~
        "ratio {id=\"123\"} 0\nfraction {id=\"123\"} 0\n" ~
        "very_real {id=\"123\"} 0\n" ~

        "up_time_s {id=\"123.034\"} 3600\ncount {id=\"123.034\"} 347\n" ~
        "ratio {id=\"123.034\"} 3.14\nfraction {id=\"123.034\"} 6.023\n" ~
        "very_real {id=\"123.034\"} 0.43\n");
}
