* `ocean.util.log.Log : Hierarchy`

  The `name` property was deprecated in favor of `label`, which is part of the
  `ILogger.Context` interface.   The `label` implementation was previously
  returning an empty string and now returns the name passed to the constructor.
  In order to mimic the property approach, the setter which was previously
  named `name` is available under `label` as well, despite not being part
  of the interface.
