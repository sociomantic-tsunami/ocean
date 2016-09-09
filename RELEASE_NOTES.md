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

Migration Instructions
======================


Deprecations
============


New Features
============

* `ocean.util.cipher.gcrypt.AES`

  Aliases for AES-CBC ciphers have been added.

* `ocean.text.utf.UtfUtil`

  Add `truncateAtN` method which truncates a string at the last space before
  the n-th character or, if the resulting string is too short, at the n-th
  character.
