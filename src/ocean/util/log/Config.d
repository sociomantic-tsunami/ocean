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
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.log.Config;


import ocean.transition;

import ocean.io.Stdout;
import ocean.core.Array : insertShift, removePrefix, removeSuffix, sort;
import ocean.util.config.ConfigFiller;
import ocean.util.config.ConfigParser;
import ocean.util.log.AppendFile;
import ocean.util.log.AppendSysLog;
import ocean.stdc.string;
import ocean.text.util.StringSearch;

import ocean.util.log.Logger;
import ocean.util.log.InsertConsole;
import ocean.util.log.Appender;
import ocean.util.log.AppendStderrStdout;
import ocean.util.log.Event;
import ocean.util.log.model.ILogger;

// Log layouts
import ocean.util.log.layout.LayoutMessageOnly;
import ocean.util.log.layout.LayoutStatsLog;
import ocean.util.log.layout.LayoutSimple;
import ocean.util.log.LayoutDate;



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

    public istring console_layout = "simple";

    /***************************************************************************

        Whether to use file output and if, which file path

    ***************************************************************************/

    public SetInfo!(istring) file;

    /***************************************************************************

        Layout to use for file output

    ***************************************************************************/

    public istring file_layout = "date";

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
        an instance of a suitable layout based on the input string

    Throws:
        if `layout_str` cannot be matched to any layout

*******************************************************************************/

public Layout newLayout ( cstring layout_str )
{
    mstring tweaked_str = layout_str.dup;

    StringSearch!() s;

    s.strToLower(tweaked_str);

    tweaked_str = removePrefix(tweaked_str, "layout");

    tweaked_str = removeSuffix(tweaked_str, "layout");

    switch ( tweaked_str )
    {
        case "messageonly":
            return new LayoutMessageOnly;

        case "stats":
        case "statslog":
            return new LayoutStatsLog;

        case "simple":
            return new LayoutSimple;

        case "date":
            return new LayoutDate;

        default:
            // Has to be 2 statements because `istring ~ cstring`
            // yields `cstring` instead of `istring`.
            istring msg = "Invalid layout requested : ";
            msg ~= layout_str;
            throw new Exception(msg, __FILE__, __LINE__);
    }
}

///
unittest
{
    // In a real app those would be full-fledged implementation
    alias LayoutSimple AquaticLayout;
    alias LayoutSimple SubmarineLayout;

    void myConfigureLoggers (
        ClassIterator!(Config, ConfigParser) config,
        MetaConfig m_config,
        scope Appender delegate ( istring file, Layout layout ) file_appender,
        bool use_insert_appender = false)
    {
        Layout makeLayout (cstring name)
        {
            if (name == "aquatic")
                return new AquaticLayout;
            if (name == "submarine")
                return new SubmarineLayout;
            return ocean.util.log.Config.newLayout(name);
        }
        ocean.util.log.Config.configureNewLoggers(config, m_config,
            file_appender, &makeLayout, use_insert_appender);
    }
}

/*******************************************************************************

    Sets up logging configuration for `ocean.util.log.Logger`

    Calls the provided `file_appender` delegate once per log being configured and
    passes the returned appender to the log's add() method.

    Params:
        config   = an instance of an class iterator for Config
        m_config = an instance of the MetaConfig class
        file_appender = delegate which returns appender instances to write to
                        a file
        use_insert_appender = true if the InsertConsole appender should be used
                              (needed when using the AppStatus module)

*******************************************************************************/

public void configureNewLoggers (
    ClassIterator!(Config, ConfigParser) config, MetaConfig m_config,
    scope Appender delegate ( istring file, Layout layout ) file_appender,
    bool use_insert_appender = false)
{
    configureNewLoggers(config, m_config, file_appender,
        (cstring v) { return newLayout(v); }, use_insert_appender);
}


/*******************************************************************************

    Sets up logging configuration for `ocean.util.log.Logger`

    Calls the provided `file_appender` delegate once per log being configured
    and passes the returned `Appender` to the `Logger.add` method.

    This is an extra overload because using a delegate literal as a parameter's
    default argument causes linker error in D1.

    Params:
        config   = an instance of an class iterator for Config
        m_config = an instance of the MetaConfig class
        file_appender = delegate which returns appender instances to write to
                        a file
        makeLayout = A delegate that returns a `Layout` instance from
                     a name, or throws on error.
                     By default, wraps `ocean.util.log.Config.newLayout`
        use_insert_appender = true if the InsertConsole appender should be used
                              (needed when using the AppStatus module)

*******************************************************************************/

public void configureNewLoggers (
    ClassIterator!(Config, ConfigParser) config, MetaConfig m_config,
    scope Appender delegate ( istring file, Layout layout ) file_appender,
    scope Layout delegate (cstring) makeLayout, bool use_insert_appender = false)
{
    // DMD1 cannot infer the common type between both return, we have to work
    // around it...
    static Appender console_appender_fn (bool insert_appender, Layout layout)
    {
        if (insert_appender)
            return new InsertConsole(layout);
        else
            return new AppendStderrStdout(ILogger.Level.Warn, layout);
    }

    // The type needs to be spelt out loud because DMD2 is clever enough
    // to see it's a function and not a delegate, but not clever enough
    // to understand we want a delegate in the end...
    scope Appender delegate(Layout) appender_dg = (Layout l)
                       { return console_appender_fn(use_insert_appender, l); };

    configureLoggers(config, m_config, file_appender, appender_dg, makeLayout);
}


/*******************************************************************************

    Sets up logging configuration. Calls the provided file_appender delegate once
    per log being configured and passes the returned appender to the log's add()
    method.

    Params:
        config   = an instance of an class iterator for Config
        m_config = an instance of the MetaConfig class
        file_appender = delegate which returns appender instances to write to
                        a file
        console_appender = Delegate which returns an Appender suitable to use
                           as console appender. Might not be called if console
                           writing is disabled.
        makeLayout      = A delegate that returns a `Layout` instance from
                          a name, or throws on error.

*******************************************************************************/

private void configureLoggers
    (ClassIterator!(Config, ConfigParser) config, MetaConfig m_config,
     scope Appender delegate (istring file, Layout layout) file_appender,
     scope Appender delegate (Layout) console_appender,
     scope Layout delegate (cstring) makeLayout)
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

    foreach (name; logger_names)
    {
        bool console_enabled = false;
        bool syslog_enabled = false;

        config.fill(name, settings);

        if (root_name == name)
        {
            name = null;
            console_enabled = settings.console(true);
            syslog_enabled = settings.syslog(false);
        }
        else
        {
            console_enabled = settings.console();
            syslog_enabled = settings.syslog();
        }
        configureLogger(name.length ? Log.lookup(name) : Log.root,
             settings, name,
             file_appender, console_appender,
             console_enabled, syslog_enabled, m_config.buffer_size,
             makeLayout);
    }
}


/*******************************************************************************

    Sets up logging configuration. Calls the provided file_appender delegate once
    per log being configured and passes the returned appender to the log's add()
    method.

    Params:
        log      = Logger to configure
        settings = an instance of an class iterator for Config
        name     = name of this logger
        file_appender = delegate which returns appender instances to write to
                        a file
        console_appender = Delegate which returns an Appender suitable to use
                           as console appender. Might not be called if console
                           writing is disabled.
        console_enabled = `true` if a console appender should be added (by
                          calling `console_enabled`).
        syslog_enabled  = `true` if a syslog appender should be added.
        makeLayout      = A delegate that returns a `Layout` instance from
                          a name, or throws on error.
                          By default, wraps `ocean.util.log.Config.newLayout`.

*******************************************************************************/

public void configureLogger
    (Logger log, Config settings, istring name,
     scope Appender delegate ( istring file, Layout layout ) file_appender,
     scope Appender delegate (Layout) console_appender,
     bool console_enabled, bool syslog_enabled, size_t buffer_size,
     scope Layout delegate (cstring) makeLayout = (cstring v) { return newLayout(v); })
{
    if (settings.buffer_size)
        buffer_size = settings.buffer_size;

    if (buffer_size > 0)
        log.buffer(new mstring(buffer_size));

    log.clear();

    // if console/file/syslog is specifically set, don't inherit other
    // appenders (unless we have been specifically asked to be additive)
    log.additive = settings.additive ||
        !(settings.console.set || settings.file.set || settings.syslog.set);

    if (settings.file.set)
    {
        log.add(file_appender(settings.file(), makeLayout(settings.file_layout)));
    }

    if (syslog_enabled)
        log.add(new AppendSysLog);

    if (console_enabled)
    {
        log.add(console_appender(makeLayout(settings.console_layout)));
    }

    log.collectStats(settings.collect_stats, settings.propagate);
    setupLoggerLevel(log, name, settings);
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

    configureNewLoggers(log_config, dummy_meta_config, &appender);

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
    with (config) if (level.length > 0)
    {
        StringSearch!() s;

        level = s.strEnsureLower(level);

        switch (level)
        {
            case "trace":
            case "debug":
                log.level(ILogger.Level.Trace, propagate);
                break;

            case "info":
                log.level(ILogger.Level.Info, propagate);
                break;

            case "warn":
                log.level(ILogger.Level.Warn, propagate);
                break;

            case "error":
                log.level(ILogger.Level.Error, propagate);
                break;

            case "fatal":
                log.level(ILogger.Level.Fatal, propagate);
                break;

            case "none":
            case "off":
            case "disabled":
                log.level(ILogger.Level.None, propagate);
                break;

            default:
                throw new Exception(cast(istring) ("Invalid log level '"
                                                   ~ level ~ "' " ~
                                                   "requested for logger '"
                                                   ~ name ~ "'"));
        }
    }
}
