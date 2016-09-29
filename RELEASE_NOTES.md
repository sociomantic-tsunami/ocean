Release Notes for Ocean v2.2.0
==============================

Note: If you are upgrading from an older version, you have to upgrade
incrementally, following the instructions in the previous versions' release
notes.

These notes are usually structured in 3 sections: **Migration Instructions**,
which are the mandatory steps a user must do to update to the new version,
**Deprecated**, which contains deprecated functions which are not recommended to
be used (and will be removed in the next major release) but will not break any
old code, and **New Features** which are new features available in the new
version that users might find interesting.


New Features
============

* `ocean.util.cipher.gcrypt.AES`

  Aliases for AES-CBC ciphers have been added.

* `ocean.text.utf.UtfUtil`

  Add `truncateAtN` method which truncates a string at the last space before
  the n-th character or, if the resulting string is too short, at the n-th
  character.

* `ocean.util.cipher.gcrypt.c.kdf`

  Bindings to gcrypt's C functions for key derivation have been added.

* `ocean.util.cipher.gcrypt.core.KeyDerivationCore`

  A wrapper class for gcrypt's key derivation functions has been added.

* `ocean.util.cipher.gcrypt.PBKDF2`

  An alias for key derivation using the PBKDF2 algorithm has been added.

* `ocean.util.cipher.misc.Padding`

  New module with cryptographic padding functions, currently contains functions
  for PKCS#7 and PKCS#5 padding.

* `ocean.text.convert.Formatter`

  This new module provides similar functionalities to `ocean.text.convert.Layout_tango`,
  but use compile-time type information instead of `TypeInfo` to do so.
  In the long run, `ocean.text.convert.Layout_tango` will be deprecated and this module will replace it.

  The module provides 4 different functions:
  - `format` takes no buffer and allocate a new `istring`. Equivalent to `Format(format_string, args)`.
  - The first `sformat` overload takes a `Sink` (`scope` delegate of type `size_t delegate (cstring)`) as first parameter and will
   call this sink (possibly multiple times) with the data to append.
  - The second `sformat` overload takes a buffer (`ref mstring`) which will be appended to.
  - A `snformat` function which takes a buffer (`mstring`) and will overwrite it. The buffer won't be extended and if the formatted
    string is too long, the extra data will be discarded.

  This brings a couple of advantages:
  - If a type isn't supported, an error will be issued at compile-time
  - Support formatting of type which don't have enough TypeInfo attached, like `struct`
  - As a result of the previous point, support formatting our Typedef implementation
  - Better code is generated, as lots of branches can be taken in advance
  - Doesn't use excessive amount of stack space

  As a result of the re-implementation, some behaviour might differ from `Layout_tango`'s.
  For example:
  - Pointers are now formatted as "{X16#}" in 64 bits and "{X8#}" in 32 bits
    So formatting a random pointer will give "0XFF002A0042000000" in 64 bits for example.
  - `null` pointers and references will now be formatted as `null` instead of `0`
  - If a type define an overload of `toString` that takes a string sink as a parameter
    (e.g. `void toString (scope size_t delegate (cstring) sink)`, it will be preferred
    over the regular `toString` overload, as the sink one is most-likely non-allocating.
    Previously only `istring toString()` was supported.
  - Structs will now be formatted as a curly-braced enclosed, comma-separated list
    of "field: value".
    For example `struct T { uint c; char[] data }` will be formatted as `{ c: 0, data: null }`
    by default.
    Inside structs, `char` and string types will be quoted. Using the previously defined `struct T`,
    an instance of `T(42, "Hello world")` will result in `{ c: 42, data: "Hello world" }`
  - AA formatting changed from `{key => value, ...}` to `[ key: value, ... ]`.
  - String nested inside an aggregate (arrays, AAs, struct...) are now quoted.
  - Function pointers are now formatted as their type + pointer, delegates as type + funcptr + ptr.
  - `union` is the only built-in type which is not supported, as the formatter would need to be
    able to discriminate it in order to print it, or avoid following references, which would lead
    to an inconsistent behaviour.
  - Many types might now be more respectful of the formatting options given to them, especially
    when it comes to string size limitation.

  In addition, the following are not supported by `Formatter`:
  - Formatting from / into arrays of `wchar` or `dchar` will output an array instead of string.
    Though it is not inherent to the design, the current version only support arrays of `char` as strings.
  - Formatting values of imaginary or complex floating point type. Those are deprecated in D2.
  - Formatting floating point as hexadecimal
