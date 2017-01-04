* `ocean.util.log.Appender`

  This module now contains the Appender-related classes that were previously in `ocean.util.log.Log`.
  It includes `Appender`, `AppendNull`, `AppendStream`, and `LayoutTimer`, as logger's `Layout` interface
  is defined in `Appender`.
  Public aliases are still available in `Log` and no change is expected from user code.
