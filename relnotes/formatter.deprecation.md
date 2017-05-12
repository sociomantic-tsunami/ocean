* `ocean.text.convert.Formatter : ElementSink`

  This alias was accidentally made public on the first release of the formatter.
  It have been deprecated and should probably not affect any project.

* `ocean.text.convert.Formatter`

  The return type of the sink alias, which was `size_t`, was changed to `void`
  as the return value wasn't used.
  As a result, the `Sink` alias is deprecated in favor of `FormatterSink`,
  and so is the `sformat` overload accepting a `Sink`.
