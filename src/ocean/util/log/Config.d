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
import ocean.core.Array : removePrefix, removeSuffix;
import ocean.util.config.ClassFiller;
import ocean.util.config.ConfigParser;
import ocean.util.log.AppendSysLog;
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

    Sets up logging configuration. Calls the provided new_appender delegate once
    per log being configured and passes the returned appender to the log's add()
    method.

    Template_Params:
        Source = the type of the config parser
        FileLayout = layout to use for logging to file, defaults to LayoutDate
        ConsoleLayout = layout to use for logging to console, defaults to
                        LayoutSimple

    Params:
        config   = an instance of an class iterator for Config
        m_config = an instance of the MetaConfig class
        new_appender = delegate which returns appender instances to be used in
            the loggers created in this function
        loose = if true, configuration files will be parsed in a more relaxed
                manner
        use_insert_appender = true if the InsertConsole appender should be used
                              (needed when using the AppStatus module)

*******************************************************************************/

public void configureLoggers ( Source = ConfigParser, FileLayout = LayoutDate,
    ConsoleLayout = LayoutSimple )
    ( ClassIterator!(Config, Source) config, MetaConfig m_config,
    Appender delegate ( istring file, Layout layout ) new_appender,
    bool loose = false, bool use_insert_appender = false )
{
    enable_loose_parsing(loose);

    foreach (name, settings; config)
    {
        bool console_enabled = false;
        bool syslog_enabled = false;
        Logger log;

        if ( name == "Root" )
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
            log.add(new_appender(settings.file(), file_log_layout));
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

            if ( use_insert_appender )
            {
                log.add(new InsertConsole(console_log_layout));
            }
            else
            {
                log.add(new AppendStderrStdout(Level.Warn, console_log_layout));
            }
        }

        setupLoggerLevel(log, name, settings);
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
