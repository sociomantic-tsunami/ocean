* `ocean.util.app.ext.UnixSocketExt`

  A new extension to add unix socket command handling to DaemonApp has been
  added. When the `[UNIX_SOCKET]` config group exists, a unix socket will be
  created under the path provided as `path`.

  Eg.

  ```
  [UNIX_SOCKET]
  path = app_name.socket
  ```
