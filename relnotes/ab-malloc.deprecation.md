## Malloc-based AppendBuffer implementation is broken

It was found to both leak memory and fail basic set of tests. Deprecated with a
recommendation to switch to tested GC-based version.
