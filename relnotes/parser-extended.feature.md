## Simplified format specifier

`ocean.text.convert.Formatter`

The Formatter used to refuse format specifiers lacking a colon, so `{:X}` had to be used instead of `{X}`.
This baseless limitation was removed, and now `{X}` works as `{:X}`.