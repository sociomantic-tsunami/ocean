### Fix `await` interaction with specialized task pools

Previosuly all `await` family functions used unconditional `theScheduler.queue`
call internally which adds the task to default worker fiber pool queue.

With specialized worker fiber pools, however, it would result in awaited task
surprisingly being queued using default pool instead of specialized one for that
task:

```D
SchedulerConfiguration config;
with (config)
{
    specialized_pools = [
        PoolDescription(Task1.classinfo.name, 10240)
    ];
}

// ...

theScheduler.await(new Task1); // NOT scheduled using Task1 dedicated pool!
```

This was fixed by enhancing Scheduler implementation to use `schedule`
internally which results in the expected behaviour.
