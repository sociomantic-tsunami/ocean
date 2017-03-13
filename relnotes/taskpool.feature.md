* `ocean.task.TaskPool`

  A new function `awaitRunningTasks()` has been added. This function suspends
  the current task until all running tasks in the pool have finished executing.

  It is assumed that the current task (i.e. the one being suspended) is not
  itself a task from the pool.
