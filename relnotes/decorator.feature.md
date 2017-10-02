* `ocean.util.serialize.contiguous.Serializer`
  `ocean.util.serialize.contiguous.Deserializer`

  `serialize` and in-place `deserialize` methods now support `Buffer!(void)` as
  one of possible buffer types. Old `void[]` and derivatives are still supported
  too.

* `ocean.util.serialize.contiguous.MultiVersionDecorator`

  `store` and in-place `load` methods now support `Buffer!(void)` as one of
  possible buffer types. Old `void[]` and derivatives are still supported too.

