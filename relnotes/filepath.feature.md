## New `FilePath.path` method to get open file path without `idup`

`ocean.io.device.File`

`File.path()` method is added which returns the file path (same as
`File.toString()`), but without `idup`ing it (unlike `File.toString()`).

