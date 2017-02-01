* `ocean.util.log.Config`

  A new function, configureNewLoggers, was added to allow configuration of the newly-introduced Logger.
  It is now called from LogExt as well, so one can selectively use the old or new logger and expect
  them to be configured the same.

* `ocean.util.app.ext.LogExt`

  This extension will now configure both old and new logger (`ocean.util.log.Log` and
  `ocean.util.log.Logger`, respectively).
  Note that Logger won't belong to the same hierarchy, so while their initial configuration will match,
  any later tweak (e.g. adding an Appender, changing the level...) will only be reflected to the same
  kind of logger.
