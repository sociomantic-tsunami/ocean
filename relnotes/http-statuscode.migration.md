* `ocean.net.http.consts.StatusCodes`, `ocean.net.HttpConst.HttpResponseCode`,
  `ocean.net.http.HttpConnectionHandler`, `ocean.net.http.HttpException`

  - `StatusCode` has been removed, use `HttpResponseCode` instead.
  - `HttpResponseCode.init` is now `HttpResponseCode.OK`.

  `StatusCode` was a `typedef` of `HttpResponseCode`, which is problematic with
  D2. Its mere purpose was to have the `OK` value as the initial value as
  required by the Sociomantic HTTP etiquette (i.e. when in doubt, respond with
  "200 OK"). `HttpResponseCode` now satifies this requirement so `StatusCode` is
  no longer needed. Historically `StatusCode` was added because at that time
  `HttpResponseCode` was code maintained by the Tango team which we couldn't ask
  for introducing changes reflecting our business policy.
