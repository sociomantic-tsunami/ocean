* `ocean.util.container.map.utils.MapSerializer`

  Added additional load & dump routines which take a IConduit as its
  parameter instead of a file path. This allows passing an existing
  file handle or a MemoryDevice for use with unittesting.

  The load/dump methods were overloaded with the methods taking a conduit.
  The loadDgConduit / dumpDgConduit methods are de-facto overloads
  of loadDg / dumpDg taking a conduit but couldn't be written as actual
  overloads due to D1's limited support for template overloading.
