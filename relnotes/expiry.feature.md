## Allow timer events to be disabled from the callbacks of other timer events

`ocean.time.timeout.model.ExpiryRegistrationBase`

New method, `drop`, provides same functionality as `unregister`, but also
removes the expiry from current list of fired events if it was present there.
This makes it possible to disable timer events from the timeout callbacks of
other timer events.
