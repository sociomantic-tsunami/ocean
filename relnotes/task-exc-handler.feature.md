* `ocean.task.Scheduler` `ocean.io.select.EpollSelectDispatcher`

  `theScheduler` now has new public field, `exception_handler`, which is a
  delegate called each time unhandled exception terminates a task run by the
  scheduler. If `null`, the exception will be simply rethrown same as before,
  otherwise rethrowing has to be done explicitly in the delegate if desired.

  When created/initialized byt the scheduler, epoll will use the same
  centralized exception handling system to process exceptions from select
  clients. For backwards compatibility purpose, all system will behave as before
  if that exception handler is `null`.

  This new system makes possible to define global top-level exception handling
  for the whole application depending on its purpose. For example, when running
  tests it may be most convenient to abort the program immediately in such case,
  while server application will normallu try to log and discard such exceptions.
