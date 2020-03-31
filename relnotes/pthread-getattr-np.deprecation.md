### Exposed declaration of `pthread_getattr_np` had been deprecated

* `ocean.util.aio.internal.ThreadWorker`

This module inadvertently exposed the `extern (C)` declaration for the
non-standard function `pthread_getattr_np`.
Users can import `core.thread` instead to get the declaration.
