* `ocean.stdc.stringz`

  This module and all functions inside of it have been deprecated,
  as they duplicates already existing functionalities in ocean.text.util.StringC,
  which is more idiomatic and actively maintained.
  In place of using static buffer, it is recommended to use a dynamic buffer,
  `copy` and `StringC.toCString` instead. Example:
  ```D
  char[64] buffer;
  open(toStringz("/etc/limits.conf", buffer));
  ```
  turns into:
  ```D
  static mstring buffer;
  buffer.copy("/etc/limits.conf");
  open(StringC.toCString(buffer));
  ```
