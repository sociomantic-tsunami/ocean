/*******************************************************************************

    Classes to write statistics to be used in graphite.

    Applications that want to log statistics usually make use of the `StatsExt`
    extension (most likely by deriving from `DaemonApp`),
    which provides a `StatsLog` instance which is automatically configured from
    the application's config.ini.

    StatsLog provides methods to:
        1. Build up a stats line by writing sets of values (specified by the
           fields of one or more user-specified structs).
        2. Flush the stats line to the output.

    Currently, `StatsLog` writes to a file (called `stats.log`), which is then
    parsed by a script that will feed the data to a Collectd socket.
    Every server's Collectd daemon will then report to a master Collectd server
    which aggregates the data.
    As our number of stats is growing and the write rate is increasing, we're
    planning to expose a way to directly write to the Collectd socket.
    As a result, the current API of `StatsLog` is intentionally designed
    to comply to the limitations of Collectd. See the documentation of
    `StatsLog` for more details

    Refer to the class' description for information about their actual usage.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.log.Stats;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.Traits : FieldName;

import ocean.core.TypeConvert;

import ocean.text.convert.Layout: StringLayout;

import ocean.util.log.layout.LayoutStatsLog;

import ocean.transition;
import ocean.core.Traits;
import ocean.util.log.Log;

import ocean.stdc.time : time_t;

version (UnitTest)
{
    import ocean.util.app.DaemonApp;
}

/*******************************************************************************

    Transmit the values of an aggregate to be used within graphite.

    This class has 2 methods which can be used: `add` and `addObject`.

    `add` is meant for application statistics, i.e. amount of memory used,
    number of channels alive, number of connections open, largest record
    processed...

    `addObject` logs an instance of an object which belongs to a category.
    This method should be used when you have a set of standard metrics which
    you want to log for multiple instances of a type of object.
    For example, you may want to log standard stats for each channel in
    a storage engine, for each campaign of an advertiser,
    for each source of input records, etc.

    See the methods description for more informations.

    Note:
    StatsLog formerly had the ability to write single value instead of an
    aggregate. It was removed as it goes against Collectd's design, where
    data sent to the socket are sent aggregated by 'types', where a type is
    a collection of related metrics (akin to a `struct`), so single values
    are not permitted.
    In addition, it's not possible to incrementally build an aggregate either,
    as we need the aggregate's complete definition : if we send incomplete/too
    much data to Collectd, it just rejects the whole aggregate, and data is sent
    without field names, as Collectd relies on its type definition for that
    piece of information. Having the wrong order would mean some metrics are
    logged as other metrics, a bug that might not be easily identifiable.
    This was leaving too much room for error which were not easily identifiable.

    Examples:
        See the unittest following this class for an example application

*******************************************************************************/

public class StatsLog
{
    import ocean.util.log.AppendFile;

    /***************************************************************************

        Stats log config class

    ***************************************************************************/

    public static class Config
    {
        public istring file_name;

        public this ( istring file_name = default_file_name )
        {
            this.file_name = file_name;
        }
    }


    /***************************************************************************

        Stats log default settings (used in ctor)

    ***************************************************************************/

    public const time_t default_period = 30; // 30 seconds
    public const istring default_file_name = "log/stats.log";


    /***************************************************************************

        Logger instance

    ***************************************************************************/

    protected Logger logger;


    /***************************************************************************

        Message formatter

    ***************************************************************************/

    protected StringLayout!() layout;


    /***************************************************************************

        Whether to add a separator or not

    ***************************************************************************/

    private bool add_separator = false;


    /***************************************************************************

        Constructor. Creates the stats log using the AppendSysLog appender.

        Params:
            config = instance of the config class
            name   = name of the logger, should be set to a different string
                     when using more than two StatLogs

    ***************************************************************************/

    public this ( Config config, istring name = "Stats" )
    {
        Appender newAppender ( istring file, Appender.Layout layout )
        {
            return new AppendFile(file, layout);
        }

        this(config, &newAppender, name);
    }


    /***************************************************************************

        Constructor. Creates the stats log using the appender returned by the
        provided delegate.

        Params:
            config = instance of the config class
            new_appender = delegate which returns appender to use for stats log
            name   = name of the logger, should be set to a different string
                     when using more than two StatLogs

    ***************************************************************************/

    public this ( Config config,
        Appender delegate ( istring file, Appender.Layout layout ) new_appender,
        istring name = "Stats" )
    {
        this.logger = Log.lookup(name);
        this.logger.clear();
        this.logger.additive(false);

        this.logger.add(new_appender(config.file_name, new LayoutStatsLog));

        // Explcitly set the logger to output all levels, to avoid the situation
        // where the root logger is configured to not output level 'info'.
        this.logger.level = this.logger.Level.Trace;

        this.layout = new StringLayout!();
    }


    /***************************************************************************

        Adds the values of the given aggregate to the stats log. Each member
        of the aggregate will be output as <member name>:<member value>.

        Params:
            values = aggregate containing values to write to the log.

    ***************************************************************************/

    public typeof(this) add ( T ) ( T values )
    {
        static assert (is(T == struct) || is(T == class),
                       "Parameter to add must be a struct or a class");
        this.format!(null)(values, istring.init);

        return this;
    }


    /***************************************************************************

        Adds the values of the given aggregate to the stats log. Each member of
        the aggregate will be output as
        <category>/<instance>/<member name>:<member value>.

        Template_Params:
            category = The name of the category this object belongs to.

        Params:
            instance = Name of the object to add.
            values = aggregate containing values to write to the log.

    ***************************************************************************/

    public typeof(this) addObject (istring category, T)
        (cstring instance, T values)
    in
    {
        static assert (is(T == struct) || is(T == class),
                       "Parameter to add must be a struct or a class");
        static assert(category.length,
                      "Template parameter 'category' should not be null");
        assert (instance.length, "Object name should not be null");
    }
    body
    {
        this.format!(category)(values, instance);
        return this;
    }


    /***************************************************************************

        Flush everything to file and prepare for the next iteration

    ***************************************************************************/

    public void flush ( )
    {
        this.logger.info(this.layout[]);
        this.add_separator = false;
        this.layout.clear();
    }


    /***************************************************************************

        Writes the values from the provided aggregate to the format_buffer
        member.

        Each member of the aggregate is output as either:
        <category name>/<object name>/<member name>:<member value>
        if a category is provided, or as:
        <member name>:<member value>
        if no category is provided.
        It's a runtime error to provide a category but no instance name, or the
        other way around.

        Note: When the aggregate is a class, the members of the super class
        are not iterated over.

        Template_Params:
            category = the type or category of the object, such as 'channels',
                       'users'... May be null (see the 'instance' parameter).
            T = the type of the aggregate containing the fields to log

        Params:
            values = aggregate containing values to write to the log. Passed as
                     ref purely to avoid making a copy -- the aggregate is not
                     modified.
            instance = the name of the instance of the category, or null if
                none. For example, if the category is 'companies', then the name
                of an instance may be "google". This value should be null if
                category is null, and non-null otherwise.

    ***************************************************************************/

    private void format ( istring category, T ) ( ref T values, cstring instance )
    {
        foreach ( i, value; values.tupleof )
        {
            auto value_name = FieldName!(i, T);

            static if (is(typeof(value) : long))
                long fmtd_value = value;
            else static if (is(typeof(value) : double))
                double fmtd_value = value;
            else
            {
                pragma(msg, "[", __FILE__, ":", __LINE__, "] '", T.stringof,
                       "' should only contain integer or floating point members");
                auto fmtd_value = value;
            }

            // stringof results in something like "values.somename", we want
            // only "somename"
            if (this.add_separator)
            {
                this.layout(' ');
            }

            static if (category.length)
            {
                assert(instance.length);
                this.layout(category, '/', instance, '/', value_name, ':',
                    fmtd_value);
            }
            else
            {
                assert(!instance.length);
                this.layout(value_name, ':', fmtd_value);
            }

            this.add_separator = true;
        }
    }
}

/// Usage example for StatsLog in a simple application
unittest
{
    class MyStatsLogApp : DaemonApp
    {
        private static struct Stats
        {
            double awesomeness;
            double bytes_written;
            double bytes_received;
        }

        private static struct Channel
        {
            double profiles_in;
            double profiles_out;
        }

        public this ()
        {
            super(null, "Test", null, null);
        }

        protected override int run (Arguments args, ConfigParser config)
        {
            return 0;
        }

        protected override void onStatsTimer ( )
        {
            // Do some heavy-duty processing ...
            Stats app_stats1 = { 42_000_000, 10_000_000,  1_000_000 };
            Stats app_stats2 = { 42_000_000,  1_000_000, 10_000_000 };
            this.stats_ext.stats_log.add(app_stats1);

            // A given struct should be `add`ed once and only once, unless
            // you flush in between
            this.stats_ext.stats_log.flush();
            this.stats_ext.stats_log.add(app_stats2);

            // Though if you use `addObject`, it's okay as long as the instance
            // name is different
            Channel disney = { 100_000, 100_000 };
            Channel discovery = { 10_000, 10_000 };

            // For the same struct type, you probably want the
            // same category name. It's not a requirement but there are
            // no known use case where you want it to differ.
            this.stats_ext.stats_log.addObject!("channel")("disney", disney);
            this.stats_ext.stats_log.addObject!("channel")("discovery", discovery);
        }
    }
}
