* `ocean.util.log.model.ILogger`

  Formatting functions (trace, info, warn, error, fatal) have been removed from the ILogger interfaces.
  Those are not compatible with the future logger, which will use templates.
  It was not possible to deprecate them either, as the deprecation would have affected the widely used overrides.
