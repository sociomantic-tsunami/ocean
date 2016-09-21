Release Notes for Ocean v2.1.0
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

* `ocean.text.convert.Integer_tango`

  `format` and `formatter` are now templated on the integer type they get as an argument,
  allowing to properly format negative numbers into their non-decimal
  (binary, octal, hexadecimal) representation.
  In addition, passing an `ulong` value which is > `long.max` with format "d" will now
  be correctly formatted (before it resulted in a negative value and required "u" to be used).

* `ocean.util.serialize.model.VersionDecoratorMixins`

  `VersionHandlingException` has been changed to avoid allocating a
  new message any time a conversion fails.

* `ocean.transition`

  `enableStomping` function now can't be called on arrays of `immutable` or
  `const` elements. This may cause compilation errors but any code which
  is subject to it was triggerring undefined behaviour and must be fixed
  with uttermost importance.

Deprecations
============

* `ocean.util.cipher.gcrypt: MessageDigest, HMAC`

  `HMAC` has been moved to a separate module, `ocean.util.cipher.gcrypt.HMAC`.
  The `HMAC` class in `ocean.util.cipher.gcrypt.MessageDigest` is deprecated.

  `MessageDigest.hash()` and `HMAC.hash(void[][] ...)` are deprecated and
   replaced with `calculate(`ubyte[][] ...`)`.  This is to avoid an implicit
   cast from `void[][]` to `void[]` when calling the function, which causes a
   wrong hash result, and the error is hard to find.

* `ocean.io.select.client.EpollProcess.ProcessMonitor`

  All references to the ProcessMonitor class should be removed. It existed
  only as a workaround for a bug in EpollProcess, but is no longer required.

* `ocean.task.util.StreamProcessor`

* Constructor that expects `max_tasks`, `suspend_point` and `resume_point` has
  been deprecated in favor of one that takes a `ThrottlerConfig` struct.

* `ThrottlerConfig.max_tasks` and the constructors which accept a `max_tasks`
  argument have been deprecated. New constructors have been added which do not
  expect or use `max_tasks`, instead creating an unlimited task pool. If you
  want to limit the maximum number of tasks in the pool, use `getTaskPool` and
  set a limit manually.

* `ocean.text.util.StringC`

  The function `toCstring()` is now deprecated in favour of `toCString()` (note
  the uppercase `S`).

* `ocean.text.convert.Float`

  `parse` overloads for `version = float_dtoa` and `format` overload
  for `version = float_old` have been deprecated.

* `ocean.util.cipher.gcrypt.core.Gcrypt`

  The `Gcrypt` template has been deprecated, either `GcryptWithIV` or
  `GcryptNoIV` should be used, depending on if your desired encryption mode
  requires initialization vectors or not.

* `ocean.util.serialize.contiguous.VersionDecorator`

  The `VersionDecorator` defined in this module is deprecated.
  The `VersionDecorator` in the `MultiVersionDecorator` module of the same package
  should be prefered, as it handles multiple version jump without runtime performance.

* `ocean.io.serialize.XmlStructSerializer`

  This unmaintained module is deprecated.

* `ocean.text.xml.Xslt`, `ocean.text.xml.c.LibXslt`, `ocean.text.xml.c.LibXml2`

  The XSLT processor implemented here is not generic and is thus being removed
  from ocean. It will be moved to another repository.

* `ocean.util.cipher.gcrypt.AES`

  The `AES` alias has been deprecated in favor of the equivalent `AES128`.

New Features
============

* `ocean.io.serialize.StringStructSerializer`

  Introduced an overload of the `StringStructSerializer` serializer
  which takes an array of known timestamp field names.
  If a field matches one of the names and implicitly converts to `ulong`,
  an ISO formatted string will be emitted in parentheses next to the value of
  the field (which is assumed to be a unix timestamp).

  Bugfix: Trailing spaces are no longer emitted for arrays with length zero.

* `ocean.util.cipher.gcrypt.AES`

  Added libgcrypt AES (Rijndael) algorithm with a 128 bit key.

* `ocean.util.config.ClassFiller`

  In the ClassIterator, a new `opApply()` function has been added to provide
  foreach iteration only over the names of the matching configuration
  categories.

* `ocean.text.convert.Float`

  A new `format` method has been introduced, which formats a floating point value according to
  a provided format string, which is a subset of the one passed to Layout.
  It mimics what Layout will do, with the exception that "x" and "X" format string aren't handled
  anymore as the original output wasn't correct.

* `ocean.sys.socket.model.ISocket`

  Add `formatInfo` method which formats information about the socket into the
  provided buffer

* `ocean.task.util.StreamProcessor`

  Added getter method for the internal task pool.

* `ocean.io.select.client.TimerSet`

  The `schedule()` method now returns an interface to the newly scheduled event
  (`IEvent`), allowing it to be cancelled.

* `ocean.task.Task`

  Task has gained methods `registerOnKillHook`/`unregisterOnKillHook` that can be
  used to register/unregister callback hooks to be called when the Task is killed.

* `ocean.util.cipher.gcrypt.AES`

  Additional aliases for 192- and 256-bit AES ciphers have been added.

* `ocean.time.timeout.TimeoutManager`

  TimeoutManager now has a constructor that takes an optional bucket element
  allocator. The intended usage is to allow the use of an alternative allocator,
  e.g. BucketElementFreeList. This can reduce the number of GC allocations
  performed. The existing constructor uses the default bucket allocator of
  map (BucketElementGCAllocator), which will cause garbage collections.

* `ocean.task.ThrottledTaskPool`

  ThrottledTaskPool has been moved out of `ocean.task.util.StreamProcessor` and
  made public.

* `ocean.task.util.TaskPoolSerializer`

  Added methods to dump and restore tasks inside of a task pool to disk to
  facilitate preserving tasks between application restarts.

  To use the serialization and deserialization funtionality the derived task
  must implement `serialize` and `deserialize`.
  `public void serialize ( ref void[] buffer )`
  `public void deserialize ( void[] buffer )`

  See usage example in the unit test for example implementation.
