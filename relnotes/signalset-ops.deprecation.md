### Deprecate D1 operator overloads in `SignalSet`

DMD 2.088.0 has deprecated D1 operator overloads, which are expected to
be replaced with the newer D2 `op{Unary,Binary,BinaryRight,OpAssign}`
templated methods: <https://dlang.org/changelog/2.088.0.html#dep_d1_ops>

The D1 operator overloads in `SignalSet` are used in a rather weird way
which does not really seem appropriate to use for insertion and removal
from a set.  Rather than replace them with D2 operator overloads, they
have simply been deprecated in favour of using the existing `add` and
`remove` methods directly.  Support for the operator overloads will be
dropped in the next major release of ocean.
