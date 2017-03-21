/*******************************************************************************

    Application extension to parse configuration files for the logging system.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.ext.LogExt;

import ocean.core.TypeConvert;
import ocean.io.device.File;
import ocean.stdc.string;
import ocean.text.convert.Formatter;
import ocean.text.util.SplitIterator;
import ocean.transition;
import ocean.util.app.Application;
import ocean.util.app.ext.ConfigExt;
import ocean.util.app.ext.model.IConfigExtExtension;
import ocean.util.app.ext.model.ILogExtExtension;
import ocean.util.app.ext.ReopenableFilesExt;
import ocean.util.app.model.ExtensibleClassMixin;
import ConfigFiller = ocean.util.config.ConfigFiller;
import ocean.util.config.ConfigParser;
import ocean.util.log.Appender;
import LogUtil = ocean.util.log.Config;
import ocean.util.log.Logger;
import ocean.util.log.model.ILogger;


/*******************************************************************************

    Application extension to parse configuration files for the logging system.

    This extension is an extension itself, providing new hooks via
    ILogExtExtension.

*******************************************************************************/

class LogExt : IConfigExtExtension
{
    /***************************************************************************

        Adds a list of extensions (this.extensions) and methods to handle them.
        See ExtensibleClassMixin documentation for details.

    ***************************************************************************/

    mixin ExtensibleClassMixin!(ILogExtExtension);


    /***************************************************************************

        True if the InsertConsole appender should be used instead of the regular
        one. The InsertConsole appender is needed when using the AppStatus
        module.

    ***************************************************************************/

    public bool use_insert_appender;


    /// If set, will be used by `makeLayout` to map a name to a `Layout`
    private Appender.Layout delegate (cstring name) layout_maker;


    /***************************************************************************

        Constructor.

        Params:
            use_insert_appender = true if the InsertConsole appender should be
                                  used (needed when using the AppStatus module)

    ***************************************************************************/

    this ( bool use_insert_appender )
    {
        this(null, use_insert_appender);
    }


    /***************************************************************************

        Constructor.

        Params:
            make_layout         = A delegate that instantiates an
                                  `Appender.Layout` from a name. If null,
                                  defaults to `ocean.util.Config: newLayout`.
            use_insert_appender = true if the InsertConsole appender should be
                                  used (needed when using the AppStatus module)

    ***************************************************************************/

    public this ( Appender.Layout delegate (cstring name) make_layout = null,
                  bool use_insert_appender = false )
    {
        this.layout_maker = make_layout is null ? &this.makeLayoutDefault
            : make_layout;

        this.use_insert_appender = use_insert_appender;
    }

    /***************************************************************************

        Extension order. This extension uses -1_000 because it should be
        called early, but after the ConfigExt extension.

        Returns:
            the extension order

    ***************************************************************************/

    public override int order ( )
    {
        return -1_000;
    }


    /***************************************************************************

        Parse the configuration file options to set up the loggers.

        Params:
            app = the application instance
            config = configuration instance

    ***************************************************************************/

    public override void processConfig ( IApplication app, ConfigParser config )
    {
        auto conf_ext = (cast(Application)app).getExtension!(ConfigExt);

        foreach (ext; this.extensions)
        {
            ext.preConfigureLoggers(app, config, conf_ext.loose_config_parsing,
                    this.use_insert_appender);
        }

        auto log_config = ConfigFiller.iterate!(LogUtil.Config)("LOG", config);
        auto log_meta_config = ConfigFiller.fill!(LogUtil.MetaConfig)("LOG", config);

        Appender appender ( istring file, LogUtil.Layout layout )
        {
            auto stream = new File(file, File.WriteAppending);
            if ( auto reopenable_files_ext =
                (cast(Application)app).getExtension!(ReopenableFilesExt) )
            {
                reopenable_files_ext.register(stream);
            }
            return new AppendStream(stream, true, layout);
        }

        ConfigFiller.enable_loose_parsing(conf_ext.loose_config_parsing);

        LogUtil.configureNewLoggers(log_config, log_meta_config, &appender,
            this.layout_maker, this.use_insert_appender);

        foreach (ext; this.extensions)
        {
            ext.postConfigureLoggers(app, config, conf_ext.loose_config_parsing,
                    this.use_insert_appender);
        }
    }


    /***************************************************************************

        Unused IConfigExtExtension methods.

        We just need to provide an "empty" implementation to satisfy the
        interface.

        Params:
            app = the application instance
            config = configuration instance

    ***************************************************************************/

    public override void preParseConfig ( IApplication app, ConfigParser config )
    {
        // Unused
    }


    /***************************************************************************

        Function to filter the list of configuration files to parse.
        Only present to satisfy the interface

        Params:
            app = the application instance
            config = configuration instance
            files = current list of configuration files to parse

        Returns:
            new list of configuration files to parse

    ***************************************************************************/

    public override istring[] filterConfigFiles ( IApplication app,
                                         ConfigParser config,
                                         istring[] files )
    {
        // Unused
        return files;
    }


    /***************************************************************************

        Default for layout_maker. DMD complains because `LogUtil.newLayout`
        is a function, not a delegate.

        Params:
            name = name of the Layout to instantiate.

        Throws:
            `Exception` if it cannot match the name

        Returns:
            A new Layout instance matching name

    ***************************************************************************/

    private Appender.Layout makeLayoutDefault ( cstring name )
    {
        return LogUtil.newLayout(name);
    }

    /***************************************************************************

        Support for dynamic configuration of `Logger` through `UnixSocketExt`

        Entry point (handler) which is passed to `UnixSocketExt`.
        From there, forwards to `unixSocketCommand`.

        Params:
            args = Arguments passed via the unix socket, split on space
            send = Delegate to use to answer

    ***************************************************************************/

    public void unixSocketHandler ( cstring[] args, UnixSocketSink send )
    {
        if (!args.length || args[0] == "help")
            return sendUsage(send);

        if (args[0] == "set")
        {
            // Need at least: 'set', 'LoggerName', 'k=v'
            if (args.length < 3)
                return sendUsage(send);

            auto logger = icmp(args[1], "root") ? Log.root : Log.lookup(args[1]);
            // We do not want to half-reconfigure a logger, it should be all or
            // nothing, which is why we have this recursive logic instead of
            // a loop.
            if (this.unixSocketCommand(send, logger.additive(), logger,
                                       args[2 .. $]))
                return send("OK\n");
            else
                return send("Error happened while processing command 'set'\n");
        }

        send("Invalid command: ");
        send(args[0]);
        send("\n\n");
        return sendUsage(send);
    }

    /// Type of sink for the UnixSocketHandler
    private alias void delegate (cstring msg) UnixSocketSink;

    /// Perform a case-insensitive string comparison
    private static bool icmp (cstring a, cstring b)
    {
        return a.length == b.length && !strncasecmp(a.ptr, b.ptr, a.length);
    }

    /***************************************************************************

        Write usage information to the provided delegate

        Params:
            send = Delegate to write the usage information to

    ***************************************************************************/

    private static void sendUsage ( UnixSocketSink send )
    {
        send(`SetLogger is a command to change the configuration of a logger
The modification is temporary and will not be in effect after restart

Usage: SetLogger help
       SetLogger set Name [ARGS...]

    - help  = Print this usage message;
    - set   = Set the provided arguments for logger 'Name', keep existing values intact

Arguments to 'set' are key-value pairs, e.g. 'level=trace' or 'file=log/newfile.log'.
Note that the order in which arguments are processed is not guaranteed,
except for 'additive' which will affect subsequent arguments.
As a result, if 'additive' is provided, it should be before 'level',
or it won't be taken into account.
`);
    }


    /***************************************************************************

        Reconfigure a logger according to the commands

        Recurses to ensure all modifications happen, or none at all.

        Params:
            send      = Delegate to use to respond to the user
            propagate = Whether the user want the modification to propagate to
                        child loggers. By default, use the `additive` property
                        of the Logger (which is `true` by default).
            logger    = Logger to reconfigure
            remaining = Remaining arguments to process

        Returns:
            Whether reconfiguring succeeded (`true`) or not (`false`).

    ***************************************************************************/

    private bool unixSocketCommand ( UnixSocketSink send, bool additive,
                                     Logger logger, in cstring[] remaining )
    {
        if (!remaining.length)
            return true;

        scope it = new ChrSplitIterator('=');
        it.reset(remaining[0]);
        cstring opt = it.next();
        cstring value = it.remaining();

        if (icmp(opt, "additive"))
        {
            if (icmp(value, "true") || icmp(value, "1"))
                additive = true;
            else if (icmp(value, "false") || icmp(value, "0"))
                additive = false;
            else
            {
                sformat(send, "Error: '{}' is not a recognized boolean value. "
                        ~ "Use 'true', 'false', '1' or '0'\n", value);
                return false;
            }

            return this.unixSocketCommand(send, additive, logger, remaining[1 .. $]);
        }

        if (icmp(opt, "level"))
        {
            auto lvl = ILogger.convert(value, logger.level());
            if (this.unixSocketCommand(send, additive, logger, remaining[1 .. $]))
            {
                logger.level(lvl, additive);
                return true;
            }
            return false;
        }

        sformat(send, "Changing property {} is not implemented\n", opt);
        return false;
    }
}
