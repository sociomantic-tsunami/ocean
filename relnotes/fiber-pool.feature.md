## Dedicated fiber pools for tasks of specific type

`ocean.task.Scheduler`

It is now possible to define dedicated worker fiber pools to process tasks of
specific type:

```D
SchedulerConfiguration config;

with (config)
{
specialized_pools = [
  PoolDescription(MyTask.classinfo, 10240),
  PoolDescription(MyOtherTask.classinfo, 2048),
];
}

initScheduler(config);

// will be processed immediately in own worker fiber pool, skipping the queue:
theScheduler.schedule(new MyTask);
```

Such functionality is intended to be used when there are some task types that
need real-time handling and thus can't afford waiting in the queue.  It can
also be used for the case where some very long-lived tasks would occupy worker
fibers from the shared pool forever, if processed normally

Note that this functionality can be used side by side with regular scheduling
queue with no issues - each task will be handled by own sub-system depending
on its `ClassInfo`.
