* `ocean.task.util.Timer`

  New function `awaitOrTimeout` can be used to suspend some task until either
  some other specified task finished OR until timer is hit, whichever comes
  first. Conceptually it is similar to `theScheduler.await`, but with a timeout.
  It is implemented as a free function in `Timer` module though to avoid adding
  hard import dependency from scheduler module to all timer event code.

  ```D
  auto task = new SomeTask;
  bool timeout = .awaitOrTimeout(task, 1_000_000);
  // Doesn't kill on timeout by default, as it is intended to be most commonly
  // used with tasks that may/should still eventually succeed
  if (timeout)
      task.kill();
  ```
