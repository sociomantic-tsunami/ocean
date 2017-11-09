## Reopen files based on unix socket command (e.g. for use in logrotate)

`ocean.util.app.DaemonApp`

`DaemonApp`'s `ReopenableFilesExt` now supports reopening commands from the
UnixSocketExt. If you have the UnixSocketExt bound to the socket, sending
command `reopen_logfile file_path` will reopen the specified file, if
registered, and acknowledge the action with `ACK` or `ERROR` strings (followed
by the file name which failed to reopen in case of `ERROR`).

With this in place, reopening only affected files (vs all open registered files)
with logrotate can be done as follows:

1) use `nosharedscripts` directive, so the post-rotate script is called
   once per file, with the absolute file path passed to it.
2) From the absolute file path, get the log directory and deduce socket
   location from it (application could place the socket in its `run/`
   directory, so the socket path would be
   `SOCKETPATH=$(dirname $LOGPATH)/../application.socket`.
3) Finally, in post-rotate script, simply executing
   `test "$(echo reopen_files $LOGPATH | nc -U $SOCKETPATH)" = ACK` will
   instruct the application to reopen the given logfile and report status
   to logrotate.

Example logrotate file:

```
/srv/dlsnode/log/*.log
{
  rotate 10
  missingok
  notifempty
  delaycompress
  compress
  size 1M
  nosharedscripts
  postrotate
    export SOCKETPATH="$(dirname $1)/../dlsnode.socket"
    test "$(echo reopen_files $1 | nc -U $SOCKETPATH)" = ACK
  endscript
}
```
