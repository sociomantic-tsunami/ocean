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

    However, some extensions (namely, the SignalExt and TimerExt) require an
    epoll instance for their internal event handling. For this reason, an epoll
    instance must be passed to the DaemonApp. To do so, pass an epoll instance
    to the startEventHandling method.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.DaemonApp;

import ocean.util.app.Application : Application;
import ocean.util.app.ext.model.IArgumentsExtExtension;
import ocean.util.app.ext.model.IConfigExtExtension;
import ocean.util.app.ext.model.ILogExtExtension;
import ocean.util.app.ext.model.ISignalExtExtension;

import ocean.transition;
version (UnitTest) import ocean.core.Test;
import ocean.core.Verify;
import ocean.task.IScheduler;

import core.stdc.time;

/// ditto
public abstract class DaemonApp : Application,
        IArgumentsExtExtension, IConfigExtExtension, ILogExtExtension,
        ISignalExtExtension
{
    import ocean.application.components.GCStats;

    static import ocean.text.Arguments;
    public alias ocean.text.Arguments.Arguments Arguments;
    static import ocean.util.config.ConfigParser;
    public alias ocean.util.config.ConfigParser.ConfigParser ConfigParser;

    import ocean.util.log.Stats;
    import ocean.io.select.EpollSelectDispatcher;

    import ocean.sys.Stats;
    import ocean.util.app.ext.ArgumentsExt;
    import ocean.util.app.ext.ConfigExt;
    import ocean.util.app.ext.VersionArgsExt;
    protected import ocean.util.app.ext.VersionInfo : VersionInfo;
    import ocean.util.app.ext.LogExt;
    import ocean.util.app.ext.StatsExt;
    import ocean.util.app.ext.TimerExt;
    import ocean.util.app.ext.SignalExt;
    import ocean.util.app.ext.ReopenableFilesExt;
    import ocean.util.app.ext.PidLockExt;
    import ocean.util.app.ext.UnixSocketExt;
    import ocean.util.app.ext.TaskExt;
    import ocean.util.app.ExitException;
    import ocean.util.log.Logger;
    import ocean.util.log.Stats;
    import ocean.util.prometheus.collector.Collector;

    static import core.sys.posix.signal;

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

        Unix socket extension to register commands for the application to
        respond to.

    ***************************************************************************/

    public UnixSocketExt unix_socket_ext;

    /***************************************************************************

        Extension to start `run` method inside a task.

    ***************************************************************************/

    public TaskExt task_ext;

    /***************************************************************************

        Cpu and memory collector instance.

    ***************************************************************************/

    private CpuMemoryStats system_stats;

    /***************************************************************************

        Garbage collector stats

    ***************************************************************************/

    private GCStats gc_stats;

    /***************************************************************************

        Epoll instance used internally.

    ***************************************************************************/

    private EpollSelectDispatcher epoll;

    /***************************************************************************

        Struct containing optional constructor arguments. There are enough of
        these that handling them as default arguments to the ctor is cumbersome.

    ***************************************************************************/

    public static struct OptionalSettings
    {
        import ocean.util.log.Appender;
        import core.sys.posix.signal : SIGHUP;

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

            Note that the signals will be handled with a delay of up to
            single epoll cycle. This is because the signal extension is synced
            with the EpollSelectDispatcher. This makes it unsuitable to handle
            critical signals (like `SIGABRT` or `SIGSEGV`) where the application
            shouldn't be allowed to proceed in the general case; for these
            cases setup an asynchronous signal handler using `sigaction` instead.

        ***********************************************************************/

        int[] signals;

        /***********************************************************************

            Signal to trigger reopening of files which are registered with the
            ReopenableFilesExt. (Typically used for log rotation.)

            If this field is set to 0, no signal handler will be installed for
            file reopening. This is useful if your app is deployed to use a
            different means of triggering file reopening (e.g. a UNIX socket
            command).

        ***********************************************************************/

        int reopen_signal = SIGHUP;

        /***********************************************************************

            Unix domain socket command to trigger reopening of files which are
            registered with the ReopenableFilesExt. (Typically used for log
            rotation).

        ***********************************************************************/

        istring reopen_command = "reopen_files";

        /***********************************************************************

            Unix domain socket command to print the `--version` output of the
            application to the unix socket.

        ***********************************************************************/

        istring show_version_command = "show_version";

        /***********************************************************************

            Set of signals to ignore. Delivery of the signals specified in this
            set will have no effect on the application -- they are not passed
            to the default signal handler.

        ***********************************************************************/

        int[] ignore_signals;

        /// Delegate for LogExt that instantiates a `Appender.Layout` from a name
        Appender.Layout delegate (cstring name) make_layout;

        /***********************************************************************

            By default TaskExt is disabled to prevent breaking change for
            applications already configuring scheduler on their own.

        ***********************************************************************/

        bool use_task_ext;

        /***********************************************************************

            Only used if `use_task_ext` is set to `true`. Defines default
            scheduler configuration to be used by TaskExt.

            Fields present in config file will take priority over this.

        ***********************************************************************/

        IScheduler.Configuration scheduler_config;
    }

    /***************************************************************************

        This constructor only sets up the internal state of the class, but does
        not call any extension or user code.

        Note: when calling this constructor, which does not accept an epoll
        instance, you must pass the epoll instance to startEventHandling
        instead.

        Params:
            name = Name of the application (to show in the help message)
            desc = Short description of what the program does (should be
                         one line only, preferably less than 80 characters)
            ver = application's version information
            settings = optional settings (see OptionalSettings, above)

    ***************************************************************************/

    public this ( istring name, istring desc,
        VersionInfo ver, OptionalSettings settings = OptionalSettings.init )
    {
        super(name, desc);

        // DaemonApp always handles SIGTERM:
        settings.signals ~= core.sys.posix.signal.SIGTERM;

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
        this.log_ext = new LogExt(settings.make_layout,
                                  settings.use_insert_appender);
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

        // Create and register signal extension
        this.signal_ext = new SignalExt(settings.signals,
                settings.ignore_signals);
        this.signal_ext.registerExtension(this);
        this.registerExtension(this.signal_ext);

        this.pidlock_ext = new PidLockExt();
        this.config_ext.registerExtension(this.pidlock_ext);
        this.registerExtension(this.pidlock_ext);

        this.unix_socket_ext = new UnixSocketExt();
        this.config_ext.registerExtension(this.unix_socket_ext);
        this.registerExtension(this.unix_socket_ext);

        if (settings.show_version_command.length)
        {
            this.ver_ext.setupUnixSocketHandler(this, this.unix_socket_ext,
                    settings.show_version_command);
        }

        if (settings.use_task_ext)
        {
            this.task_ext = new TaskExt(settings.scheduler_config);
            this.config_ext.registerExtension(this.task_ext);
        }

        // Create and register repoenable files extension
        this.reopenable_files_ext = new ReopenableFilesExt();

        if (settings.reopen_signal)
        {
            this.reopenable_files_ext.setupSignalHandler(this.signal_ext,
                    settings.reopen_signal);
        }

        if (settings.reopen_command.length)
        {
            this.reopenable_files_ext.setupUnixSocketHandler(
                    this.unix_socket_ext, settings.reopen_command);
        }

        this.registerExtension(this.reopenable_files_ext);

        this.system_stats = new CpuMemoryStats();
        this.gc_stats = new GCStats();
    }

    /***************************************************************************

        This method must be called in order for signal and timer event handling
        to start being processed. As it registers clients (the stats timer and
        signal handler) with epoll which will always reregister themselves after
        firing, you should call this method when you are about to start your
        application's main event loop.

        Note that, as this method constructs the timer extension, it may only be
        used once this method has been called.

        Params:
            epoll = the epoll instance to use for event handling. If null is
                passed, then the epoll-accepting-ctor must have been called. If
                non-null is passed, then the other ctor must have been called.

    ***************************************************************************/

    public void startEventHandling ( EpollSelectDispatcher epoll )
    {
        verify(
            (epoll !is null) ^ (this.epoll !is null),
            "Must pass epoll either via ctor or startEventHandling " ~
                "argument (but not both)"
        );

        if (this.epoll is null)
            this.epoll = epoll;

        verify(this.timer_ext is null);

        // Create and register timer extension
        this.timer_ext = new TimerExt(this.epoll);
        this.registerExtension(this.timer_ext);

        // Register stats timer with epoll
        ulong initial_offset = timeToNextInterval(this.stats_ext.config.interval);
        this.timer_ext.register(
            &this.statsTimer, initial_offset, this.stats_ext.config.interval);

        // Register signal event handler with epoll
        this.epoll.register(this.signal_ext.selectClient());

        /// Initialize the unix socket with epoll.
        this.unix_socket_ext.initializeSocket(this.epoll);
    }

    /***************************************************************************

        Params:
            interval = interval used for calling the stats timer
            current  = current time, default to now (`time(null)`)

        Returns:
            function to calculate the amount of time to wait until the next
            interval is reached.

    ***************************************************************************/

    private static ulong timeToNextInterval (ulong interval, time_t current = time(null))
    {
        return (current % interval) ? (interval - (current % interval)) : 0;
    }

    unittest
    {
        time_t orig = 704124854; // 14 seconds past the minute
        test!("==")(timeToNextInterval(15, orig), 1);
        test!("==")(timeToNextInterval(20, orig), 6);
        test!("==")(timeToNextInterval(30, orig), 16);
        test!("==")(timeToNextInterval(60, orig), 46);
        test!("==")(timeToNextInterval(15, orig + 1), 0);
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
        this.gc_stats.start();
        scope(exit) this.gc_stats.stop();

        if (this.task_ext is null)
            return this.run(this.args, this.config);

        this.startEventHandling(theScheduler.epoll());
        return this.task_ext.run(&this.mainForTaskExt);
    }

    /***************************************************************************

        Used inside `run` if TaskExt is enabled to workaround double `this`
        issue with inline delegate literal

    ***************************************************************************/

    private int mainForTaskExt ( )
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
        this.exit(status, msg, Logger.init);
    }

    /// Ditto
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

        Collects CPU and memory stats and reports it to stats log. Should be
        called periodically (inside onStatsTimer).

    ***************************************************************************/

    protected void reportSystemStats ( )
    {
        this.stats_ext.stats_log.add(this.system_stats.collect());
    }

    /***************************************************************************

        Collects CPU and memory stats for incoming prometheus' requests. Should
        be sent, as a callback, to the CollectorRegistry instance used in
        prometheus request listener.

    ***************************************************************************/

    public void collectSystemStats ( Collector prometheus_collector )
    {
        prometheus_collector.collect(this.system_stats.collect());
    }

    /***************************************************************************

        Collects GC stats and reports them to stats log. Should be
        called periodically (inside onStatsTimer).

    ***************************************************************************/

    protected void reportGCStats ( )
    {
        this.stats_ext.stats_log.add(this.gc_stats.collect());
    }

    /***************************************************************************

        Collects GC stats for incoming prometheus' requests. Should be sent,
        as a callback, to the CollectorRegistry instance used in prometheus
        request listener.

    ***************************************************************************/

    public void collectGCStats ( Collector prometheus_collector )
    {
        prometheus_collector.collect(this.gc_stats.collect());
    }

    /***************************************************************************

        Called by the timer extension when the stats period fires. By default
        does nothing, but should be overridden to write the required stats.

    ***************************************************************************/

    protected void onStatsTimer ( )
    {
    }

    /***************************************************************************

        ISignalExtExtension method default implementation.

        This method is implemented with behaviour most commonly desired in apps
        that don't do any custom signal handling - attempt cleaner shutdown on
        SIGTERM signal.

        See ISignalExtExtension documentation for more information on how to
        override this method with own behaviour. `super.onSignal` is not needed
        to be called when doing so.

        Note that the default `onSignal` implementation handles `SIGTERM` and
        calls `theScheduler.shutdown` upon receiving the signal. This results in
        clean termination but may also cause some in-progress data loss from
        killed tasks - any application that must never loose data needs to
        implement own handler.

    ***************************************************************************/

    override public void onSignal ( int signum )
    {
        switch ( signum )
        {
            case core.sys.posix.signal.SIGTERM:
                // Default implementation to shut down cleanly
                if (isSchedulerUsed())
                    theScheduler.shutdown();
                else
                    this.epoll.shutdown();
                break;
            default:
                break;
        }
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
        import core.sys.posix.signal: SIGINT, SIGTERM;

        import ocean.io.select.EpollSelectDispatcher;

        this ( )
        {

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
            super(name, desc, ver, settings);
        }

        // Called after arguments and config file parsing.
        override protected int run ( Arguments args, ConfigParser config )
        {
            // In order for signal and timer handling to be processed, you must
            // call this method. This registers one or more clients with epoll.
            this.startEventHandling(new EpollSelectDispatcher);

            // Application main logic. Usually you would call the epoll event
            // loop here.

            return 0; // return code to OS
        }

        // Handle those signals we were interested in
        //
        // Note that DaemonApp provides default `onSignal` implementation
        // that handles `SIGTERM` and calls `theScheduler.shutdown` upon
        // receiving the signal. This results in clean termination but may also
        // cause some in-progress data loss from killed tasks - any application
        // that must never loose data needs to implement own handler.
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
            this.reportSystemStats();
            this.reportGCStats();
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
