* `ocean.io.serialize.SimpleSerializer`

  `SimpleSerializer` and `SimpleSerializerArrays` are renamed to
  `SimpleStreamSerializer` and `SimpleStreamSerializerArrays` to better
  describe the fact that this is a stream-based serializer. They can be found
  under a new name inside `ocean.io.serialize.SimpleStreamSerializer` module.
  In addition, `EofException` that's being used by these classes is also moved
  to the new location.
