* `ocean.io.device.Device`

  `Device` class (which the `File` inherits from) got two new methods: `pread`
  and `pwrite` which does reading and writing from the given offset, not changing
  the file offset in any way while doing it.
