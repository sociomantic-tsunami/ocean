## Template to recursively check if type contains dynamic arrays

`ocean.meta.traits.Indirectons`

New `containsDynamicArray` template is implemented on top of generic
`ReduceType` facility and provides a more reliable and robust way to detect that
a given type transitively contains some dynamic array.

```D
static struct S
{
  struct Arr { int[] x; }
  Arr[3][4] arr;
}

static assert(containsDynamicArray!(S2));
```
