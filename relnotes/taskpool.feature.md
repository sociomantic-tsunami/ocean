### Change of `StreamProcessor`, `TaskPool` and `ThrottledTaskPool` internals

Also affects `StreamProcessor` as it uses `ThrottledTaskPool` internally.

Both `TaskPool` and `ThrottledTaskPool` stopped defining internal private
`OwnedTask` to wrap user-supplied type in. Instead, regular termination hook
infrastructure is used.

Both also don't try to catch and rethrow exceptions arising from a task. This is
not needed because recycling is already done by the termination hook system.

Overall, only expected observable impact is fixed interaction between
specialized worker fiber pools and `TaskPool`. However, because of how different
internal logic is now, it is highly recommended to carefully test applications
when upgrading.
