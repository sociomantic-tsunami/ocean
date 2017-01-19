* `ocean.util.log.Log : Logger`

  The parameter-less `trace`, `info`, `warn`, `error`, `fatal` functions
  that allowed to know if a certain level is enabled have been deprecated.
  They can be trivially replaced by `logger_instance.enabled(Logger.Level.XXXX)`.