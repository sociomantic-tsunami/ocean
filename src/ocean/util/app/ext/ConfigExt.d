/*******************************************************************************

    Application extension to parse configuration files.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.ext.ConfigExt;



import ocean.util.app.model.ExtensibleClassMixin;
import ocean.util.app.model.IApplicationExtension;
import ocean.util.app.Application;
import ocean.util.app.ext.model.IConfigExtExtension;
import ocean.util.app.ext.model.IArgumentsExtExtension;
import ocean.util.app.ext.ArgumentsExt;

import ocean.util.config.ConfigParser;
import ocean.text.Arguments;
import ocean.io.Stdout : Stderr;

import ocean.transition;
import ocean.core.Verify;
import ocean.text.Util : join, locate, locatePrior, trim;
import ocean.core.ExceptionDefinitions : IOException;



/*******************************************************************************

    Application extension to parse configuration files.

    This extension is an extension itself, providing new hooks via
    IConfigExtExtension.

    It is also an extension for the ArgumentsExt extension, so if it is
    registered as such, it will add the --config command line option to specify
    the configuration file to read. If loose_config_parsing is false, it will
    also add a --loose-config-parsing option to enable that feature.

*******************************************************************************/

class ConfigExt : IApplicationExtension, IArgumentsExtExtension
{
    import ConfigOverrides = ocean.application.components.ConfigOverrides;

    /***************************************************************************

        Adds a list of extensions (this.extensions) and methods to handle them.
        See ExtensibleClassMixin documentation for details.

    ***************************************************************************/

    mixin ExtensibleClassMixin!(IConfigExtExtension);


    /***************************************************************************

        Configuration parser to use.

    ***************************************************************************/

    public ConfigParser config;


    /***************************************************************************

        If true, configuration files will be parsed in a more relaxed way.

        This might be overridden by command line arguments.

    ***************************************************************************/

    public bool loose_config_parsing;


    /***************************************************************************

        Default configuration files to parse.

    ***************************************************************************/

    public istring[] default_configs;


    /***************************************************************************

        Constructor.

        Params:
            loose_config_parsing = if true, configuration files will be parsed
                                   in a more relaxed way
            default_configs = default configuration files to parse
            config = configuration parser to use, instantiate one if null
                     is passed

    ***************************************************************************/

    this ( bool loose_config_parsing = false,
           istring[] default_configs = [ "etc/config.ini" ],
           ConfigParser config = null )
    {
        this.loose_config_parsing = loose_config_parsing;
        this.default_configs = default_configs;
        if ( config is null )
        {
            config = new ConfigParser;
        }
        this.config = config;
    }


    /***************************************************************************

        Extension order. This extension uses -10_000 because it should be
        called pretty early, but after the ArgumentsExt extension.

        Returns:
            the extension order

    ***************************************************************************/

    public override int order ( )
    {
        return -10_000;
    }


    /***************************************************************************

        Setup command line arguments.

        Adds the following additional command line arguments:
            --config/-c
            --loose-config-parsing (if needed)
            --override-config/-O

        Params:
            app = the application instance
            args = parsed command line arguments

    ***************************************************************************/

    public override void setupArgs ( IApplication app, Arguments args )
    {
        args("config").aliased('c').params(1).smush()
            .help("use the given configuration file");

        foreach (conf; this.default_configs)
        {
            args("config").defaults(conf);
        }

        if (!this.loose_config_parsing)
        {
            args("loose-config-parsing").params(0)
                .help("ignore unknown configuration parameters in config file");
        }

        ConfigOverrides.setupArgs(args);
    }


    /***************************************************************************

        Process command line arguments (ArgumentsExt hook).

        Overrides the loose_config_parsing variable if appropriate.

        Params:
            app = the application instance
            args = parsed command line arguments

    ***************************************************************************/

    public override void processArgs ( IApplication app, Arguments args )
    {
        if (!this.loose_config_parsing)
        {
            this.loose_config_parsing = args("loose-config-parsing").set;
        }
    }


    /***************************************************************************

        Do a simple validation over override-config arguments

        Params:
            app = the application instance
            args = parsed command line arguments

        Returns:
            error text if any

    ***************************************************************************/

    public override cstring validateArgs ( IApplication app, Arguments args )
    {
        return ConfigOverrides.validateArgs(args);
    }


    /***************************************************************************

        Parse configuration files (Application hook).

        This function do all the extension processing invoking all the
        extensions hooks.

        If configuration file parsing fails, it exits with status code 3 and
        prints an appropriate error message.

        Note:
            This is not done in processArgs() method because it can be used
            without being registered as a ArgumentsExt extension.

        Params:
            app = the application instance
            cl_args = command line arguments

    ***************************************************************************/

    public override void preRun ( IApplication app, istring[] cl_args )
    {
        foreach (ext; this.extensions)
        {
            ext.preParseConfig(app, this.config);
        }

        auto args_ext = (cast(Application)app).getExtension!(ArgumentsExt);
        // If an ArgumentExt is present, `.assigned` returns the user's
        // input or the default
        auto config_files = (args_ext !is null)
            ? args_ext.args("config").assigned.dup : this.default_configs;

        foreach (e; this.extensions)
        {
            config_files = e.filterConfigFiles(app, this.config, config_files);
        }

        foreach (config_file; config_files)
        {
            try
            {
                this.config.parseFile(config_file, false);
            }
            catch (IOException e)
            {
                app.exit(3, "Error reading config file '" ~ config_file ~
                        "': " ~ idup(e.message()));
            }
        }

        if (args_ext !is null)
        {
            ConfigOverrides.handleArgs(args_ext.args, this.config);
        }

        foreach (ext; this.extensions)
        {
            ext.processConfig(app, this.config);
        }
    }


    /***************************************************************************

        Unused IApplicationExtension method.

        We just need to provide an "empty" implementation to satisfy the
        interface.

    ***************************************************************************/

    public override void postRun ( IApplication app, istring[] args, int status )
    {
        // Unused
    }

    /// ditto
    public override void atExit ( IApplication app, istring[] args, int status,
                         ExitException exception )
    {
        // Unused
    }

    /// ditto
    public override ExitException onExitException ( IApplication app,
                                           istring[] args,
                                           ExitException exception )
    {
        // Unused
        return exception;
    }


    /***************************************************************************

        Unused IArgumentsExtExtension method.

        We just need to provide an "empty" implementation to satisfy the
        interface.

    ***************************************************************************/

    public override void preValidateArgs ( IApplication app, Arguments args )
    {
        // Unused
    }
}
