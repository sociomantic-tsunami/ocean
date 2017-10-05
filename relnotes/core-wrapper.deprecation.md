* `ocean.core.Runtime`, `ocean.core.Thread`, `ocean.core.Vararg`

  Those modules were deprecated, as they are nothing but thin wrapper around runtime modules.
  Import `core.runtime`, `core.thread` or `core.stdc.stdarg` instead.

* `ocean.core.VersionIdentifiers`

  This module holds a functionality which was MakD specific and has long been moved there.
  It's not expected to be of any interest to application, and if needed MakD's `Version`
  module can be imported, or if not suitable, it can be trivially replicated.
