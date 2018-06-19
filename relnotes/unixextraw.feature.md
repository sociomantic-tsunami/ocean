### Support registering handlers that accept unix socket in UnixSocketExt

`UnixSocketExt` now provides an interface for the user to register the
unix socket command handlers which receive both read/write delegates and
the "raw" instance of the socket.
