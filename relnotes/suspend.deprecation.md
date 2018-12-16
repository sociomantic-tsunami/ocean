### Deprecation of `suspend_queue` configuration

Thanks to changes in scheduler/epoll internals, there is now no limit for how
many tasks can be temporarily suspended via `theScheduler.processEvents()` or
`theScheduler.delayedResume(task)`. Because of that old configuration values
for these limits have been deprecated.
