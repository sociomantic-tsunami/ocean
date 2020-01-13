### Support for streaming pkzip files

* `ocean.io.compress.ZipStream`

The new class `ZipStreamDecompressor` supports streaming of both gzip and
well-behaved single-file pkzip archives. Streaming of pkzip archives is
supported only when the archive contains a single file, and does not use
any of the exotic features allowed by the pkzip format.
