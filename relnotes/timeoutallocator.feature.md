* `ocean.io.select.client.TimerSet`,
  `ocean.io.select.timeout.TimerEventTimeoutManager`

  These classes are now able to specify the allocation strategy used by the
  base `TimeoutManager` class.

* `ocean.util.app.ext.TimerExt`

  `TimerExt` now uses FreeList-based allocation strategy for the internals,
  instead of deferring to GC for this, generating less GC activity.
