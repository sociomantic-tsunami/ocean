* `ocean.util.log.Log`

  `Log` now contains `Stats` struct which aggregates the number of the log
  events emitted between two calls of now introduced `Log.stats()` method.
  This can be turned off for specific loggers or parts of the hierarchy
  by setting `collect_stats` log config property to `false`.
