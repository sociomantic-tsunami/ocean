* `ocean.util.serializer.contiguous.Deserializer`

  It is now possible to (de)serialize structs containing `Contiguous` structs
  as some of its fields. Interior pointers of nested structs will be properly
  updated during deserialization of the host.
