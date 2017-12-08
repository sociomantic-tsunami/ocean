## Built-in task and scheduler support in DaemonApp

`ocean.util.app.DaemonApp` `ocean.util.app.ext.TaskExt`

It is now possible to make `DaemonApp` initialize scheduler automatically using
standard app configuration file. To do so, it is sufficient to enable it via
`DaemonApp` optional settings:

```D
class MyApp : DaemonApp
{
  this ( )
  {
    DaemonApp.OptionalSettings settings;
    settings.use_task_ext = true;
    super("name", "desc", VersionInfo.init, settings);
  }
```

This extension is disabled by default to avoid clashing with existing
application code which is already handling scheduler initialization in some way.

If `TaskExt` is enabled, overriden `run` method will be called within a task
context and there is no need to create one manually or start scheduler event
loop:

```D
class MyApp : DaemonApp
{
  this ( )
  {
    DaemonApp.OptionalSettings settings;
    settings.use_task_ext = true;
    super("name", "desc", VersionInfo.init, settings);
  }

  override int run ( Arguments args, ConfigParser config )
  {
    assert(Task.getThis() !is null);
    assert(isSchedulerUsed());

    scope (exit)
    {
      // Must be called in this case, registered DaemonApp events won't let
      // event loop exit on its own:
      theScheduler.epoll.shutdown();
      // Most real-world daemon applications have different condition for
      // terminating (for example, handling the signal) and won't need such
      // `scope(exit)` statement.
    }

    return 0;
  }
```

NB: using `TaskExt` results in `startEventHandling` being called automatically,
    do not call it again from the `run` method!

Expected configuration file format matches `SchedulerConfiguration` struct
fields (all field are optional, defaults will be used if not defined):

```
[SCHEDULER]
worker_fiber_stack_size = 102400
worker_fiber_limit = 5
task_queue_limit = 10
suspended_task_limit = 16
specialized_pools =
    pkg.mod.MyTask:1024
    pkg.mod.MyOtherTask:2048
```
