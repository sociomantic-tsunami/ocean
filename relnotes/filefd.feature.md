### Wrap already open file descriptor in File instance

* `ocean.io.device.File`

  `File` class implements all ocean's IO interfaces, so it's
  very convenient to wrap a file descriptor of previously
  opened device into `File` instance for easy composition
  in the rest of the IO framework. `File` class now implements
  `setFileHandle` method which allows user to wrap the
  `File` around it.
