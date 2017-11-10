## New utility to forge zero-allocation closures with one argument

`ocean.core.TypeConvert`

New `toContextDg` function takes one plain static function as template argument
and one `void*` runtime argument, returning forged delegate which calls that
function with provided context:

```D
static void handler ( void* context )
{
    test!("==")(cast(size_t) context, 42);
}

void delegate() dg = toContextDg!(handler)(cast(void*) 42);
dg();
```

This utility is intended for advanced performance optimization. It is not
recommended for casual usage.
