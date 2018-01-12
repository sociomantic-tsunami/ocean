## Several methods now support `Buffer!(void)` as one of possible buffer types

`ocean.util.serialize.contiguous.Serializer`
`ocean.util.serialize.contiguous.Deserializer`
: `serialize` and in-place `deserialize`

`ocean.util.serialize.contiguous.MultiVersionDecorator` : `store` and in-place `load`

Old `void[]` and derivatives are still supported too.
