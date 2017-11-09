## Allow setting mode of unix socket after binding

`ocean.util.app.ext.UnixSocketExt`

`UnixSocketExt` now supports setting the mode for the socket after
binding. User can set it in the config file in `UNIX_SOCKET.mode`
as an octal string and the mode will be applied to the socket after
creating it. This allows setting mode which would possibly allow
all other users for connecting to the socket, since the socket is created
with the umask 002 (which would prevent other users from connecting to it).
