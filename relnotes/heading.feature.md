### Allow turning off CPU/Memory usage and/or uptime in AppStatus

* `ocean.io.console.AppStatus`

  `AppStatus` now allows turning off particular components of the heading
  line printout. This allows user not to query potentially expensive stats
  (such as `MemoryUsage` if not needed).
