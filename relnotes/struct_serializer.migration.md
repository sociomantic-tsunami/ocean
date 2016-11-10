* `ocean.io.serialize.StructSerializer`, `ocean.io.serialize.StringStructSerializer`

  Old formatting functions from `ocean.text.convert.Format` and
  `ocean.text.convert.Layout_tango` have been replaced by corresponding new
  functions from `ocean.text.convert.Formatter`.
  This is not expected to result in any changes to the users of StructSerializer
  or StringStructSerializer. However, it is recommended to keep an eye out for
  potential inconsistencies in the serialized output before and after updating.
