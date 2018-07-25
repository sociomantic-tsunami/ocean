### New `Daemon` application base class

`ocean.application.Daemon`

The new class is intended to be a replacement for the old `DaemonApp`, with two
main advantages:
1. It provides less options, resulting in more standardised applications.
2. Its internal code is greatly simplified (it doesn't use any kind of
   extensions framework), for increased ease of maintenance.

The new application base class has the following built-in features:
* Command line arguments parsing, including the following built-in args:
    * `--help`
    * `--version`
    * `--build-info`
    * `--confg`: specifies the config files to read
    * `--override-config`: allows config values to be overriden from the
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
    * `show_version`
    * `show_build_info`
    * `reopen_files`: reopens the specified files (must be registered with
      the open files registry; see above)
    * `reload_config`: re-parses the config files and reconfigures any
      internal components that can be (this currently includes only the
      logging system).
* Creation of a PID lock file, to prevent multiple instances of the
  application from starting in the same directory.
* Epoll and task scheduler setup.
* A main `Task` instance that the application's main logic is run in.

