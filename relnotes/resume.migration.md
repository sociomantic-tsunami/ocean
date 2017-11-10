## Disallow direct resume in termination hooks

It is now necessary to use `IScheduler.delayedResume` method if one task has to
be resumed as a result of termination of another task. Attempting direct resume
will result in a `SanityException` being thrown.

All ocean facilities have been already adjusted to switch accordingly (for
example, `await`), but please pay attention to adjusting application code that
does the same.
