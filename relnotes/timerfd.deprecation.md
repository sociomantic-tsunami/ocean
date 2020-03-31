### C bindings in `ocean.sys.TimerFD` have been deprecated

* `ocean.sys.TimerFD`

This module exposed the functions `timerfd_create`, `timerfd_gettime`, `timerfd_settime`,
as well as the constants `CLOCK_MONOTONIC`, `TFD_TIMER_ABSTIME`, `TFD_CLOEXEC`, `TFD_NONBLOCK`.
Those have now been deprecated, as they are part of druntime.
`CLOCK_MONOTONIC` is part of `core.sys.posix.time`, and the other functions / constants
can be found in `core.sys.linux.timerfd` since 2.069.
The rest of the module, which provides wrapper types around this functionality, is not deprecated.
