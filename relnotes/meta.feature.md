## Enhancements in `ocean.meta`

More utilities have been ported from `ocean.core.Traits`:

`ocean.meta.codegen.CTFE`

Now `toString` accepts compile-time integers of any size, and not just
`long`/`ulong`.

`ocean.meta.traits.Basic`

New template, `isBasicArrayType`, checks if array is either dynamic or static
(but not an AA).

`ocean.meta.traits.Arrays`

New module for more complicated array-based traits. Contains single template for
now, `isUTF8StringType`.

`ocean.meta.traits.Aggregates`

New module for traits specialized for classes, structs and unions. Provides two
traits, `hasMember` and `hasMethod`.
