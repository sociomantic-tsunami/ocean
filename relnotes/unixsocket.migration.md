* `ocean.net.server.unix.UnixListener`,
  `ocean.net.server.unix.UnixConnectionHandler`,
  `ocean.util.app.ext.UnixSocketExt`

Handlers previously used for communicating with the user on UnixSocket now
accept additional delegate: `waitReply`. Handlers now may initiate interactive
session with the user by sending the data via `send_response` and waiting for
user to reply via `wait_reply`.
