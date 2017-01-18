* `ocean.io.device.Device`

  `(p)write/read` function will now not throw an exception if interrupted by
  signal, but they will instead try again to perform read/write.
