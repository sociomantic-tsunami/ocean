### Allow changing of the output streams for AppStatus

* `ocean.io.console.AppStatus`, `ocean.util.log.InsertConsole`

  `AppStatus` and `InsertConsole` now support connecting and disconnecting
  to/from the output streams at runtime, decoupling them from the Stdout. This
  allows for connecting various output devices, such as unix domain sockets at
  runtime.
