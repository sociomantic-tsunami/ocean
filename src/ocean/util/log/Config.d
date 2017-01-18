/*******************************************************************************

    Utility functions to configure tango loggers from a config file.

    Configures tango loggers, uses the AppendSyslog class to provide logfile
    rotation.

    In the config file, a logger can be configured using the following syntax:

        ; Which logger to configure. In this case LoggerName is being configured.
        ; A whole hierachy can be specified like LOG.MyApp.ThatOutput.X
        ; And each level can be configured.
        [LOG.LoggerName]

        ; Whether to output to the terminal
        ; warn, error, and fatal are written to stderr, info and trace to stdout
        console   = true

        ; File to output to, no output to file if not given
        file      = log/logger_name.log

        ; Whether to propagate the options down in the hierachy
        propagate = false

        ; The verbosity level, corresponse to the tango logger levels
        level     = info

        ; Is this logger additive? That is, should we walk ancestors
        ; looking for more appenders?
        additive  = true

    Note that `LOG.Root` will be treated specially: it will configure the
    'root' logger, which is the parent of all loggers.
    `Root` is case insensitive, so `LOG.root` or `LOG.ROOT` will work as well.

    See the class Config for further options and documentation.

    There are global logger configuration options as well:

        ; Global options are in the section [LOG]
        [LOG]

        ; Maximum amount of files that will exist.
        file_count    = 10

        ; Maximum size of one file in bytes till it will be rotated
        ;
        max_file_size = 500000

        ; files equal or higher this value will be compressed
        start_compress = 4

        ; Buffer size for output
        buffer_size = 2048

    See the class MetaConfig for further options and documentation.

    Upon calling the configureLoggers function, logger related configuration
    will be read and the according loggers configured accordingly.

    Usage Example (you probably will only need to do this):

    ----
        import Log = ocean.util.log.Config;
        // ...
        Log.configureLoggers(Config().iterateCategory!(Log.Config)("LOG"),
                             Config().get!(Log.MetaConfig)("LOG"));
    ----

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.log.Config;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.io.Stdout;
import ocean.core.Array : insertShift, removePrefix, removeSuffix, sort;
import ocean.util.config.ConfigFiller;
import ocean.util.config.ConfigParser;
import ocean.util.log.AppendFile;
import ocean.util.log.AppendSysLog;
import ocean.stdc.string;
import ocean.text.util.StringSearch;

import ocean.util.log.Log;
import ocean.util.log.InsertConsole;
import ocean.util.log.AppendStderrStdout;

// Log layouts
import ocean.util.log.layout.LayoutMessageOnly;
import ocean.util.log.layout.LayoutStatsLog;
import ocean.util.log.layout.LayoutSimple;
import ocean.util.log.LayoutDate;
import ocean.util.log.LayoutChainsaw;


/*******************************************************************************

    Configuration class for loggers

*******************************************************************************/

class Config
{
    /***************************************************************************

        Level of the logger

    ***************************************************************************/

    public cstring level;

    /***************************************************************************

        Whether to use console output or not

    ***************************************************************************/

    public SetInfo!(bool) console;

    /***************************************************************************

        Whether to use syslog output or not

    ***************************************************************************/

    public SetInfo!(bool) syslog;

    /***************************************************************************

        Layout to use for console output

    ***************************************************************************/

    public istring console_layout;

    /***************************************************************************

        Whether to use file output and if, which file path

    ***************************************************************************/

    public SetInfo!(istring) file;

    /***************************************************************************

        Layout to use for file output

    ***************************************************************************/

    public istring file_layout;

    /***************************************************************************

        Whether to propagate that level to the children

    ***************************************************************************/

    public bool propagate;

    /***************************************************************************

        Whether this logger should be additive or not

    ***************************************************************************/

    bool additive;

    /***************************************************************************

        Whether this logger should be part of the global logging stats
        mechanism

    ***************************************************************************/

    bool collect_stats = true;

    /***************************************************************************

        Buffer size of the buffer output, overwrites the global setting
        given in MetaConfig

    ***************************************************************************/

    public size_t buffer_size = 0;
}

/*******************************************************************************

    Configuration class for logging

*******************************************************************************/

class MetaConfig
{
    /***************************************************************************

        How many files should be created

    ***************************************************************************/

    size_t file_count    = 10;

    /***************************************************************************

        Maximum size of one log file

    ***************************************************************************/

    size_t max_file_size = 500 * 1024 * 1024;

    /***************************************************************************

        Index of the first file that should be compressed

        E.g. 4 means, start compressing with the fourth file

    ***************************************************************************/

    size_t start_compress = 4;

    /***************************************************************************

        Tango buffer size, if 0, internal stack based buffer of 2048 will be
        used.

    ***************************************************************************/

    size_t buffer_size   = 0;
}

/*******************************************************************************

    Convenience alias for iterating over Config classes

*******************************************************************************/

alias ClassIterator!(Config) ConfigIterator;

/*******************************************************************************

    Convenience alias for layouts

*******************************************************************************/

alias Appender.Layout Layout;

/*******************************************************************************

    Gets a new layout instance, based on the given name.

    Params:
        layout_str = name of the desired layout

    Returns:
        an instance of a suitable layout based on the input string, or an
        instance of 'LayoutMessageOnly' if no suitable layout was identified.

*******************************************************************************/

public Layout newLayout ( istring layout_str )
{
    Layout layout;

    mstring tweaked_str = layout_str.dup;

    StringSearch!() s;

    s.strToLower(tweaked_str);

    tweaked_str = removePrefix(tweaked_str, "layout");

    tweaked_str = removeSuffix(tweaked_str, "layout");

    switch ( tweaked_str )
    {
        case "messageonly":
            layout = new LayoutMessageOnly;
            break;

        case "stats":
        case "statslog":
            layout = new LayoutStatsLog;
            break;

        case "simple":
            layout = new LayoutSimple;
            break;

        case "date":
            layout = new LayoutDate;
            break;

        case "chainsaw":
            layout = new LayoutChainsaw;
            break;

        default:
            throw new Exception("Invalid layout requested : " ~ layout_str);
    }

    return layout;
}

/*******************************************************************************

    Clear any default appenders at startup

*******************************************************************************/

static this ( )
{
    Log.root.clear();
}

/*******************************************************************************

    Sets up logging configuration. Creates an AppendSysLog appender for each
    log.

    Template_Params:
        Source = the type of the config parser
        FileLayout = layout to use for logging to file, defaults to LayoutDate
        ConsoleLayout = layout to use for logging to console, defaults to
                        LayoutSimple

    Params:
        config   = an instance of an class iterator for Config
        m_config = an instance of the MetaConfig class
        loose = if true, configuration files will be parsed in a more relaxed
                manner
        use_insert_appender = true if the InsertConsole appender should be used
                              (needed when using the AppStatus module)

    Throws:
        Exception if the config for a logger specifies an invalid level

*******************************************************************************/

public void configureLoggers ( Source = ConfigParser, FileLayout = LayoutDate,
                               ConsoleLayout = LayoutSimple )
                             ( ClassIterator!(Config, Source) config,
                               MetaConfig m_config, bool loose = false,
                               bool use_insert_appender = false )
{
    Appender newAppender ( istring file, Appender.Layout layout )
    {
        return new AppendFile(file, layout);
    }

    configureLoggers!(Source, FileLayout, ConsoleLayout)
        (config, m_config, &newAppender, loose, use_insert_appender);
}

/*******************************************************************************

    Instantiate the template to make sure it compiles but doesn't test it.

*******************************************************************************/

unittest
{
    void f ( )
    {
        configureLoggers!()(ClassIterator!(Config, ConfigParser).init,
            MetaConfig.init);
    }
}

/*******************************************************************************

    Sets up logging configuration. Calls the provided file_appender delegate once
    per log being configured and passes the returned appender to the log's add()
    method.

    Params:
        Source = the type of the config parser
        FileLayout = layout to use for logging to file, defaults to LayoutDate
        ConsoleLayout = layout to use for logging to console, defaults to
                        LayoutSimple
        config   = an instance of an class iterator for Config
        m_config = an instance of the MetaConfig class
        file_appender = delegate which returns appender instances to write to
                        a file
        loose = if true, configuration files will be parsed in a more relaxed
                manner
        use_insert_appender = true if the InsertConsole appender should be used
                              (needed when using the AppStatus module)

*******************************************************************************/

public void configureLoggers ( Source = ConfigParser, FileLayout = LayoutDate,
    ConsoleLayout = LayoutSimple )
    ( ClassIterator!(Config, Source) config, MetaConfig m_config,
    Appender delegate ( istring file, Layout layout ) file_appender,
    bool loose = false, bool use_insert_appender = false )
{
    // DMD1 cannot infer the common type between both return, we have to work
    // around it...
    static Appender console_appender_fn (bool insert_appender, Layout layout)
    {
        if (insert_appender)
            return new InsertConsole(layout);
        else
            return new AppendStderrStdout(Level.Warn, layout);
    }

    enable_loose_parsing(loose);

    configureLoggers!(Source, FileLayout, ConsoleLayout)
        (config, m_config, file_appender,
         (Layout l) { return console_appender_fn(use_insert_appender, l); });
}

/*******************************************************************************

    Sets up logging configuration. Calls the provided file_appender delegate once
    per log being configured and passes the returned appender to the log's add()
    method.

    Params:
        Source = the type of the config parser
        FileLayout = layout to use for logging to file, defaults to LayoutDate
        ConsoleLayout = layout to use for logging to console, defaults to
                        LayoutSimple

        config   = an instance of an class iterator for Config
        m_config = an instance of the MetaConfig class
        file_appender = delegate which returns appender instances to write to
                        a file
        console_appender = Delegate which returns an Appender suitable to use
                           as console appender. Might not be called if console
                           writing is disabled.

*******************************************************************************/

private void configureLoggers
    (Source = ConfigParser, FileLayout = LayoutDate, ConsoleLayout = LayoutSimple)
    (ClassIterator!(Config, Source) config, MetaConfig m_config,
     Appender delegate (istring file, Layout layout) file_appender,
     Appender delegate (Layout) console_appender)
{
    // It is important to ensure that parent loggers are configured before child
    // loggers. This is because parent loggers will override the settings of
    // child loggers when the 'propagate' property is enabled, thus preventing
    // child loggers from customizing their properties via the config file(s).
    // However, since the parsed configuration is stored in an AA, ordered
    // iteration of the logging config is not directly possible. For this
    // reason, the names of all loggers present in the configuration are first
    // sorted, and the loggers are then configured based on the sorted list. The
    // sorting is performed in increasing order of the lengths of the logger
    // names so that parent loggers appear before child loggers.

    istring[] logger_names;
    istring   root_name;

    foreach (name; config)
    {
        if (name.length == "root".length
            && strncasecmp(name.ptr, "root".ptr, "root".length) == 0)
            root_name = name;
        else
            logger_names ~= name;
    }

    sort(logger_names);
    // As 'Root' is the parent logger of all loggers, we need to special-case it
    // and put it at the beginning of the list
    if (root_name.length)
    {
        logger_names.insertShift(0);
        logger_names[0] = root_name;
    }

    Config settings;

    foreach(name; logger_names)
    {
        bool console_enabled = false;
        bool syslog_enabled = false;
        Logger log;

        config.fill(name, settings);

        if ( root_name == name )
        {
            log = Log.root;
            console_enabled = settings.console(true);
            syslog_enabled = settings.syslog(false);
        }
        else
        {
            log = Log.lookup(name);
            console_enabled = settings.console();
            syslog_enabled = settings.syslog();
        }

        size_t buffer_size = m_config.buffer_size;
        if ( settings.buffer_size )
        {
            buffer_size = settings.buffer_size;
        }

        if ( buffer_size > 0 )
        {
            log.buffer(new mstring(buffer_size));
        }

        log.clear();

        // if console/file/syslog is specifically set, don't inherit other
        // appenders (unless we have been specifically asked to be additive)
        log.additive = settings.additive ||
            !(settings.console.set || settings.file.set || settings.syslog.set);

        if ( settings.file.set )
        {
            Layout file_log_layout = (settings.file_layout.length)
                                         ? newLayout(settings.file_layout)
                                         : new FileLayout;
            log.add(file_appender(settings.file(), file_log_layout));
        }

        if ( syslog_enabled )
        {
            log.add(new AppendSysLog);
        }

        if ( console_enabled )
        {
            Layout console_log_layout = (settings.console_layout.length)
                                            ? newLayout(settings.console_layout)
                                            : new ConsoleLayout;

            log.add(console_appender(console_log_layout));
        }

        log.collectStats(settings.collect_stats, settings.propagate);

        setupLoggerLevel(log, name, settings);
    }
}

version (UnitTest)
{
    import ocean.core.Array : copy;
    import ocean.core.Test : test;
}

// When the 'propagate' property of a logger is set, its settings get propagated
// to all child loggers. However, every child logger should be able to define
// its own settings overriding any automatically propagated setting from the
// parent logger. Since loggers are stored in an AA, the order in which they are
// configured is undeterministic. This could potentially result in parent
// loggers being configured after child loggers and thus overriding any
// specifically defined setting in the child logger. To avoid this from
// happening, parent loggers are deliberately configured before child loggers.
// This unit test block confirms that this strict configuration order is
// enforced, and parent loggers never override the settings of child loggers.
unittest
{
    class TempAppender : Appender
    {
        private mstring latest_log_msg;
        private Mask mask_;

        final override public void append (LogEvent event)
        {
            copy(this.latest_log_msg, event.toString());
        }

        final override public Mask mask () { return this.mask_; }
        final override public istring name () { return null; }
    }

    auto config_parser = new ConfigParser();

    auto config_str =
`
[LOG.A]
level = trace
propagate = true
file = dummy

[LOG.A.B]
level = info
propagate = true
file = dummy

[LOG.A.B.C]
level = warn
propagate = true
file = dummy

[LOG.A.B.C.D]
level = error
propagate = true
file = dummy

[LOG.Root]
level = trace
propagate = true
file = dummy
`;

    auto temp_appender = new TempAppender;

    Appender appender(istring, Layout)
    {
        return temp_appender;
    }

    config_parser.parseString(config_str);

    auto log_config = iterate!(Config)("LOG", config_parser);
    auto dummy_meta_config = new MetaConfig();

    configureLoggers(log_config, dummy_meta_config, &appender);

    auto log_D = Log.lookup("A.B.C.D");

    log_D.trace("trace log (shouldn't be sent to appender)");
    test!("==")(temp_appender.latest_log_msg, "");

    log_D.info("info log (shouldn't be sent to appender)");
    test!("==")(temp_appender.latest_log_msg, "");

    log_D.warn("warn log (shouldn't be sent to appender)");
    test!("==")(temp_appender.latest_log_msg, "");

    log_D.error("error log");
    test!("==")(temp_appender.latest_log_msg, "error log");

    log_D.fatal("fatal log");
    test!("==")(temp_appender.latest_log_msg, "fatal log");
}

/*******************************************************************************

    Instantiate the template to make sure it compiles but doesn't test it.

*******************************************************************************/

unittest
{
    void f ( )
    {
        Appender delegate ( istring file, Layout layout ) file_appender;
        configureLoggers!()(ClassIterator!(Config, ConfigParser).init,
            MetaConfig.init, file_appender);
    }
}

/*******************************************************************************

    Sets up the level configuration of a logger.

    Params:
        log = logger to configure
        name = name of logger
        config = config settings for the logger

    Throws:
        Exception if the config for a logger specifies an invalid level

*******************************************************************************/

public void setupLoggerLevel ( Logger log, istring name, Config config )
{
    with (config) if ( level.length > 0 )
    {
        StringSearch!() s;

        level = s.strEnsureLower(level);

        switch ( level )
        {
            case "trace":
            case "debug":
                log.level(Level.Trace, propagate);
                break;

            case "info":
                log.level(Level.Info, propagate);
                break;

            case "warn":
                log.level(Level.Warn, propagate);
                break;

            case "error":
                log.level(Level.Error, propagate);
                break;

            case "fatal":
                log.level(Level.Fatal, propagate);
                break;

            case "none":
            case "off":
            case "disabled":
                log.level(Level.None, propagate);
                break;

            default:
                throw new Exception(cast(istring) ("Invalid log level '"
                                                   ~ level ~ "' " ~
                                                   "requested for logger '"
                                                   ~ name ~ "'"));
        }
    }
}
