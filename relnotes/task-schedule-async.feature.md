* `ocean.task.Scheduler`

  New `theScheduler.queue` method is similar to `theScheduler.schedule`, but
  starts the task in the next event loop cycle by forcing task addition to the
  queue even if there are worker fibers available for immediate execution.
  Mostly useful for implementation of advanced library utils.

  As part of implementing this feature, `theScheduler` will now resume any tasks
  from the queue during select cycle hooks if there are free worker fibers
  available at that point of time.
