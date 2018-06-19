### Add UnixSocketExt handler to display the AppStatus to socket

* `ocean.io.console.AppStatus`

  `AppStatus` now allows program to register the AppStatus instance
  with the Unix domain socket's handler and print the app status there
  until the socket is connected. The usage example is as simple as
  `this.unix_socket_ext.addHandler("show_status", &this.app_status.connectedSocketHandler)`
