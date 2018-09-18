### Usage of `Task.continueAfterThrow` is not needed anymore

`ocean.task.Task.continueAfterThrow` method has been deprecated and is now
implemented as no-op. Calls to this method can simply be removed; the required
cleanup behaviour is now handled automatically by the scheduler. (A task that
rethrows an unhandled exception to the caller will now be automatically resumed
by the scheduler for cleanup, using the delayedResume functionality.)

In rare cases when tasks are used without scheduler, caller must resume task
directly instead of calling `continueAfterThrow`.
