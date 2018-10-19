### Tasks do not implement ISuspendable interface anymore

This is a breaking change that may cause compilation errors.

Marking `Task` class as implementing `ISuspendable` was a historical mistake
coming from similarity of methods - and it indeed worked for very simple use
cases. However, tasks are much more restrictive about when exactly it is legal
to call `suspend` and `resume` methods while `ISuspendable` expects both to be
callable at any arbitrary moment.

As a result, trying to use tasks as suspendables has caused several extremely
hard to debug issues and needs to be prohibited. Originally this change was
scheduled for v5.0.0 because it is a breaking one, but negative impact of bugs
occuring because of this mistake has proven to be strong enough to warrant
immediate upgrade effort.

Any affected code has to be adjusted to use raw epoll events (which are
registered on `resume` calls and unregistered on `suspend` calls) instead of a
task.
