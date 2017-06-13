* `ocean.net.http.HttpResponse`

  The constructor for `HttpResponse` now takes an optional parameter
  specifying how big to make the initial buffer to build responses in. The
  default is 1KB. If you know you will be sending larger responses than this
  then it is more GC friendly to use a larger value when constructing.
