* `ocean.net.server.connection.TaskConnectionHandler`

  A `TaskConnectionHandler` is a server connection handler, to be used with the
  `SelectListener`, which runs the abstract `handle` method in a task. This
  requires using `theScheduler` from `ocean.task.Scheduler`.
  Caution: While there are unit tests for `TaskConnectionHandler` it hasn't been
  thoroughly tested for performance in a production environment yet.

* `ocean.net.http.TaskHttpConnectionHandler`

  `TaskHttpConnectionHandler` works like `HttpConnectionHandler` but runs the
  request handler in a task. This requires using `theScheduler` from
  `ocean.task.Scheduler`.
  Caution: While there are unit tests for `TaskHttpConnectionHandler` it hasn't
  been thoroughly tested for performance in a production environment yet.
