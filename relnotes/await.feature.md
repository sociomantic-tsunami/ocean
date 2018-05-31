### Awaiting on already running task

It is now possible to write code like this:

```D
  auto sub = new SubTask;
  // first await spawns sub task
  bool timeout = theScheduler.awaitOrTimeout(sub, 2_000);
  test(timeout);
  // waits for the same sub task a bit more but also timeouts
  timeout = theScheduler.awaitOrTimeout(sub, 2_000);
  test(timeout);
  // awaits unconditionally for the same sub task
  theScheduler.await(sub);
```

Previously attempt to run `await` or `awaitOrTimeout` with already scheduled
task would result in rather unhelpful assertion violation as this scenario was neither
intended to work nor had a proper error message. Now such code "just works", skipping
scheduling of awaited task if it is already running.
