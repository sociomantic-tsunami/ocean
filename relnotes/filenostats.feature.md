* `ocean.sys.Stats`, `ocean.sys.stats.linux.ProcVFS`, `ocean.sys.stats.linux.Queriable`

  The new module `ocean.sys.Stats` contains a function to get information
  about the number of file descriptors currently in use by the process. (It
  is implemented via the lower level functions in `ocean.sys.stats.linux.ProcVFS`
  and `ocean.sys.stats.linux.Queriable`.)
