
* `ocean.net.server.unix.UnixConnectionHandler`, `ocean.net.server.unix.UnixListener`

  The new classes `UnixSocketListener` and `UnixSocketConnectionHandler` allow
  customised command handling logic to be provided via a template type argument.
  The specified type must provide a method `void handle ( cstring command,
  cstring args, void delegate ( cstring response ) send_response )` that will
  handle any command received by the Socket.
