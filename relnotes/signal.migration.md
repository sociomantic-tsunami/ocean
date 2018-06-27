### DaemonApp doesn't append SIGTERM to signal list

Previously `DaemonApp` would append `SIGTERM` to handled signal
list even if there is already an app-defined one. It was a bug - automatic
handling of `SIGTERM` was only intended to happen if there is no custom
signal handling defined in derived application.

Starting with 5.0.0 `DaemonApp` will behave as originally intended - if your
application was relying on old behaviour, make sure to add `SIGTERM` to signal
list explicitly now.
