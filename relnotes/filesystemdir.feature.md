* `ocean.io.select.client.FileSystemEvent`

  `FileSystemEvent`'s constructor and `setHandler` now accepts
  `FileSystemEvent.Notifier` which accepts `SmartUnion` of structs
  `(path, events)` or `(path, name, events)` where the later member is
  used when the changes are performed on the files inside monitored directory,
  where the `name` will be the name of the file that triggered this event.
