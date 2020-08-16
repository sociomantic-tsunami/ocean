### `SmartUnion` will no longer produce conflicting `opCall`

* `ocean.core.SmartUnion`

Before this change, `SmartUnion` would generate duplicated `static opCall`
for initialization. However those `opCall` were not callable,
as the call would be ambiguous.
After this change, those `opCall` won't be generated anymore,
and only the `set` and `get` methods will be available on fields
which don't have a unique type in the `union`.
