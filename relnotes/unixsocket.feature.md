## Interactive session over the unix domain socket.

`ocean.net.server.unix.UnixListener`, `ocean.net.server.unix.UnixConnectionHandler`, `ocean.util.app.ext.UnixSocketExt`

UnixConnectionHandler now accepts the map of the interactive handlers -
delegates that accept additional delegate argument: `wait_reply`. These handlers
can initiate interactive session with the user by sending the data via
`send_response` and waiting for the user to reply via `wait_reply`.
