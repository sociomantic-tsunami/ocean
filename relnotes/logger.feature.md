### `Logger.runtime()` now uses `Clock.startTime()`

* `ocean.util.log.Logger`

The `Logger` now uses `Clock.startTime()` instead of the hierarchy instantiation time.
This means that all hierarchy will have the same `runtime`.
In practice, programs only ever had one hierarchy,
and since the common usage is to instantiate `Logger`s from the module constructor,
the `runtime()` was almost always that of the program, save for a few milliseconds.
