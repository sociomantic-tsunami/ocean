* `ocean.io.compress.ZlibStream`

   `ZlibStreamDecompressor.decodeChunk` no longer performs automatic resource
   cleanup, and no longer returns a value. This functionality has been moved to
   a new member function `end`, which should be called after the last call to
   `decodeChunk` (ie, when EOF is reached, or when the download has finished).

