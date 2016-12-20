* `ocean.util.app.DaemonApp`

  `OptionalSettings.ignore_signals` may be used to specify a set of signals to
  be ignored by the application. Signals in this set will not be passed to the
  default signal handler.

* `ocean.util.app.ext.SignalExt`

  Users can now specify that certain signals be ignored by the application, via
  an array passed to the constructor or the new method `ignore`. This feature
  can be useful for disabling the default handler for a signal.
