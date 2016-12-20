* `ocean.net.device.*`

  This package is now deprecated. If you need socket and address, use ones
  from `ocean.sys.socket`.

* `ocean.net.InternetAddress`

  This module is deprecated and one should use `ocean.sys.socket.InetAddress`
  instead.

* `ocean.net.http.HttpClient`, `ocean.net.http.HttpGet`,
  `ocean.net.http.HttpPost`, `ocean.util.log.AppendMail`,
  `ocean.util.log.AppendSocket`

  These modules were depending on now deprecated `ocean.net.device` package
  and they are deprecated.
