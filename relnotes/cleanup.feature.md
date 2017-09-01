* `ocean.util.app.ext.SignalExt`

  Now instead of empty default implementation, the one that catches `SIGTERM`
  and tries shutting down scheduler/epoll system is used. It should result in
  same observable behaviour but with runtime finalizers being run. Applications
  that already implement their own `onSignal` don't need to do anything either
  (not even call `super.onSignal`).
