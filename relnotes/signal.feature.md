### ReopenableFilesExt can be configured to not register signal handler

`ocean.util.app.ext.ReopenableFilesExt`

If `reopen_signal` constructor argument is set to `0`, it will result in no
signal handler being registered. This is new feature intended for applications
that implement log rotation support through other means (like UNIX socket).

`reopen_signal` is most commonly set indirectly via `DaemonApp` configuration:

```D
class MyApp : DaemonApp
{
    this ( )
    {
       DaemonApp.OptionalSettings settings;
       settings.reopen_signal = 0;
       super("name", "description", versionInfo, settings);
    }
}
```
