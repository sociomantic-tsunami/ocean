* `ocean.util.app.ext.SignalExt`

  Instead of `SignalEvent` (based on `signalfd`), `SignalExt` is now installing
  regular signal handlers and relies on the regular signal dispatch mechanism
  in combination with self-pipe trick used for epoll callback synchronisation.
  This allows better behaviour with gdb, since the signals are no longer blocked
  and caught with `signalfd`.
