* `ocean.core.SmartUnion`

  A helper function template, `callWithActive`, has been added to the
  smart-union module. This function allows a user-specified function to be
  called with the currently active field of a smart-union. This is useful, for
  example, for logging information about the currently active field, without
  having to long-hand write out a switch statement for all possibilities.
