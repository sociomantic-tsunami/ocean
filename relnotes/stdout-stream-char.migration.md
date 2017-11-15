## Dropped support for non UTF-8 output in stream's FormatOutput / Stdout

`ocean.io.Stdout`, `ocean.io.stream.Format`

The `TerminalOutput` and its parent class `FormatOutput` dropped support for non UTF-8 character type.
In practice, it means that they were turned from a templated class with one template argument
to a non-templated class.
