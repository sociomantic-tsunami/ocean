* `ocean.task.Scheduler` `ocean.io.select.EpollSelectDispatcher`

  `theScheduler` now has new public field, `exception_handler`, which is a
  delegate called each time unhandled exception terminates a task run by the
  scheduler. If `null`, the exception will be simply rethrown same as before,
  otherwise rethrowing has to be done explicitly in the delegate if desired.

  When created/initialized by the scheduler, epoll will use the same
  centralized exception handling system to process exceptions from select
  clients. For backwards compatibility purposes, all system will behave as before
  if that exception handler is `null`.

  This new system makes possible to define global top-level exception handling
  for the whole application depending on its purpose. For example, when running
  tests it may be most convenient to abort the program immediately in such case,
  while server application will normally try to log and discard such exceptions.

  Note: In order to resume handling of further tasks after a task throws, you
  must call the new static method Task.continueAfterThrow. Failure to do so will
  lead to leaked worker fibers and potentially the scheduling of tasks halting.

  This is example of how these new features can be used in server applications:

  ```D
  initScheduler(config);
  theScheduler.exception_handler = (Task t, Exception e) {
      log.error(getMsg(e));
      ++stats.very_bad_thing;
      // `t` may be `null` here, but `continueAfterThrow` saves the day:
      Task.continueAfterThrow();
  };

  // ...

  theScheduler.eventLoop();
  ```

  Alternatively, one may use it to ensure early abort in tests:

  ```D
  initScheduler(config);
  theScheduler.exception_handler = (Task t, Exception e) {
      Stdout.formatln("Unhandled task exception!\n{}", getMsg(e));
      abort();
  };

  // ...

  theScheduler.eventLoop();
  ```

  If your applications handles all possible exceptions inside a task itself, new
  functionality can be ignored.
