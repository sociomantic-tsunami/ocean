* `ocean.core.StructConverter.structConvert`

  The structConvert function now supports more explicit convert functions.
  The new form of the functions must be static and have one of the following
  signatures:

    void function ( ref <From>, ref <To>, void[] delegate ( size_t ) )
    void function ( ref <From>, ref <To> )

  They no longer need to be wrapped in `static if` based on the version they are
  intended for as the parameters alone already uniquely describe from which
  version to which version they convert.
