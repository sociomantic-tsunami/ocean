* `ocean.text.convert.Utf`

  This module gained 3 new `toString` functions which accept the input as the first parameter (as UTF-*),
  and a delegate accepting a `cstring` as the second parameter.
  Those functions perform UTF-{16,32} decoding just like their counterpart, however using a sink allow
  to push the allocation strategy onto the user, and facilitate their integration into the formatter.
  Unlike the other `toString`, they do not support surrogate pair (values > U + 10_000).
