## Arguments.error is now deprecated

`ocean.text.Arguments`

In order to support the upcoming removal of `ocean.text.convert.Layout_tango`,
the `error` method that takes an argument is deprecated in favor of an `error` method
which takes no argument and uses `Layout!(char).instance` by default.