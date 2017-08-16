* `ocean.core.Verify`

  New module with a single function, `verify`, intended to serve as drop-in
  replacement for `assert` to comply to [Sociomantic assert/enforce
  policies](https://github.com/sociomantic-tsunami/sociomantic/blob/master/Code/assert-vs-enforce.rst)

  It works similar to `enforce` as it throws `Exception` instead of an `Error`
  and will remain even when built with `-release`. But it also uses specific
  pre-constructed `SanityException` type to indicate importance of the failure.
