* `ocean.core.SmartUnion`

  Helper mixin string `handleInvalidCases` in `SmartUnion` is added as the support
  for the `final switch`. It covers `case none` and `default:` so the actual
  switch body is as clean as possible.
