/*******************************************************************************

    Application extension to log or output the version information.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.ext.VersionArgsExt;



/*******************************************************************************

    Imports

*******************************************************************************/

public import ocean.util.app.ext.VersionInfo;

import ocean.util.app.model.IApplicationExtension;
import ocean.util.app.ext.model.IArgumentsExtExtension;
import ocean.util.app.ext.model.ILogExtExtension;
import ocean.util.app.ext.LogExt;
import ocean.util.app.ext.ConfigExt;
import ocean.util.app.Application;

import ocean.text.Arguments;
import ocean.util.config.ConfigParser;
import ocean.io.Stdout;
import ocean.core.Array: startsWith;

import ocean.transition;
import ocean.util.log.Log;
import ocean.util.log.AppendFile;
import ocean.util.log.LayoutDate;
import ocean.core.Array: sort;



/*******************************************************************************

    Application extension to log or output the version information.

    This extension is an ArgumentsExt and a LogExt extension, being optional for
    both (but makes no sense unless it's registered at least as one of them).

    If it's registered as an ArgumentsExt, it adds the option --version to print
    the version information and exit. (Note that the actual handling of the
    --version command line option is performed by ArgumentsExt.)

    If it's registered as a LogExt, it will log the version information using
    the logger with the name of this module.

*******************************************************************************/

class VersionArgsExt : IApplicationExtension, IArgumentsExtExtension,
        ILogExtExtension
{

    /***************************************************************************

        Version information.

    ***************************************************************************/

    public VersionInfo ver;


    /***************************************************************************

        True if a default logger for the version should be added.

    ***************************************************************************/

    public bool default_logging;


    /***************************************************************************

        Default name of the file to log when using the default logger.

    ***************************************************************************/

    public istring default_file;


    /***************************************************************************

        Logger to use to log the version information.

    ***************************************************************************/

    public Logger ver_log;


    /***************************************************************************

        Constructor.

        Params:
            ver = version information.
            default_logging = true if a default logger for the version should be
                              added
            default_file = default name of the file to log when using the
                           default logger

    ***************************************************************************/

    this ( VersionInfo ver, bool default_logging = true,
            istring default_file = "log/version.log" )
    {
        this.ver = ver;
        this.default_logging = default_logging;
        this.default_file = default_file;
        this.ver_log = Log.lookup("ocean.util.app.ext.VersionArgsExt");
    }


    /***************************************************************************

        Get a single version string with all the libraries versions.

        Only keys starting with "lib_" are considered libraries.

        Params:
            ver = associative array with the version name as the key and the
                  revision as the value

        Returns:
            string with the version information of all libraries

    ***************************************************************************/

    protected istring getLibsVersionsString ( istring[istring] ver )
    {
        const prefix = "lib_";
        istring s;
        auto sorted_names = ver.keys;
        sorted_names.sort();
        foreach (name; sorted_names)
        {
            if (name.startsWith(prefix))
                s ~= " " ~ name[prefix.length .. $] ~ ":" ~ ver[name];
        }
        return s;
    }


    /***************************************************************************

        Get the program's name and full version information as a string.

        Params:
            app_name = program's name
            ver = description of the application's version / revision

        Returns:
            String with the version information

    ***************************************************************************/

    protected istring getVersionString ( istring app_name, VersionInfo ver )
    {
        istring get(istring key)
        {
            auto v = key in ver;
            return v is null ? "<unknown>" : *v;
        }
        return app_name ~ " version " ~ get("version") ~ " (compiled by '" ~
                get("build_author") ~ "' on " ~ get("build_date") ~ " with " ~
                get("compiler") ~ " using" ~
                this.getLibsVersionsString(ver) ~ ")";
    }


    /***************************************************************************

        Extension order. This extension uses 100_000 because it should be
        called very late.

        Returns:
            the extension order

    ***************************************************************************/

    public override int order ( )
    {
        return 100_000;
    }


    /***************************************************************************

        Adds the command line option --version.

        Params:
            app = the application instance
            args = command-line arguments instance

    ***************************************************************************/

    public override void setupArgs ( IApplication app, Arguments args )
    {
        args("version").params(0).help("show version information and exit");
    }


    /***************************************************************************

        Checks whether the --version flag is present and, if it is, prints the
        app version and exits without further arguments validation.

        Params:
            app = application instance
            args = command line arguments instance

    ***************************************************************************/

    public override void preValidateArgs ( IApplication app, Arguments args )
    {
        if ( args.exists("version") )
            this.displayVersion(app);
    }


    /***************************************************************************

        Print the version information to Stdout and exit.

        Params:
            app = the application instance

    ***************************************************************************/

    public void displayVersion ( IApplication app )
    {
        version ( UnitTest ) { } // suppress console output in unittests
        else
        {
            Stdout(getVersionString(app.name, this.ver)).newline;
        }
        app.exit(0);
    }


    /***************************************************************************

        Add the default logger if default_logging is true.

        If the configuration variable is present, it will override the current
        default_logging value. If the value does not exist in the config file,
        the value set in the ctor will be used.

        Note that the logger is explicitly set to output all levels, to avoid
        the situation where the root logger is configured to not output level
        'info'.

        Params:
            app = the application instance
            config = the configuration instance
            loose_config_parsing = if true, configuration files will be parsed
                                   in a more relaxed way
            use_insert_appender = true if the InsertConsole appender should be
                                  used (needed when using the AppStatus module)

    ***************************************************************************/

    public override void postConfigureLoggers ( IApplication app, ConfigParser config,
            bool loose_config_parsing, bool use_insert_appender )
    {
        this.ver_log.level = this.ver_log.Level.Info;

        this.default_logging = config.get("VERSION", "default_version_log",
                this.default_logging);

        if (this.default_logging)
        {
            this.ver_log.add(new AppendFile(this.default_file, new LayoutDate));
        }
    }


    /***************************************************************************

        Print the version information to the log if the ConfigExt and LogExt are
        present.

        Params:
            app = the application instance
            args = command-line arguments

    ***************************************************************************/

    public override void preRun ( IApplication app, istring[] args )
    {
        auto conf_ext = (cast(Application)app).getExtension!(ConfigExt)();
        if (conf_ext is null)
        {
            return;
        }

        auto log_ext = conf_ext.getExtension!(LogExt)();
        if (log_ext is null)
        {
            return;
        }

        this.ver_log.info(getVersionString(app.name, this.ver));
    }


    /***************************************************************************

        Unused IApplicationExtension methods.

        We just need to provide an "empty" implementation to satisfy the
        interface.

    ***************************************************************************/

    public override void postRun ( IApplication app, istring[] args, int status )
    {
        // Unused
    }

    public override void atExit ( IApplication app, istring[] args, int status,
                         ExitException exception )
    {
        // Unused
    }

    public override ExitException onExitException ( IApplication app,
                                           istring[] args,
                                           ExitException exception )
    {
        // Unused
        return exception;
    }


    /***************************************************************************

        Unused IArgumentsExtension methods.

        We just need to provide an "empty" implementation to satisfy the
        interface.

        Params:
            app = the application instance
            args = command-line arguments instance

    ***************************************************************************/

    public override cstring validateArgs ( IApplication app, Arguments args )
    {
        // Unused
        return null;
    }

    public override void processArgs ( IApplication app, Arguments args )
    {
        // Unused
    }


    /***************************************************************************

        Unused ILogExtExtension methods.

        We just need to provide an "empty" implementation to satisfy the
        interface.

        Params:
            app = the application instance
            config = the configuration instance
            loose_config_parsing = if true, configuration files will be parsed
                                   in a more relaxed way
            use_insert_appender = true if the InsertConsole appender should be
                                  used (needed when using the AppStatus module)

    ***************************************************************************/

    public override void preConfigureLoggers ( IApplication app, ConfigParser config,
            bool loose_config_parsing, bool use_insert_appender )
    {
        // Unused
    }

}

version ( UnitTest )
{
    import ocean.core.Test;
    import ocean.util.app.ext.ArgumentsExt;
}

/*******************************************************************************

    Test that --version succeeds when there are unprovided required arguments.

*******************************************************************************/

unittest
{
    class MyApp : Application, IArgumentsExtExtension
    {
        this ( )
        {
            super("test_app", "desc");

            auto args_ext = new ArgumentsExt("test", "just a test");
            args_ext.registerExtension(this);
            this.registerExtension(args_ext);

            auto ver_ext = new VersionArgsExt(VersionInfo.init);
            args_ext.registerExtension(ver_ext);
            this.registerExtension(ver_ext);
        }

        override protected int run ( istring[] ) { return 10; }

        override public void setupArgs ( IApplication, Arguments args )
        {
            args("important").params(1).required;
        }

        override public void preValidateArgs ( IApplication, Arguments ) { }

        override public cstring validateArgs ( IApplication, Arguments )
            { return null; }

        override public void processArgs ( IApplication, Arguments ) { }

        // ArgumentsExt.preRun() calls exit(2) if the args parsing fails,
        // VersionArgsExt.displayVersion() should call exit(0) before that
        // happens.
        override public void exit ( int status, istring msg = null )
        {
            test!("==")(status, 0);

            super.exit(status, msg);
        }
    }

    auto app = new MyApp;
    app.main(["app_name", "--version"]);
}
