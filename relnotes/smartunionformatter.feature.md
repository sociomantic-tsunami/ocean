### New `SmartUnion` formatting function

`ocean.text.formatter.SmartUnion`

The helper function `asActiveField` accepts a smart-union and returns a struct
with a `toString` method, suitable for passing to the `Formatter`. This formats
the value of the active field (if any), and (optionally) its name.

