* `ocean.text.xml.Document`

  Copy the names and values to the node arrays rather than using slices. This
  prevents accidental overwriting of values.

  Added a new `header` method that uses a constant string as the header string
  which means the method does not allocate memory.
