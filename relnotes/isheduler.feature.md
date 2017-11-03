## Split of the scheduler into the interface and an implementation

`ocean.task.IScheduler`

New module defining all basic data types needed to interact with the scheduler
API. It is recommended that only modules that need to configure the scheduler
would import original `ocean.task.Scheduler` and all others should switch to
new light-weight one.

`ocean.task.IScheduler.theScheduler` will return the very same global
scheduler reference but upcast to `IScheduler` interface.
