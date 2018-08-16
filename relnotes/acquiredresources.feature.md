### Helpers for auto-relinquishing shared resources used by an execution context

`ocean.util.container.pool.AcquiredResources`

Helper structs for a specific execution context (e.g. a `Task` or connection
handler) to acquire and relinquish resources from a shared pool.

Several utilities are provided in this module, all of which build on top of
`FreeList`:
    * `Acquired`: Tracks instances of a specific type acquired from the
        shared resources and automatically relinquishes them when the
        execution context exits.
    * `AcquiredArraysOf`: Tracks arrays of a specific type acquired from the
        shared resources and automatically relinquishes them when the
        execution context exits.
    * `AcquiredSingleton`: Tracks a singleton instance acquired from the
        shared resources and automatically relinquishes it when the execution
        context exits.

For more details on how to set up a global shared resources container and a
class to track the resources that have been acquired by a specific execution
context, see the module header documentation.

The module contains detailed usage examples. For the most common use case --
acquiring and reliniquishing arrays from a pool -- see the usage example of
`AcquiredArraysOf`.

