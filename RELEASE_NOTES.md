Release Notes for Ocean v2.3.0
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

* `ocean.core.Traits`
  A new symbol, `TemplateInstanceArgs` was introduced.
  It allows to get the arguments of a template instance in a D1-friendly manner.
  It can also be used to check if a type is an instance of a given template.

* `ocean.util.config.ConfigFiller`

  Provides the same functionality as the old `ClassFiller`, but it's
  extended to support `struct`s too.

* `ocean.util.container.queue.LinkedListQueue`

  Added the ability to walk over a `LinkedListQueue` with a foreach statement.
  It will walk in order from head to tail.

* `ocean.util.encode.Base64`

  - the encode and decode tables used by `encode`, `encodeChunk` and `decode` have been rewritten in a readable way,
    and made accessible to user (`public`) under the `defaultEncodeTable` and `defaultDecodeTable` names, respectively;
  - encode and decode table for url-safe base64 (according to RFC4648) have been added under the `urlSafeEncodeTable`
    and `urlSafeDecodeTable`, respectively;
  - `encode` and `decode` now accepts their table as template argument: this means one can provide which characters are
    used for base64 encoding / decoding. By default `default{Encode,Decode}Table` are used to keep the old behavior.
  - `encode` now takes a 3rd argument, `bool pad` which defaults to `true`, to tell the encoder whether to pad or not.

* `ocean.net.server.unix.UnixListener`, `ocean.net.server.unix.UnixConnectionHandler`

  `UnixListener` and `UnixConnectionHandler` classes are added with support for listening on the unix socket
   and responding with the appropriate actions on the given commands. Users can connect to the application on
   the desired unix socket, send a command, and wait for the application to perform the action and/or write
   back the response on the same connection.

* `ocean.io.serialize.StringStructSerializer`

  A new optional boolean flag has been added to the `serialize()` function. If
  this flag is set, then single character fields in structs will be serialized
  into equivalent friendly string representations if the fields contain
  whitespace or other unprintable characters.
  For example, the string '\n' will be generated for the newline character, '\t'
  for the tab character and so on.

* `ocean.io.select.EpollSelectDispatcher`

  Optional delegate argument of `eventLoop` method now can return `bool`,
  indicating if there is any pending work left at the call
  site. This is likely to only be relevant for `ocean.task.Scheduler` internals

Deprecations
============

* `ocean.util.config.ClassFiller`

  Deprecated in favour of the new `ConfigFiller` which provides the
  same interface.

* `ocean.io.select.EpollSelectDispatcher`

  Old overload of `eventLoop` was deprecated. If your app call `eventLoop` with
  no arguments, it won't be affected.
