* `ocean.task.Scheduler`

  `theScheduler` now has new public field, `exception_handler`, which is a
  delegate called each time unhandled exception terminates a task run by the
  scheduler. If `null`, the exception will be simply rethrown same as before,
  otherwise rethrowing has to be done explicitly in the delegate if desired.
