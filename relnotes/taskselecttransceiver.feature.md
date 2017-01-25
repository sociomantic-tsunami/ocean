* `ocean.io.select.protocol.task.TaskSelectTransceiver`

  `TaskSelectTransceiver` manages non-blocking I/O done in a task. It is a
  replacement for both `FiberSelectReader` and `FiberSelectWriter`, combining
  their read/write functionality.
  `TaskSelectTransceiver` works with any non-blocking POSIX I/O device that is
  wrapped in the `IODevice` class in `ocean.io.device.IODevice`. The `read*` and
  `write` methods of `TaskSelectTransceiver` need to be called in a running
  task. To wait for the I/O device to become ready `TaskSelectTransceiver` uses
  `TaskSelectClient` below to suspend the currently running task and resume it
  when the `EPOLLIN` "ready for reading", `EPOLLOUT` "ready for writing" event,
  an error or a timeout has occurred for the I/O device.
  `TaskSelectTransceiver` uses buffered input: It contains an input buffer and
  the logic to manage it. It does, however, not contain an output buffer and
  leaves output buffering to the OS environment. For the most common use case
  where the I/O device is a TCP socket `TaskSelectTransceiver` supports an
  output buffering feature built into Linux called TCP Cork. If and only if the
  file descriptor of the I/O device refers to a TCP socket then
  `TaskSelectTransceiver.write` automatically enables output buffering through
  TCP Cork. In this case calling `TaskSelectTransceiver.flush` flushes the
  output data buffer and writes all pending output data immediately.
  
* `ocean.io.select.protocol.task.TaskSelectClient`

  `TaskSelectClient` is used to suspend the currently running task to wait for
  an epoll event to occur for an I/O device. The I/O device is represented by a
  file descriptor through the `ISelectable` interface.
  `TaskSelectClient.wait` registers the I/O device with epoll using the epoll
  facility built into the task scheduler, then suspends the task; the event
  handler callback finally resumes the task. The task is also resumed if epoll
  wait timeouts are enabled and the I/O device timed out;
  `TaskSelectClient.wait` throws a `TimeoutException` then.
  An I/O device that is used with a `TaskSelectClient` should not be registered
  with or unregistered from epoll outside that `TaskSelectClient` instance.
