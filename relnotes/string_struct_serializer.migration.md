* `ocean.io.serialize.StringStructSerializer`

  When serializing structs into strings, if the struct contains zero-length
  non-character arrays, then they would be previously formatted as `[]` but
  without a space following the preceding colon. An extra space has now been
  added between the colon and `[]`.
