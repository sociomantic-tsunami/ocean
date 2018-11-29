### Garbage Collector stats

* `ocean.application.components.GCStats`,

  `GCStats` can be used with dmd-transitional in order to get stats about the
  garbage collector. It will collect:
    - `gc_run_duration` The number of microseconds the garbage collector ran
        for during the last collection cycle.
    - `gc_run_percentage` The percentage of time that was spent by the
        garbage collector during the last collection cycle.

* `ocean.util.app.DaemonApp`

  `DaemonApp` class now contains the `reportGCStats()` method which will add
  the GC stats to the stats log file.
