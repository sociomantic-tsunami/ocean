* `ocean.util.app.ext.SignalExt`

  `SignalExt` was previously exposing its internal `SignalEvent` member via
  `event()` method, so its `ISelectClient` part can be registered with `epoll`.
  Returning `SelectEvent` for this purpose is an overkill, as that doesn't
  allow changing the internal structure of the `SignalExt` to use some other
  mechanism to communicate with epoll. Instead, `SignalExt.selectClient()`
  method should be used.
