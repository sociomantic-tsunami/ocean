### Add utility to wrap task as `ISuspendable`

* `ocean.task.util.TaskSuspender`

New small utility that accepts task instance via constructor and implements
`resume` method via `theScheduler.delayedResume` of underlying task instance.
Makes possible to use tasks as suspendables without violating scheduler
requirements of not resuming one task via another directly.

```D
auto generator = new GeneratorTask;
auto stream_processor = new StreamProcessor!(ProcessingTask);
stream_processor.addStream(new TaskSuspender(generator));
```
