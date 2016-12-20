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

  `PidLockExt` extension is added to the `DaemonApp`. See release notes for
  `ocean.util.app.ext.PidLockExt` for more info.
