## Slight change in usage of `MultiVersionDecorator.store`

`ocean.util.serialize.contiguous.MultiVersionDecorator`

`store` method doesn't work with explicit template argument anymore. Simply
removing it and relying on template inference should be sufficient to fix
compilation errors.

Previously it was possible (but not necessary) to explicitly specify serialized
struct type as a template argument. Sadly, it was not possible to keep this
behaviour while introducing additional overloads of `store`.
