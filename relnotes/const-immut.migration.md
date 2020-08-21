### Templates `Const`, `Immut` and `Inout` have been removed

* `ocean.transition`, `ocean.meta.types.Qualifiers`

Those templates were used during the transition to D2, but are obsolete now.
However, due to [a DMD bug](https://issues.dlang.org/show_bug.cgi?id=20190)
they could not be deprecated. Instead, usage in downstream project was cleared,
and they were directly removed. Any usage can be replaced by the equivalent keyword
(`Immut!(T)` => `immutable(T)`, `Inout!(T)` => `inout(T)`, `Const!(T)` => `const(T)`).
