### `verify` now lazily allocates on `throw`, not on call

`ocean.core.Verify`

`verify` used to lazily initialize a `static` exception on the first call.
However, this means that `testNoAlloc(verify(true))` could randomly fail,
depending on the order unittests are executed,
and this transitively affected all users of `verify` (that is, everything).
`verify` will now lazily allocates only on `throw`,
so `testNoAlloc(verify(true))` will always pass,
but `testNoAlloc(verify(false))` could still potentially fail.
