* `ocean.util.app.ext.StatsExt`

  The stats logger config instance parsed in `processConfig` is now accessible
  as a public member. (This also allows `DaemonApp` to configure its
  `onStatsTimer` callback to fire according to the period specified in the stats
  logger config. Previously this was not configurable, in a daemon app.)"
