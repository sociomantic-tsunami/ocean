### The Formatter now pretty-print enums

`enum` members are now correctly printed by the Formatter.
For example `enum Foo { A, B}` will print either `Foo.A` or `Foo.B`
instead of `0` and `1`, previously.
If a value that is not a member of an `enum` is casted to it,
such as `cast(Foo) 42`, the Formatter will print `cast(Foo) 42`.
Note that the type will be printed qualified, e.g. passing a `const`
value will print `const(Foo).A`, for example.
