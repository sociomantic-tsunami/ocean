### Fix `-=` operator implementation in SuspendableThrottlerCount

`ocean.io.model.SuspendableThrottlerCount`

The `-=` operator overload (D1 `opSubAssign`) was inexplicably aliased
to the `add` method rather than the correct `remove`.  This probably
means that no one was ever actually using the operator overload, but it
seems a good idea to fix it in any case.
