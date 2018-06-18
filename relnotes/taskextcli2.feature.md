### DaemonApp now supports scheduler defaults for TaskExt

Similar to just added `TaskExt` support in `CliApp`:

```D
class TestApp : DaemonApp
{
    this ( )
    {
        DaemonApp.OptionalSettings settings;
        settings.use_task_ext = true;
        // any scheduler configuration supplied here will be used inside
        // TaskExt unless overriden via config file
        settings.scheduler_config.worker_fiber_limit = 42;
        super("name", "desc", VersionInfo.init, settings);
    }
}
```
