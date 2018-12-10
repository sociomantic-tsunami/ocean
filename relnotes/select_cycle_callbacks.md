### Select cycle callbacks

Select cycle callbacks are delegates that are
executed once the select cycle has finished
(i.e. all available events reported by
`epoll_wait` are processed).

These "one-shot" callbacks are stored in a queue,
and have to be registered each time from new (e.g.
if a certain callback should be executed after
each select cycle it can reregister itself).

Note that the select cycle (i.e. `epoll_wait`) doesn't
block as long as the callback queue is not empty –
that implies, use them with care.
