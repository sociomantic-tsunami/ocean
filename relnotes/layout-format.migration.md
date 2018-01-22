## Appender.Layout's `format` method sink type was updated

`ocean.util.log.Appender : Appender.Layout.format`

This method was previously accepting a `size_t delegate(Const!(void)[])` as sink type.
As we moved away from `size_t`-returning delegates, and all those layout were essentially
casting the data to `cstring` under the hood, those delegates were changed to be the same
as `FormatterSink` (that is, `void delegate(cstring)`).
Unless you are defining your own `Appender.Layout` classes, this should not have any effect on you.
