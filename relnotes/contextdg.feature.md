### toContextDg now supports return values

`ocean.core.TypeConvert.toContextDg`

Enhancement to existing utility function that converts function accepting a
single word size argument into a zero-argument delegate with no allocations. Now
it is possible to use a function with some return value, and resulting delegate
will have the very same return type.
