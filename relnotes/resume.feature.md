## New method to resume a task after the event loop cycle

`ocean.task.IScheduler`

`IScheduler` interface defines new method, `delayedResume`, which takes one task
and adds it to the resume queue. That means that such task will be resumed by
the scheduler after current epoll cycle instead of immediate resuming by the
current context.

```D
// will be resumed later:
theScheduler.delayedResume(some_task);
```
