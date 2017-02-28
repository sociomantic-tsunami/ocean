* `ocean.task.Scheduler`

  New method, `Scheduler.await` allows to schedule execution of any task object
  and suspend caller until that execution finishes completely, either naturally
  or because spawned task got killed.

  Additionally, one may provide optional delegate argument to `await` call so
  that it will be called after awaited task finishes but before it gets
  recycled. That allows to copy any required data from the task.

  Finally, simple convenience wrapper `awaitResult` makes possible to wait on a
  task and get its result in a single line if it fits the convention that its
  result is a simple value type stored in a public field named `result`.

  ```D
  class ExampleTask : Task
  {
      int result; // must have public value-type field named 'result'

      override void run ( )
      {
          // do things that may result in suspending ...
          this.result = 42;
      }

      override void recycle ( )
      {
          this.result = 43;
      }
  }

  auto data = theScheduler.awaitResult(new ExampleTask);
  test!("==")(data, 42);
  ```

  For more examples check new method documentation/tests.
