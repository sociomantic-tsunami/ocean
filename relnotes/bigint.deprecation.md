* `ocean.math.BigInt`

  This module is deprecated in favor of `ocean.math.WideUint` because its
  implementation (immutable value that gets re-allocated on most operations)
  makes it unsuitable for Sociomantic projects. At the same time its main
  feature (unbound maximum integer size) is not of any use to Sociomantic
  projects.

  If you are interested in actual unbound big integer implementation, please
  switch to a different third-party library.
