## `EpollProcess` no longer allocates memory

`ocean.io.select.client.EpollProcess`

`EpollProcess` now uses a `FreeListAllocator` internally, so that starting a
new process after a previous one has finished no longer allocates memory.
