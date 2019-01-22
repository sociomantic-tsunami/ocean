### Possible to get fiber stats for specialized pools

New method in `IScheduler` API - `getSpecializedPoolStats`:

```D
    SchedulerConfiguration config;
    with (config)
    {
        specialized_pools = [
            PoolDescription("SomeTask", 10240)
        ];
    }
    initScheduler(config);

    // returns stats struct wrapped in `Optional`:
    auto stats = theScheduler.getSpecializedPoolStats("NonExistent");
    test(!stats.isDefined());

    stats = theScheduler.getSpecializedPoolStats("SomeTask");
    stats.visit(
      ( ) { /* not defined */ },
      (ref SpecializedPoolStats s) {
        Stdout.formatln("{} {}", s.free_fibers, s.used_fibers);
      }
    );
```
