* `ocean.text.convert.Formatter`

  The formatter will now treat `null` arrays the same way it treats empty array.
  This means `null` typed as array of char will result in empty string instead of
  the string `null`, and other null arrays will result in `[]`.
  Null associative array will result in `[:]`.
