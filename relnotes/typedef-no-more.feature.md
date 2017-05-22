* `ocean.core.Traits : isTypedef, StripTypedef`

  Those functions now behave the same in D1 and D2.
  Previously they were no-op in D2 under the assumption that Typedef
  could be handled generically using type conversion instead of strict type checks,
  but this proved to not be possible.
