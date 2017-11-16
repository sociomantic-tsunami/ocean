## Call `awaitOrTimeout` via scheduler interface

Thanks to introducing `IScheduler` interface, it is now possible to call
`awaitOrTimeout` as scheduler member method:

```D
import ocean.task.IScheduler;
theScheduler.awaitOrTimeout(task, timeout);
```

Internally it still does the same call to global function in
`ocean.task.util.Timer`, but new alias allows for slightly more uniform API.

NB: this means that any app using the scheduler is now required to add
`-L-lebtree` to its linker flags.
