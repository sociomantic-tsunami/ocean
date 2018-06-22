### `getMsg` is deprecated in favor of `Exception.message()`

`ocean.transition`

The `getMsg()` utility was introduced to abstract away the differences between runtimes.
Nowadays (since `v2.077.0`), it always resolves to `Exception.message()` and can be removed.
