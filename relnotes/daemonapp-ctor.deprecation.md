* `ocean.util.app.DaemonApp`

  The constructor which accepts an epoll instance is deprecated. Code should be
  changed to pass the epoll instance to `startEventHandling` instead. After
  making this change, be careful not to use the `timer_ext` member until after
  calling `startEventHandling`.
