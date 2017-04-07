* `ocean.sys.socket.InetAddress`, `ocean.sys.socket.AddressIPSocket`

  Functions which accept an IP address string now report an invalid address by
  setting `errno = EINVAL`. It was `EAFNOSUPPORT` before, which is wrong because
  `EAFNOSUPPORT` refers to the wrong address family, which is not the case.
  This affects the following methods:
  * `ocean.sys.socket.InetAddress.opCall`
  * `ocean.sys.socket.AddressIPSocket.bind(cstring, ushort)`
  * `ocean.sys.socket.AddressIPSocket.connect(cstring, ushort)`
