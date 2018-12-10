### Wrapper for dynamic array with IQueue interface

`ocean.util.container.queue.DynamicQueue`

New module that wraps common pattern of using a dynamic array to imitate
infinitely growing queue. `push` is implemented as appending to the backing
array and `pop` as fetching elements from the beginning.

```D
  auto queue = new DynamicQueue!(int);
  queue.push(1);
  queue.push(2);
  test!("==")(*queue.pop(), 1);
  test!("==")(*queue.pop(), 2);
```
