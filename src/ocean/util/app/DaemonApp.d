/*******************************************************************************

    Application class that provides the standard features needed by applications
    that run as a daemon:
        * Command line parsing
        * Version support
        * Reading of config file
        * Auto-configuration of loggers
        * Periodic stats logging
        * Re-opening of log files upon receipt of SIGHUP (intended to be used
          in conjunction with logrotate)

    Usage example:
        See DaemonApp class' documented unittest

    A note on epoll:

    The daemon app does not currently interact with epoll in any way (either
    registering clients or starting the event loop). This is a deliberate
    choice, in order to leave the epoll handling up to the user, without
    enforcing any required sequence of events. (This may come in the future.)

    An epoll instance must be passed to the constructor, as this is required by
    the TimerExt and SignalExt. The user must manually call the
    startEventHandling() method, which registers the select clients required by
    the extensions with epoll (see usage example).

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.DaemonApp;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.app.Application : Application;
import ocean.util.app.ext.model.IArgumentsExtExtension;
import ocean.util.app.ext.model.IConfigExtExtension;
import ocean.util.app.ext.model.ILogExtExtension;
import ocean.util.app.ext.model.ISignalExtExtension;

import ocean.transition;

/*******************************************************************************

    DaemonApp class

*******************************************************************************/

public abstract class DaemonApp : Application,
        IArgumentsExtExtension, IConfigExtExtension, ILogExtExtension,
        ISignalExtExtension
{
    import ocean.util.config.ConfigParser : ConfigParser;
    import ocean.util.log.Stats;
    import ocean.io.select.EpollSelectDispatcher;
    import ocean.text.Arguments : Arguments;

    import ocean.util.app.ext.ArgumentsExt;
    import ocean.util.app.ext.ConfigExt;
    import ocean.util.app.ext.VersionArgsExt;
    import ocean.util.app.ext.LogExt;
    import ocean.util.app.ext.StatsExt;
    import ocean.util.app.ext.TimerExt;
    import ocean.util.app.ext.SignalExt;
    import ocean.util.app.ext.ReopenableFilesExt;
    import ocean.util.app.ext.PidLockExt;
    import ocean.util.app.ExitException;

    import ocean.util.log.Log;

    /***************************************************************************

        Command line arguments used by the application.

    ***************************************************************************/

    public Arguments args;

    /***************************************************************************

        Command line arguments extension used by the application.

    ***************************************************************************/

    public ArgumentsExt args_ext;

    /***************************************************************************

        Configuration parser to use to parse the configuration files.

    ***************************************************************************/

    public ConfigParser config;

    /***************************************************************************

        Configuration parsing extension instance.

    ***************************************************************************/

    public ConfigExt config_ext;

    /***************************************************************************

        Logging extension instance.

    ***************************************************************************/

    public LogExt log_ext;

    /***************************************************************************

        Version information.

    ***************************************************************************/

    public VersionInfo ver;

    /***************************************************************************

        Version information extension.

    ***************************************************************************/

    public VersionArgsExt ver_ext;

    /***************************************************************************

        Stats log extension -- TODO auto configured or what? Why public?
        getter for StatsLog instance?

    ***************************************************************************/

    public StatsExt stats_ext;

    /***************************************************************************

        Timer handler extension.

    ***************************************************************************/

    public TimerExt timer_ext;

    /***************************************************************************

        Signal handler extension. Directs registered signals to the onSignal()
        method.

    ***************************************************************************/

    public SignalExt signal_ext;

    /***************************************************************************

        Reopenable files extension. Hooks into the stats, log, and signal
        extentions, and automatically reopens logfiles upon receipt of the
        SIGHUP signal (presumably sent from logrotate).

    ***************************************************************************/

    public ReopenableFilesExt reopenable_files_ext;

    /***************************************************************************

        PidLock extension. Tries to create and lock the pid lock file (if
        specified in the config), ensuring that only one application instance
        per pidlock may exist.

    ***************************************************************************/

    public PidLockExt pidlock_ext;

    /***************************************************************************

        Epoll instance passed to ctor.

    ***************************************************************************/

    private EpollSelectDispatcher epoll;

    /***************************************************************************

        Struct containing optional constructor arguments. There are enough of
        these that handling them as default arguments to the ctor is cumbersome.

    ***************************************************************************/

    public static struct OptionalSettings
    {
        import ocean.stdc.posix.signal : SIGHUP;

        /***********************************************************************

            How the program is supposed to be invoked.

        ***********************************************************************/

        istring usage = null;

        /***********************************************************************

            Long description of what the program does and how to use it.

        ***********************************************************************/

        istring help = null;

        /***********************************************************************

            Default configuration files to parse.

        ***********************************************************************/

        istring[] default_configs = [ "etc/config.ini" ];

        /***********************************************************************

            If true, configuration files will be parsed in a more relaxed way.

        ***********************************************************************/

        bool loose_config_parsing = false;

        /***********************************************************************

            Configuration parser to use (if null, a new instance is created).

        ***********************************************************************/

        ConfigParser config = null;

        /***********************************************************************

            If true, any loggers which are configured to output to the console
            (see ocean.util.log.Config) will use the InsertConsole appender,
            rather than the AppendConsole appender. This is required by apps
            which use ocean.io.console.AppStatus.

        ***********************************************************************/

        bool use_insert_appender = false;

        /***********************************************************************

            Set of signals to handle.

        ***********************************************************************/

        int[] signals = [];

        /***********************************************************************

            Signal to trigger reopening of files which are registered with the
            ReopenableFilesExt. (Typically used for log rotation.)

        ***********************************************************************/

        int reopen_signal = SIGHUP;
    }

    /***************************************************************************

        This constructor only sets up the internal state of the class, but does
        not call any extension or user code.

        Params:
            epoll = epoll instance, required by timer and signal extensions
            name = Name of the application (to show in the help message)
            desc = Short description of what the program does (should be
                         one line only, preferably less than 80 characters)
            ver = application's version information
            settings = optional settings (see OptionalSettings, above)

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll, istring name, istring desc,
        VersionInfo ver, OptionalSettings settings = OptionalSettings.init )
    {
        super(name, desc);

        this.epoll = epoll;

        // Create and register arguments extension
        this.args_ext = new ArgumentsExt(name, desc, settings.usage,
            settings.help);
        this.args = this.args_ext.args;
        this.args_ext.registerExtension(this);
        this.registerExtension(this.args_ext);

        // Create and register config extension
        if ( settings.config is null )
            settings.config = new ConfigParser;
        this.config_ext = new ConfigExt(settings.loose_config_parsing,
            settings.default_configs, settings.config);
        this.config = this.config_ext.config;
        this.config_ext.registerExtension(this);
        this.registerExtension(this.config_ext);
        this.args_ext.registerExtension(this.config_ext);

        // Create and register log extension
        this.log_ext = new LogExt(settings.use_insert_appender);
        this.config_ext.registerExtension(this.log_ext);

        // Create and register version extension
        this.ver_ext = new VersionArgsExt(ver);
        this.ver = this.ver_ext.ver;
        this.args_ext.registerExtension(this.ver_ext);
        this.log_ext.registerExtension(this.ver_ext);
        this.registerExtension(this.ver_ext);

        // Create and register stats extension
        this.stats_ext = new StatsExt;
        this.config_ext.registerExtension(this.stats_ext);

        // Create and register timer extension
        this.timer_ext = new TimerExt(this.epoll);
        this.registerExtension(this.timer_ext);

        // Create and register signal extension
        this.signal_ext = new SignalExt(settings.signals);
        this.signal_ext.registerExtension(this);
        this.registerExtension(this.signal_ext);

        // Create and register repoenable files extension
        this.reopenable_files_ext = new ReopenableFilesExt(this.signal_ext,
            settings.reopen_signal);
        this.registerExtension(this.reopenable_files_ext);

        this.pidlock_ext = new PidLockExt();
        this.config_ext.registerExtension(this.pidlock_ext);
        this.registerExtension(this.pidlock_ext);
    }

    /***************************************************************************

        This method must be called in order for signal and stats event handling
        to start being processed. As it registers clients (the stats timer and
        signal handler) with epoll which will always reregister themselves after
        firing, you should call this method when you are about to start your
        application's main event loop.

    ***************************************************************************/

    public void startEventHandling ( )
    {
        this.timer_ext.register(&this.statsTimer, this.stats_ext.config.interval);
        this.epoll.register(this.signal_ext.selectClient());
    }

    /***************************************************************************

        Run implementation that forwards to the abstract
        run(Arguments, ConfigParser).

        Params:
            args = raw command line arguments

        Returns:
            status code to return to the OS

    ***************************************************************************/

    override protected int run ( istring[] args )
    {
        return this.run(this.args, this.config);
    }

    /***************************************************************************

        This method must be implemented by subclasses to do the actual
        application work.

        Params:
            args = parsed command line arguments
            config = parser instance with the parsed configuration

        Returns:
            status code to return to the OS

    ***************************************************************************/

    abstract protected int run ( Arguments args, ConfigParser config );

    /***************************************************************************

        Exit cleanly from the application, passing the specified return code to
        the OS and optionally printing the specified message to the console.

        Calling exit() will properly unwind the stack and all the destructors
        will be called. The method should be used only from the main application
        thread, though, as it throws an ExitException which may not be handled
        properly in other contexts.

        Params:
            status = status code to return to the OS
            msg = optional message to show just before exiting

    ***************************************************************************/

    override public void exit ( int status, istring msg = null )
    {
        this.exit(status, msg, null);
    }

    /***************************************************************************

        Exit cleanly from the application, passing the specified return code to
        the OS and optionally printing the specified message to the console and
        the specified logger (if one is provided).

        Params:
            status = status code to return to the OS
            msg = optional message to show just before exiting
            logger = logger to use to log the message

    ***************************************************************************/

    public void exit ( int status, istring msg, Logger logger )
    {
        if (logger !is null)
        {
            logger.fatal(msg);
        }
        throw new ExitException(status, msg);
    }

    /***************************************************************************

        Called by the timer extension when the stats period fires. Calls
        onStatsTimer() and returns true to keep the timer registered.

        Returns:
            true to re-register timer

    ***************************************************************************/

    private bool statsTimer ( )
    {
        this.onStatsTimer();
        return true;
    }

    /***************************************************************************

        Called by the timer extension when the stats period fires. By default
        does nothing, but should be overridden to write the required stats.

    ***************************************************************************/

    protected void onStatsTimer ( )
    {
    }

    /***************************************************************************

        ISignalExtExtension methods dummy implementation.

        This method is implemented with an "empty" implementation to ease
        deriving from this class.

        See ISignalExtExtension documentation for more information on how to
        override this method.

    ***************************************************************************/

    override public void onSignal ( int signum )
    {
        // Dummy implementation of the interface
    }

    /***************************************************************************

        IArgumentsExtExtension methods dummy implementation.

        These methods are implemented with an "empty" implementation to ease
        deriving from this class.

        See IArgumentsExtExtension documentation for more information on how to
        override these methods.

    ***************************************************************************/

    override public void setupArgs ( IApplication app, Arguments args )
    {
        // Dummy implementation of the interface
    }

    /// ditto
    override public void preValidateArgs ( IApplication app, Arguments args )
    {
        // Dummy implementation of the interface
    }

    /// ditto
    override public cstring validateArgs ( IApplication app, Arguments args )
    {
        // Dummy implementation of the interface
        return null;
    }

    /// ditto
    override public void processArgs ( IApplication app, Arguments args )
    {
        // Dummy implementation of the interface
    }

    /***************************************************************************

        IConfigExtExtension methods dummy implementation.

        These methods are implemented with an "empty" implementation to ease
        deriving from this class.

        See IConfigExtExtension documentation for more information on how to
        override these methods.

    ***************************************************************************/

    override public void preParseConfig ( IApplication app, ConfigParser config )
    {
        // Dummy implementation of the interface
    }

    /// ditto
    override public istring[] filterConfigFiles ( IApplication app,
                                                  ConfigParser config,
                                                  istring[] files )
    {
        // Dummy implementation of the interface
        if (files.length)
        {
            return files[$-1 .. $];
        }
        return files;
    }

    /// ditto
    override public void processConfig ( IApplication app, ConfigParser config )
    {
        // Dummy implementation of the interface
    }

    /***************************************************************************

        ILogExtExtension methods dummy implementation.

        These methods are implemented with an "empty" implementation to ease
        deriving from this class.

        See IConfigExtExtension documentation for more information on how to
        override these methods.

    ***************************************************************************/

    override public void preConfigureLoggers ( IApplication app,
            ConfigParser config, bool loose_config_parsing,
            bool use_insert_appender )
    {
        // Dummy implementation of the interface
    }

    /// ditto
    override public void postConfigureLoggers ( IApplication app,
            ConfigParser config, bool loose_config_parsing,
            bool use_insert_appender )
    {
        // Dummy implementation of the interface
    }
}

///
unittest
{
    /***************************************************************************

        Example daemon application class.

    ***************************************************************************/

    class MyApp : DaemonApp
    {
        import ocean.stdc.posix.signal: SIGINT, SIGTERM;

        import ocean.io.select.EpollSelectDispatcher;

        private EpollSelectDispatcher epoll;

        this ( )
        {
            // The timer extension requires an epoll instance
            this.epoll = new EpollSelectDispatcher;

            // The name of your app and a short description of what it does.
            istring name = "my_app";
            istring desc = "Dummy app for unittest.";

            // The version info for your app. Normally you get this by importing
            // Version and passing the AA which contains the version info
            // (called versionInfo) to DaemonApp's constructor.
            auto ver = VersionInfo.init;

            // You may also pass an instance of OptionalSettings to DaemonApp's
            // constructor, to specify non-mandatory options. In this example,
            // we specify the help text and some signals that we want to handle.
            DaemonApp.OptionalSettings settings;
            settings.help = "Actually, this program does nothing. Sorry!";
            settings.signals = [SIGINT, SIGTERM];

            // Call the super class' ctor.
            super(this.epoll, name, desc, VersionInfo.init, settings);
        }

        // Called after arguments and config file parsing.
        override protected int run ( Arguments args, ConfigParser config )
        {
            // In order for signal and timer handling to be processed, you must
            // call this method. This registers one or more clients with epoll.
            this.startEventHandling();

            // Application main logic. Usually you would call the epoll event
            // loop here.

            return 0; // return code to OS
        }

        // Handle those signals we were interested in
        override public void onSignal ( int signal )
        {
            switch ( signal )
            {
                case SIGINT:
                case SIGTERM:
                    // Termination logic.
                    break;
                default:
            }
        }

        // Handle stats output.
        override protected void onStatsTimer ( )
        {
            struct Treasure
            {
                int copper, silver, gold;
            }
            Treasure loot;
            this.stats_ext.stats_log.add(loot);
            this.stats_ext.stats_log.flush();
        }
    }

    /***************************************************************************

        Your application's main() function should look something like this.
        (This function is not called here as we don't want to actually run the
        application in this unittest -- it will fail due to the lack of properly
        configured etc/ and log/ directories.)

    ***************************************************************************/

    int main ( istring[] cl_args )
    {
        // Instantiate an instance of your app class.
        auto my_app = new MyApp;

        // Pass the raw command line arguments to its main function.
        auto ret = my_app.main(cl_args);

        // Return ret to the OS.
        return ret;
    }
}
