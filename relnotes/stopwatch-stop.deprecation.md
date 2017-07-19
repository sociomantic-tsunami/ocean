* `ocean.time.StopWatch`

  The `stop` method of `StopWatch` was highly misleading in its name and
  documentation, since it did not (contra to claims) stop the underlying
  timer.  It has therefore been renamed (and redocumented) to `sec` (by
  analogy to the existing `microsec` method), with a deprecated alias to
  support calls to the old `stop`.
