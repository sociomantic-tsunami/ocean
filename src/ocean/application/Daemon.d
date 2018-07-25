/*******************************************************************************

    Daemon application base class, with the following built-in features:
        * Command line arguments parsing, including the following built-in args:
            * --help
            * --version
            * --build-info
            * --confg: specifies the config files to read
            * --override-config: allows config values to be overriden from the
              command line
        * Config file reader, including automatic configuration of the
          following components:
            * The logging system
            * Stats logging
            * The task scheduler
        * Periodic stats logging, including automatic logging of process stats.
        * Version logging, at startup.
        * App-level timers
        * Epoll-based signal handling, and signal masking.
        * A registry of open files that can be reopened on command (see below).
          All log files (including the stats log) are automatically added to
          this registry.
        * A unix socket command interface, including support for the following
          built-in commands:
            * show_version
            * show_build_info
            * reopen_files: reopens the specified files (must be registered with
              the open files registry; see above)
            * reload_config: re-parses the config files and reconfigures any
              internal components that can be (this currently includes only the
              logging system).
        * Creation of a PID lock file, to prevent multiple instances of the
          application from starting in the same directory.
        * Epoll and task scheduler setup.
        * A main Task instance that the application's main logic is run in.

    Usage example:
        See Daemon class' documented unittest

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.application.Daemon;

import ocean.transition;

/// ditto
public abstract class Daemon
{
    import ocean.core.Enforce;
    import ocean.core.ExceptionDefinitions : IOException;
    import ocean.core.Verify;
    import ocean.io.device.File;
    import ocean.io.Stdout;
    import ocean.task.Scheduler;
    import ocean.task.Task;
    import ocean.text.Arguments;
    import ocean.util.app.ExitException;
    import ocean.util.config.ConfigParser;
    import ConfigFiller = ocean.util.config.ConfigFiller;
    import ocean.util.log.Appender;
    import ocean.util.log.AppendFile;
    import LogConfig = ocean.util.log.Config;
    import ocean.util.log.LayoutDate;
    import ocean.util.log.Logger;
    import ocean.util.log.Stats;
    import ocean.sys.Stats;

    import ConfigOverrides = ocean.application.components.ConfigOverrides;
    import ocean.application.components.OpenFiles;
    import ocean.application.components.PidLock;
    import ocean.application.components.Signals;
    import TaskScheduler = ocean.application.components.TaskScheduler;
    import ocean.application.components.Timers;
    import ocean.application.components.UnixSocketCommands;
    import Version = ocean.application.components.Version;

    /// Settings passed to the constructor.
    public struct Settings
    {
        /// Application name. Mandatory.
        istring name;

        /// Application description string.
        istring desc;

        /// Long description of what the program does and how to use it.
        istring help;

        /// Application version info. Mandatory.
        Version.VersionInfo ver;

        /// Configuration files to parse.
        istring[] config_files = [ "etc/config.ini" ];

        /// If true, errors when parsing configuration files are treated as
        /// fatal -- the app will not start.
        bool config_errors_fatal = true;

        /// Set of signals to handle.
        int[] signals;

        /// Set of signals to ignore. Delivery of the signals specified in this
        /// set will have no effect on the application -- they are not passed to
        /// the default signal handler.
        int[] ignore_signals;

        /// Default scheduler configuration to be used if no scheduler settings
        /// are specified in the config file.
        Scheduler.Configuration scheduler_config;
    }

    /// Settings passed to the constructor.
    protected Settings settings;

    /// Command line args.
    protected Arguments args;

    /// Configuration parser to use to parse the configuration files.
    protected ConfigParser config;

    /// Stats logger.
    protected StatsLog stats_log;

    /// Stats logging config. (Also required for timer setup.)
    private StatsLog.Config stats_log_config;

    /// Set of files opened by the application that should be reopened on signal.
    protected OpenFiles files;

    /// Unix socket helper.
    protected UnixSocketCommands unix_socket;

    /// Application-level timers.
    protected Timers timers;

    /// PID lock helper.
    private PidLock pid;

    /// Signal handlers.
    private Signals signals;

    /// Process stats tracker.
    private CpuMemoryStats process_stats;

    // TODO: global process monitor (see ocean.io.select.client.EpollProcess)

    /// Arrays of delegates that are called at certain points in the app
    /// start-up procedure.
    private struct Hooks
    {
        /// Hooks called just before args handling has occurred.
        void delegate ( )[] pre_handle_args;

        /// Hooks called during validation of args. If a validation error
        /// occurs, a description of the error should be returned.
        cstring delegate ( )[] validate_args;

        /// Hooks called to process the parsed config files.
        void delegate ( )[] process_config;
    }

    /// ditto
    protected Hooks hooks;

    /***************************************************************************

        Constructor.

        Params:
            settings = application settings struct

    ***************************************************************************/

    public this ( Settings settings )
    {
        enforce(settings.name.length);
        enforce(settings.ver.length);

        this.settings = settings;

        this.files = new OpenFiles;
        this.unix_socket = new UnixSocketCommands;
        with(settings) this.args = new Arguments(name, desc, null, help);
        this.process_stats = new CpuMemoryStats;
        this.signals = new Signals(&this.onSignal);
        ConfigFiller.enable_loose_parsing(!this.settings.config_errors_fatal);
        this.config = new ConfigParser;
    }

    /***************************************************************************

        Begins the startup process and (if successful) calls
        mainAppLogic() in the main Task.

        Params:
            cl_args = command line args passed to `main`

        Returns:
            integer success code to operating system

    ***************************************************************************/

    public int run ( istring[] cl_args )
    {
        // Default setup of components.
        this.setupSignals();
        scope ( exit ) this.signals.clear();
        this.setupArgs();
        this.setupUnixSocketCommands();

        // Call pre-args-handling hooks.
        foreach ( hook; this.hooks.pre_handle_args )
            hook();

        // Handle command line args and parse config files.
        this.handleArgs(cl_args);
        this.parseConfig();
        this.oneTimeConfiguration();

        // Initialise scheduler, epoll, and epoll clients.
        initScheduler(this.settings.scheduler_config);
        this.timers = new Timers; // Needs epoll, so must be constructed here.
        this.startTimers();
        this.startSignalHandling();
        this.unix_socket.startEventHandling(theScheduler.epoll);
        scope ( exit ) this.unix_socket.shutdown();

        // Lock the PID file, log the version, and start the main app task.
        this.pid.lock();
        scope ( exit ) this.pid.unlock();
        this.logVersion();
        return TaskScheduler.runInTask(&this.mainAppLogic);
    }

    /***************************************************************************

        The derived class should implement its main logic here, including config
        parsing.

        Returns:
            integer success code to operating system

    ***************************************************************************/

    protected abstract int mainAppLogic ( );

    /***************************************************************************

        Called periodically. The derived class should implement its stats
        logging here.

    ***************************************************************************/

    protected abstract void onStatsTimer ( );

    /***************************************************************************

        The derived class should implement its signal handling logic here.

        Note that the signals will be handled with a delay of up to a single
        epoll cycle. This is because the signal handler is synced with the
        EpollSelectDispatcher instance. This makes it unsuitable to handle
        critical signals (like `SIGABRT` or `SIGSEGV`) where the application
        generally shouldn't be allowed to proceed. For these cases, setup an
        asynchronous signal handler using `sigaction` instead.

        Params:
            signals = list of signals that fired since the last event loop cycle

    ***************************************************************************/

    protected abstract void onSignal ( int[] signals );

    /***************************************************************************

        Sets up the signals to handle / ignore, as specified in the `Settings`
        instance passed to the ctor.

    ***************************************************************************/

    private void setupSignals ( )
    {
        this.signals.handle(this.settings.signals);
        this.signals.ignore(this.settings.ignore_signals);
    }

    /***************************************************************************

        Sets up the default CLI args for daemon apps. The derived class may
        specify its own additional arguments handling (or modify the defaults)
        by adding a hook to `this.hooks.pre_handle_args` and/or
        `this.hooks.validate_args`.

    ***************************************************************************/

    private void setupArgs ( )
    {
        this.args("help").aliased('h').params(0)
            .help("Display this help message and exit");
        this.args("version").params(0)
            .help("Show version information and exit");
        this.args("build-info").params(0)
            .help("Show detailed build information and exit");
        this.args("config").aliased('c').params(1).smush()
            .help("Use the given configuration file");
        foreach ( conf; this.settings.config_files )
            this.args("config").defaults(conf);
        ConfigOverrides.setupArgs(this.args);
    }

    /***************************************************************************

        Sets up the default unix socket commands for daemon apps. The derived
        class may add its own additional commands by directly accessing
        `this.unix_socket_commands`.

    ***************************************************************************/

    private void setupUnixSocketCommands ( )
    {
        this.unix_socket.commands.addHandler("show_version",
            &this.showVersionCommand);
        this.unix_socket.commands.addHandler("show_build_info",
            &this.showBuildInfoCommand);
        this.unix_socket.commands.addHandler("reopen_files",
            &this.reopenFilesCommand);
        this.unix_socket.commands.addHandler("reload_config",
            &this.reloadConfigCommand);
    }

    /***************************************************************************

        Parses, validates, and handles CLI args.

        Params:
            args = command line args passed to `main`

    ***************************************************************************/

    private void handleArgs ( istring[] cl_args )
    {
        verify(this.args !is null);

        // Parse passed arguments.
        cstring[] errors;
        auto args_ok = this.args.parse(cl_args[1 .. $]);

        // Handle special args that ignore parsing errors and that cause the app
        // to exit, if present (e.g. `--help`).
        if ( !this.handleExitArgs() )
            this.exit(0);

        // Validate built-in args and call user hooks for further args
        // validation.
        if ( auto errs = ConfigOverrides.validateArgs(args) )
            errors ~= errs;

        foreach ( hook; this.hooks.validate_args )
                errors ~= hook();

        // Exit if any errors occured.
        if ( !args_ok )
        {
            Stderr.red();
            this.args.displayErrors();
            foreach ( error; errors )
                Stderr.format("{}", error).newline();
            Stderr.default_colour();
            Stderr.formatln("\nType {} -h for help", this.settings.name);
            this.exit(2);
        }
    }

    /***************************************************************************

        Handles special args that ignore parsing errors and that cause the app
        to exit, if present (e.g. `--help`).

        Returns:
            false to exit; true to continue

    ***************************************************************************/

    private bool handleExitArgs ( )
    {
        if ( args.exists("help") )
        {
            args.displayHelp();
            return false;
        }

        version ( UnitTest ) { } // suppress console output in unittests
        else
        {
            if ( args.exists("version") )
            {
                Stdout.formatln("{}", Version.getVersionString(
                    this.settings.name, this.settings.ver));
                return false;
            }

            if ( args.exists("build-info") )
            {
                Stdout.formatln("{}", Version.getBuildInfoString(
                    this.settings.name, this.settings.ver));
                return false;
            }
        }

        return true;
    }

    /***************************************************************************

        Parses all config files specified in `this.settings` / on the command
        line. Handles any config value overrides specified by the command line
        args. Configures internal components that may be reconfigured (i.e. as
        opposed to the components handled in oneTimeConfiguration, that must
        only be configured once). Calls user-defined config processing hooks.

    ***************************************************************************/

    private void parseConfig ( )
    {
        // Parse all arg-specified config files.
        foreach ( config_file; this.args("config").assigned )
        {
            try
            {
                this.config.parseFile(config_file, false);
            }
            catch ( IOException e )
            {
                this.exit(3,
                    "Error reading config file '" ~ config_file ~ "': "
                    ~ idup(e.message()));
            }
        }

        // Apply any arg-specified config value overrides.
        ConfigOverrides.handleArgs(this.args, this.config);

        // Configure internal components that may be reconfigured.
        this.configureLoggers();

        // Call config processing hooks.
        foreach ( hook; this.hooks.process_config )
            hook();
    }

    /***************************************************************************

        Configure internal components that must be set up once only.

    ***************************************************************************/

    private void oneTimeConfiguration ( )
    {
        TaskScheduler.parseSchedulerConfig(this.config,
            this.settings.scheduler_config);
        this.unix_socket.parseConfig(this.config);
        this.pid.parseConfig(this.config);
        this.configureStatsLogger();
    }

    /***************************************************************************

        Sets up logging from the parsed config files.

    ***************************************************************************/

    private void configureLoggers ( )
    {
        auto log_config =
            ConfigFiller.iterate!(LogConfig.Config)("LOG", this.config);
        auto log_meta_config =
            ConfigFiller.fill!(LogConfig.MetaConfig)("LOG", this.config);

        LogConfig.configureNewLoggers(log_config, log_meta_config,
            &this.newLogAppender);
    }

    /***************************************************************************

        Sets up stats logging from the parsed config files.

    ***************************************************************************/

    private void configureStatsLogger ( )
    {
        this.stats_log_config =
            ConfigFiller.fill!(StatsLog.Config)("STATS", this.config);

        this.stats_log = new StatsLog(this.stats_log_config,
            &this.newLogAppender, this.stats_log_config.file_name);
    }

    /***************************************************************************

        Writes the application version to the version log file.

    ***************************************************************************/

    private void logVersion ( )
    {
        auto ver_log = Log.lookup("ocean.application.Daemon");
        ver_log.add(this.newLogAppender("log/version.log", new LayoutDate));

        ver_log.info(Version.getVersionString(this.settings.name,
            this.settings.ver));
    }

    /***************************************************************************

        Creates a new AppendStream instance attached to a File, and adds it to
        the registry of open files.

        Params:
            file = path of log file
            layout = logger layout to use when writing to the file

        Returns:
            new appender

    ***************************************************************************/

    private Appender newLogAppender ( istring file, Appender.Layout layout )
    {
        auto stream = new File(file, File.WriteAppending);
        this.files.register(stream);
        return new AppendStream(stream, true, layout);
    }

    /***************************************************************************

        Sets up timers required by the internal components.

    ***************************************************************************/

    private void startTimers ( )
    {
        this.timers.register(&this.statsTimer, this.stats_log_config.interval);
    }

    /***************************************************************************

        Starts handling incoming signals by registering the signal handler with
        epoll.

    ***************************************************************************/

    private void startSignalHandling ( )
    {
        theScheduler.epoll.register(this.signals.selectClient());
    }

    /***************************************************************************

        Stats timer callback. Logs the process stats, then calls `onStatsTimer`.

        Returns:
            always true, to keep the timer registered

    ***************************************************************************/

    private bool statsTimer ( )
    {
        this.stats_log.add(this.process_stats.collect());
        this.onStatsTimer();
        return true;
    }

    /***************************************************************************

        Exit cleanly from the application.

        Calling exit() will properly unwind the stack and all the destructors
        will be called. Should be used only from the main application thread
        though.

        Params:
            status = status code to return to the OS
            msg = optional message to show just before exiting

    ***************************************************************************/

    protected void exit ( int status, istring msg = null )
    {
        throw new ExitException(status, msg);
    }

    /***************************************************************************

        Print the version to the provided sink delegate. Used as a callback from
        the Unix socket.

        Params:
            args = list of arguments received from the socket - ignored
            send_response = delegate to send a response to the client

    ***************************************************************************/

    private void showVersionCommand ( cstring[] args,
            void delegate ( cstring response ) send_response )
    {
        send_response(
            Version.getVersionString(this.settings.name, this.settings.ver));
        send_response("\n");
    }

    /***************************************************************************

        Print the build info to the provided sink delegate. Used as a callback
        from the Unix socket.

        Params:
            args = list of arguments received from the socket - ignored
            send_response = delegate to send a response to the client

    ***************************************************************************/

    private void showBuildInfoCommand ( cstring[] args,
        void delegate ( cstring response ) send_response )
    {
        send_response(
            Version.getBuildInfoString(this.settings.name, this.settings.ver));
        send_response("\n");
    }

    /***************************************************************************

        Reopen command to trigger from the Unix Domain socket. It reads
        the names of the files to reload and reloads the appropriate files.

        Params:
            args = list of arguments received from the socket - should contain
                the names of the files to rotate.
            send_response = delegate to send the response to the client

    ***************************************************************************/

    private void reopenFilesCommand ( cstring[] args,
        void delegate ( cstring response ) send_response )
    {
        if (args.length == 0)
        {
            send_response("ERROR: missing name of the file to rotate.\n");
            return;
        }

        foreach (filename; args)
        {
            if (!this.files.reopenFile(filename))
            {
                send_response("ERROR: Could not rotate the file '");
                send_response(filename);
                send_response("'\n");
                return;
            }
        }

        send_response("ACK\n");
    }

    /***************************************************************************

        Unix socket command that reloads all config files and calls all config
        processing hooks.

        Params:
            args = list of arguments received from the socket - should contain
                the names of the files to rotate.
            send_response = delegate to send the response to the client

    ***************************************************************************/

    private void reloadConfigCommand ( cstring[] args,
        void delegate ( cstring response ) send_response )
    {
        this.parseConfig();
        send_response("ACK\n");
    }
}

///
unittest
{
    /***************************************************************************

        Example daemon application class.

    ***************************************************************************/

    class MyApp : Daemon
    {
        import ocean.application.components.Version;
        import core.sys.posix.signal: SIGINT, SIGTERM;

        this ( )
        {
            Daemon.Settings settings;

            // The name of your app and a short description of what it does.
            settings.name = "my_app";
            settings.desc = "Dummy app for unittest.";

            // The version info for your app. Normally you get this by importing
            // Version.
            settings.ver = VersionInfo.init;

            // Specify othern optional settings. In this example, we specify the
            // help text and some signals that we want to handle.
            settings.help = "Actually, this program does nothing. Sorry!";
            settings.signals = [SIGINT, SIGTERM];

            // Call the super class' ctor.
            super(settings);

            // If you need to handle any additional CLI args, add a hook:
            this.hooks.pre_handle_args ~= &this.setupArgs;

            // If you need to do any special CLI arg validation, add a hook:
            this.hooks.validate_args ~= &this.validateArgs;
        }

        // Args setup hook, called just before the CLI args are parsed.
        private void setupArgs ( )
        {
            // Add an extra arg to handle.
            this.args("something").help("Do something");

            // Set the standard config arg to be mandatory.
            this.args("config").required;
        }

        // Args validation hook, called just after the CLI args are parsed.
        private cstring validateArgs ( )
        {
            if ( this.args.exists("something") )
                return "That's actually not allowed";

            return null;
        }

        // Implement your main application logic here. This method is called
        // inside a Task. The event loop is already running.
        protected override int mainAppLogic ( )
        {
            // Application main logic.

            return 0; // return code to OS
        }

        // Handle those signals we were interested in.
        protected override void onSignal ( int[] signals )
        {
            foreach ( signal; signals )
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
        }

        // Handle stats output.
        protected override void onStatsTimer ( )
        {
            struct Treasure
            {
                int copper, silver, gold;
            }
            Treasure loot;
            this.stats_log.add(loot);
            this.stats_log.flush();
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
        auto ret = my_app.run(cl_args);

        // Return ret to the OS.
        return ret;
    }
}
