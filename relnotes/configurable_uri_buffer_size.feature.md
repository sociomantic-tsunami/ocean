* `ocean.net.Uri`

  One constructor for `Uri` now takes an optional parameter specifying how big
  to make the initial buffer used to URL decode URIs into.
  The default is 512B. If you know you will be using larger URIs than this
  then it is more GC friendly to use a larger value when constructing.

* `ocean.net.http.HttpRequest`

  One constructor for `HttpRequest` now takes an optional parameter specifying
  how big a buffer the internal `Uri` object should use to decode URIs into.
  The default is 512B. If you know you will be receiving requests with URIs
  longer than this then it is more GC friendly to use a larger value when
  constructing.
