* `ocean.util.log.Log`

  This module is now deprecated, and all usages should be replaced with
  `ocean.util.log.Logger` which provides the same functionalities,
  but uses the Formatter (and hence all data types can be logged).
  The module itself, the `Logger` type, and a couple of function are
  not marked as `deprecated` due to complications with the compiler,
  but enough functions (including the formatting primitives) are
  marked as deprecated so make any user notice they are using it.
