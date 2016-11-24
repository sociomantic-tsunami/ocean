* `ocean.util.serialize.contiguous.Contiguous`,
`ocean.util.serialize.contiguous.Serializer`,
`ocean.util.serialize.contiguous.DeSerializer`

  Remove support for pointers. This feature is broken in Contiguous, and
  Serializer/Deserializer don't support it.
  In Contiguous pointers of type `T*` were assumed to point to one object, whose
  data are stored in the contiguous buffer. However, since a pointer may point
  to the first element in an array and the length of the array isn't known from
  just the pointer, this is a wrong and therefore dangerous assumption.
  Moreover, `void*` was assumed to point to a one-byte (`void.sizeof`) object.
