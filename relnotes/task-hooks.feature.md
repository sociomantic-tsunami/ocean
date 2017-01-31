* `ocean.task.Task`

  New `terminationHook` and `removeTerminationHook` method of `Task` base class
  replace previous `registerOnKillHook` and `unregisterOnKillHook` ones, but
  will be called after any task termination, not just the `kill` call.

  It is illegal to (un)register new hooks within the execution of existing ones
  and may result in undefined behaviour. Task scheduler will try to detect and
  assert on it.
