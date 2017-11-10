## New default scheduler exception handler in tests

Previously, default exception handler in the scheduler was simply rethrowing any
exception (in both test builds and actual builds). This was most backwards
compatible behaviour but with an unfortunate effect that unexpected exceptions
in tests could be lost and were hard to debug in general.

For `version (UnitTest)` the new default exception handler is defined to:

  1) Print exception information
  2) Call C `abort` to terminate the process immediately

If some test requires old behaviour, it can be trivially restored like this:

```D
import ocean.task.Scheduler;

theScheduler.exception_handler = (Task t, Exception e) {
    throw e;
};
```
