* `ocean.task.Scheduler`

  New method, `Scheduler.await` allows to schedule execution of any task object
  and suspend caller until that execution finishes completely, either naturally
  or because spawned task got killed.
