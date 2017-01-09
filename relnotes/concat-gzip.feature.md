* `ocean.io.compress.ZlibStream`

   Previously, `ZlibStreamDecompressor` rejected concatenated gzip streams,
   even though such streams are valid. They are now supported. This requires
   a small change to the API. The `decodeChunk` function no longer attempts
   to perform automatic resource management; this was unreliable and could
   cause memory leaks. Now, a new member function `ZlibStreamDecompressor.end`
   must be called after the last call to `decodeChunk`.
