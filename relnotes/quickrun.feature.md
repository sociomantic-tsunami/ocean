### Helper to quickly spawn a task for scripting

* `ocean.task.util.QuickRun`

Utility intended for script-like usage:

```D
  int main ( )
  {
    initScheduler(SchedulerConfiguration.init);

    return quickRun({
      // use task-blocking functions:
      Dht.connect(10_000);
      Dht.put("channel", 23, "value");
      return 0;
    });
  }
```

It turns delegate argument into a task and runs it through scheduler. Starts the
event loop automatically and will finish only when all tasks finish and no
registered events remain (or `theScheduler.shutdown` is called).
