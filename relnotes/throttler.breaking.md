### Restore `ISuspendable` throttler fix

This change ensures that the suspend state of an ISuspendable instance
when added to the throttler is consistent with the throttler state.

The bug fix was originally introduced in ocean v4.2.10 but got reverted because
it was incompatible with swarm neo implementation.
