* `ocean.util.container.BTreeMap`

  `BTreeMap` now provides `opIn` to get the pointer to the stored
  value based on key.

* `ocean.util.container.BTreeMap`

  `BTreeMap` now provides overload of `insert` which returns the pointer
  to the either existing or new value and passes the information if the
  insertion has been successful via out parameter. This is handy if the
  user needs a stored pointed immediately after inserting it into the
  tree (it saves one lookup per insert).
