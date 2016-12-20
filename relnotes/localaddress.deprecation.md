* `ocean.net.device.LocalSocket`

  All classes in this module are now deprecated. Users should move to using
  `sockaddr_un` instead.

* `ocean.sys.socket.UnixSocket`

  All methods accepting `LocalSocket` are deprecated in favour of the ones
  accepting pointer to `sockaddr_un`.
