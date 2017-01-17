* `ocean.util.app.DaemonApp`

  It is now possible to pass your epoll instance to `DaemonApp` via
  `startEventHandling` (which you usually call inside the `run` method). An
  epoll instance is no longer required by the constructor. Passing the epoll
  instance at this later stage can simplify some application workflows (e.g.
  reading task scheduler config from a file, before constructing the epoll
  instance).

  Important notes when adapting code to make use of this new feature (i.e.
  passing your epoll instance to `startEventHandling`):

    1. You must also adapt your code to not pass it to the constructor.
    2. You must ensure that you do not use the `timer_ext` member of `DaemonApp`
       until after calling `startEventHandling`.
