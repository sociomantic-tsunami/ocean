* `ocean.text.util.Time`

  The `formatTime()` function now accepts an additional parameter that can be
  used to specify a custom format string to use when formatting the given UNIX
  timestamp.

* `ocean.text.util.Time`

  A new function `formatTimeRef()` has been added. Like the `formatTime()`
  function, it is also used to format a given UNIX timestamp. But there are two
  main differences:
    1. The new function takes the output buffer by reference (so it is better
       suited for formatting timestamps into a persistent dynamic buffer)
    2. The new function doesn't require the caller to set the length of the
       output buffer beforehand to be at least as large as the resulting string
