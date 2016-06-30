
Release Notes for Ocean v2.0.0
==============================

These notes are usually structured in 3 sections: **Migration Instructions**,
which are the mandatory steps a user must do to update to the new version,
**Deprecated**, which contains deprecated functions which are not recommended to
be used (and will be removed in the next major release) but will not break any
old code, and **New Features** which are new features available in the new
version that users might find interesting.


Changes Since Ocean v1.30.x
---------------------------

**Note:** If you are upgrading from an older version, you have to upgrade
incrementally, following the instructions in the previous versions' release
notes.


### Dependencies

Dependency | Version
-----------|---------
makd       | v1.3.x
tango      | v1.5.1


### Migration Instructions

* `ocean.*`

  - All **deprecated symbols** in Ocean v1.x.x have been **completely removed**.

  - All modules have been stripped of any mentions of mutexes and
    `synchronized`. This shouldn't affect any of our projects as those are
    exclusively single-threaded and any synchronization is thus wasted time.

* `tango.*`

  Completely removed, use modules from ocean package.

* `ocean.util.app.ext.LogExt`,
  `ocean.util.app.ext.StatsExt`,
  `ocean.util.log.Stats`,
  `ocean.util.log.Config`

  The `LogExt` and `StatsExt`, the `configureLoggers()` function in
  `ocean.util.log.Config`, and the constructor of `StatsLog` no longer configure
  the application's log files to automatically rotate themselves (via the
  `AppendSyslog` appender in tango). Instead, it is expected that logs will be
  rotated via the `logrotate` system facility in conjunction with the
  `ReopenableFilesExt`. Programs which make use of loggers should be based on
  ocean's `DaemonApp`, which provides all the facilities required for rotated
  log files (see the [v1.26.0 release notes](https://github.com/sociomantic/ocean/releases/tag/v1.26.0)
  for migration instructions).

  The file-rotation-related fields or `StatsLog.Config` (that is,
  `max_file_size`, `file_count`, `start_compress`) have been removed, along with
  the corresponding `default_` constants in `StatsLog`.

* `ocean.core.Array_tango`

  Several function unused in sociomantic projects have been removed completely:
  - all heap manipulation function
  - `krfind`
  - `lbound` and `ubound`
  - tango `bsearch` version (one that returns boolean)
  - tango `shuffle` version (one that uses predicate struct as random source)

* `ocean.core.Array` `ocean.core.Array_tango`

  These modules have been completely reimplemented to support new `Buffer`
  struct and improve D2 porting by simplifying templated code. All functions
  have been split into 3 modules `ocean.core.array.Mutation`,
  `ocean.core.array.Transormation` and `ocean.core.array.Searching` and both
  `ocean.core.Array` and `ocean.core.Array_tango` provide them all. As a result
  some clashes or subtle mismatches may happen in applicaton causing
  compilation errors. For example, it won't be possible anymore to rely on
  implicit conversion of `Typedef` values when passing to such functions.

New Features
============

* `ocean.core.Buffer`

  New struct which emulates D1 array semantics (with data stomping on append)
  via wrapper struct so that it will keep working the same in D2. When
  compiled in D2 it is also marked as non-copyable to ensure that buffers
  are only ever passed by reference if they need to be resized.

