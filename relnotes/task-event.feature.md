`ocean.task.util.Event`

  A new module was added that provides the `TaskEvent` struct. It mimicks the 
  behaviour of the deprecated `FiberSelectEvent` class, allowing you to 
  call `wait`/`trigger` in an arbitrary order instead of having to manually 
  keep track of `suspend`/`resume`.
