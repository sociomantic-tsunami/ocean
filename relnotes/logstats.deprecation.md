## CpuMemoryStats.log is now deprecated in favour of collect

* `ocean.sys.Stats`

  Method `CpuMemoryStats.log` is now renamed to `CpuMemoryStats.collect` to better
  represent what it does (it doesn't do any logging, it just collects all the
  stats and returns them via struct instance that can be used for logging).
