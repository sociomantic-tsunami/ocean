### Deprecated the `init` method in `BitArray` and introduced `initialize`

`ocean.core.BitArray`

The `BitArray` struct has an `init` method which was used for initializing
with a set of parameters. However, this makes `BitArray.init` unusable in
some contexts in generic code, as it would trigger compiler errors.

The new `initialize` method should be used instead.
