## Deprecated RRTI-specific functions in Stdout / stream's Format

`ocean.io.Stdout`, `ocean.io.stream.Format`

In both those module, specific support for RTTI has be removed to prepare for
the transition from Layout_tango to Formatter.  This includes `format` and
`formatln` methods accepting the `TypeInfo[]` / `void*[]` duo, the `print`
function which was redundant with `format` and of little use, the `layout`
setter and getter, and the `Layout`-accepting constructors. Same applies to
`opCall` as it was aliasing the `print` method.
