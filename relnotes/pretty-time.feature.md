* `ocean.text.convert.DateTime_tango`

  New `asPrettyStr` function is a thin non-allocating wrapper over `Time` value
  which enhances it with `toString` method compatible with the `Formatter` and
  generates formatted string using current locale configured in `DateTime_tango`.

  ```D
  import ocean.text.convert.Formatter;
  import ocean.text.convert.DateTime_tango;

  test!("==")(
    format("{}", asPrettyStr(Time.epoch1970)),
      "01/01/70 00:00:00"
  );
  ```

  This is intended as drop-in replacement for own `Time.toString` method which
  is going to be deprecated.
