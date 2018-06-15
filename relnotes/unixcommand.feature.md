### Extract the Unix socket command system from the application

The only convenient way to use the Unix domain socket as a control point was
through the `UnixSocketExt`, which was limiting this to a single socket per
application. Now the `UnixSocketExt` is only instantiating and configuring the
instance of `UnixSocketListener` and `ComandsRegistry`, which can also be
instantiated and configured manually as many times as needed.
