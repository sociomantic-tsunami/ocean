### Replace D1 operator overloads with D2 operator overloads

`ocean.io.model.SuspendableThrottlerCount`

DMD 2.088.0 has deprecated D1 operator overloads, which are expected to
be replaced with the newer D2 `op{Unary,Binary,BinaryRight,OpAssign}`
templated methods: <https://dlang.org/changelog/2.088.0.html#dep_d1_ops>

Since templated methods cannot be overridden this may in some rare cases
cause breaking change for classes that implemented the old operators.
In general however this will likely make no practical difference, other
than the absence of scores of deprecation messages with more recent DMD
versions.
