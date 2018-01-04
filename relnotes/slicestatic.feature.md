## New D2 migration helper template for static array corner case

`ocean.transition`

New `SliceIfD1StaticArray` template is intended to help with situations when
generic function had to return its templated argument which could turn out to be
a static array. In D1 that would require slicing such argument as returning
static array types is not allowed. In D2, however, static arrays are value types
and such slicing is neither necessary nor memory-safe.

```D
SliceIfD1StaticArray!(T) foo ( T ) ( T input )
{
    return input;
}

foo(42);
foo("abcd"); // wouldn't work if `foo` tried to return just T
```
