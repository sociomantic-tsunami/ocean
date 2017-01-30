* `ocean.task.ThrottledTaskPool`

  Default throttler implementation, `PoolThrottler`, is now a public class
  residing in the same module. It can be derived from to adjust some of
  throttling behaviour without rewriting it completely.

  `ThrottledTaskPool` itself has got a new constructor overload (zero-argument)
  and new public `useThrottler` method which allows to set throttler instance
  after construction. This was added to solve soft circular dependency between
  construction of the pool and the throttler in case when default throttler is
  inherited from:

  ```D
  auto pool = new ThrottledTaskPool;
  auto throttler = new PoolThrottler(pool, 10, 100);
  pool.useThrottler(throttler);
  ```
