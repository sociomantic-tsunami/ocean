### CliApp now supports TaskExt

Similar to `DaemonApp`, if `settings.use_task_ext` is set to `true` in the
application constructor, task extension will try to automatically initialize
the scheduler and start `run` method within a task:

```D
class TestApp : CliApp
{
    this ( )
    {
        CliApp.OptionalSettings settings;
        // enable task extension:
        settings.use_task_ext = true;
        // provide scheduler configuration:
        settings.scheduler_config.worker_fiber_limit = 42;
        super("name", "desc", VersionInfo.init, settings);
    }

    override int run ( Arguments args )
    {
        // following is guaranteed to always pass:
        test(Task.getThis() !is null);
        test(isSchedulerUsed());
    }
}
```
