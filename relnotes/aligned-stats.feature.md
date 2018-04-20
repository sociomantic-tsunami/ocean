### Stats timer is now triggered at a predictable moment

`ocean.util.app.DaemonApp`

In order to help with multiple instance apps, or similar apps needing to compare their stats,
the initial call to `onStatsTimer` will not be dependent on when the application was started anymore,
but will be aligned on the interval provided.
For example, if an application starts at 12:00:04 with an interval of 30 (the default),
the first call to `onStatsTimer` will happen at 12:00:30 instead of 12:00:34 (currently).
