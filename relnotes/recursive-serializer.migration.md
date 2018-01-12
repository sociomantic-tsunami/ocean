## Contiguous (de)serializer does not support recursive types

This struct used to be accepted by serializer but will cause compilation error
with the new ocean:

```D
struct S
{
  S[] x;
}
```

This is unfortunate side effect of making serializer more generic and separating
type analysis from serialization code. As this feature was not used by
Sociomantic projects and new implementation will simplify maintenance, it was
considered a desirable trade-off.
