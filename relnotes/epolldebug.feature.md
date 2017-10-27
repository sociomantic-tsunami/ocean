* `ocean.io.select.EpollSelectDispatcher`

  In case `EpollFdSanity` debug flags is set `EpollSelectDispatcher` and
  related utilities will exploit the limitation in the user address space
  and stuff the least significant byte of the fd into the highest bits
  of the epoll registration data. This allows checking if the epoll firing
  the event on the ISelectClient is actually valid: it can happen that the
  ISelectClient gets reused, possibly changing its fd, but still leaving
  the registration for the old file descriptor in the epoll. This should
  help us debugging these issues more easily.
