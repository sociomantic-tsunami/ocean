# Release Notes for Ocean v2.4.0

Note: If you are upgrading from an older version, you have to upgrade
incrementally, following the instructions in the previous versions' release
notes.

These notes are usually structured in 3 sections: **Migration Instructions**,
which are the mandatory steps a user must do to update to the new version,
**Deprecated**, which contains deprecated functions which are not recommended to
be used (and will be removed in the next major release) but will not break any
old code, and **New Features** which are new features available in the new
version that users might find interesting.


## Dependencies

Dependency                | Version
--------------------------|---------
makd                      | v1.3.x
tango runtime (for D1)    | v1.5.1


## Deprecations

* `ocean.util.cipher.AES`, `ocean.util.cipher.Blowfish`, `ocean.util.cipher.Cipher`,
  `ocean.util.cipher.HMAC`, `ocean.util.cipher.misc.Bitwise`

  The remaining non-gcrypt cipher modules are no longer supported. All code
  which requires encryption or decryption should use the libgcrypt binding in
  `ocean.util.cipher.gcrypt`.

* `ocean.net.device.*`

  This package is now deprecated. If you need socket and address, use ones
  from `ocean.sys.socket`.

* `ocean.net.InternetAddress`

  This module is deprecated and one should use `ocean.sys.socket.InetAddress`
  instead.

* `ocean.net.http.HttpClient`, `ocean.net.http.HttpGet`,
  `ocean.net.http.HttpPost`, `ocean.util.log.AppendMail`,
  `ocean.util.log.AppendSocket`

  These modules were depending on now deprecated `ocean.net.device` package
  and they are deprecated.

* `ocean.net.device.LocalSocket`

  All classes in this module are now deprecated. Users should move to using
  `sockaddr_un` instead.

* `ocean.sys.socket.UnixSocket`

  All methods accepting `LocalSocket` are deprecated in favour of the ones
  accepting pointer to `sockaddr_un`.

* `ocean.util.app.ext.SignalExt`

  `SignalExt` was previously exposing its internal `SignalEvent` member via
  `event()` method, so its `ISelectClient` part can be registered with `epoll`.
  Returning `SelectEvent` for this purpose is an overkill, as that doesn't
  allow changing the internal structure of the `SignalExt` to use some other
  mechanism to communicate with epoll. Instead, `SignalExt.selectClient()`
  method should be used.

* `ocean.util.container.HashMap`, `ocean.util.container.more.CacheMap`,
  `ocean.util.container.more.StackMap`

  These modules are now deprecated. Tango's HashMap implementation has an
  equivalent ocean counterpart in `ocean.util.container.map.HashMap`. No
  replacements exist for CacheMap & StackMap as there is no use case for them.

## New Features

* `ocean.io.select.EpollSelectDispatcher`

  If `EPOLLERR` is reported then information about the select client is added to
  the message of the exception thrown.

* `ocean.text.utf.UtfUtil.limitStringLength`

  Limits the length of a UTF-8 string, to at most the specified number of bytes.
  Ensures the UTF code units are not cut in half.

* `ocean.util.log.Log`

  `Log` now contains `Stats` struct which aggregates the number of the log
  events emitted between two calls of now introduced `Log.stats()` method.
  This can be turned off for specific loggers or parts of the hierarchy
  by setting `collect_stats` log config property to `false`.

* `ocean.util.container.map.utils.MapSerializer`

  Added additional load & dump routines which take a IConduit as its
  parameter instead of a file path. This allows passing an existing
  file handle or a MemoryDevice for use with unittesting.

  The load/dump methods were overloaded with the methods taking a conduit.
  The loadDgConduit / dumpDgConduit methods are de-facto overloads
  of loadDg / dumpDg taking a conduit but couldn't be written as actual
  overloads due to D1's limited support for template overloading.

* `ocean.io.FilePath_tango`, `ocean.io.Path`

  Methods `createFile`/`createFolder` in these two modules have learned
  to accept mode for the new file/directory as a optional argument. They default
  to their previous values, 0660 and 0777, respectively.

* `ocean.util.app.ext.PidLockExt`

  This extension should be use if it's critical that only one instance of the
  application is running (say, if sharing the working directory between two
  instances will corrupt data).

  If `[PidLock]` section with the `path` member is found in the config file,
  application will try to lock the file specified by `path` and it will abort
  the execution if that fails, making sure only one application instance per
  pid-lock file is running.

  The pid-lock file contains pid of the application that locked the file, and
  it's meant for the user inspection - the locking doesn't depend on this
  data.

* `ocean.util.app.DaemonApp`

  The `StatsLog` instance created by `StatsExt` will now be registered at the
  interval defined by `[STATS].interval` config instead of always using the
  default value.

* `ocean.util.app.DaemonApp`

  `PidLockExt` extension is added to the `DaemonApp`. See release notes for
  `ocean.util.app.ext.PidLockExt` for more info.

* `ocean.util.container.queue.LinkedListQueue`

  Adds a new method bottom() to the LinkedListQueue to make the bottom
  (youngest) element available, similar to how top() makes the oldest element
  available.

* `ocean.io.select.client.model.ISelectClient`

  Added `ISelectClient.fmtInfo()`, which outputs formatted string data of select
  client information without allocating memory.

* `ocean.stdc.posix.sys.un`

  `sockaddr_un` struct now contains a static `create` method which will
  fill the socket address with the provided path and it will set the `sin_family`
  to `AF_UNIX`, returning initialised and usable `sockaddr_un` instance.

* `ocean.util.app.ext.StatsExt`

  The stats logger config instance parsed in `processConfig` is now accessible
  as a public member. (This also allows `DaemonApp` to configure its
  `onStatsTimer` callback to fire according to the period specified in the stats
  logger config. Previously this was not configurable, in a daemon app.)
