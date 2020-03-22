### `ocean.core.Time` has been deprecated

* `ocean.core.Time`

This module has been completely deprecated and should be replaced by usages of `core.time`.
The sole function in this module, `seconds`, was mostly used as argument to `Thread.sleep`.
It can be replaced by `seconds` from `core.time` if the argument is an integer,
or `msecs`, `usecs`, `hnsecs` or `nsecs` depending on the expected precision.
