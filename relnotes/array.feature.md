### Non-allocating replacement for declaring array literals.

* `ocean.core.Array`

  Add a new helper function `fill()` to assign all the elements of an array.
  The function is an alternative for declaring an array literal, which is
  known to allocate GC memory. (`fill()` also checks that the length of the
  array matches the number of variadic arguments.)

  A couple of examples without this functionality:

  ```D
  int[4] mem_array = [0, 1, 2, 3]; // allocates memory in the heap

  int[3] static_array;
  static_array[0] = 0;
  static_array[1] = 1; // Does not allocate memory in the heap but does not
  static_array[2] = 2; // scale well for many elements
  ```

  So the `fill()` functionality helps as follows:

  ```D
  int[3] array;
  array.fill(0, 1, 2); // Does not allocate memory in the heap and scale well
  ```
