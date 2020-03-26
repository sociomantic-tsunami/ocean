### Most modules in `ocean.stdc.posix.sys` are deprecated

* `ocean.stdc.posix.sys.ipc`, `ocean.stdc.posix.sys.mman`,
  `ocean.stdc.posix.sys.select`, `ocean.stdc.posix.sys.shm`,
  `ocean.stdc.posix.sys.stat`, `ocean.stdc.posix.sys.statvfs`,
  `ocean.stdc.posix.sys.uio`,
  `ocean.stdc.posix.sys.utsname`, `ocean.stdc.posix.sys.wait`

Those modules where just thin wrapper, publicly importing their
`core.sys.posix.sys` counterpart and can be trivially replaced.
The only two remaining modules are `ocean.stdc.posix.sys.un`,
which a `create` method and a different definition (but binary compatible)
for the `sockaddr_un` struct, and `ocean.stdc.posix.sys.socket`,
as it contains definitions not available as of DMD 2.091.0.
