`InputStream.read`, `OutputStream.write` et al now take a `scope` argument

* ``

The following method have been modified, so that either their argument is `scope`,
or the delegate they accept takes a `scope` argument (when multiple `scope`s are present,
the change will be highlighted as `*scope*`).

In `ocean.io.model.IConduit`:
- `InputStream.read`: This interface method now takes a `scope void[]`;
- `OutputStream.write`: This interface method now takes a `scope const(void)[]`;
- `InputBuffer.next`: This interface method now takes a `scope size_t delegate (*scope* const(void)[])`;
- `InputBuffer.reader`: This interface method now takes a `scope size_t delegate (*scope* const(void)[])`;
- `OutputBuffer.append`: This interface method now takes a `scope const(void)[]`;
- `OutputBuffer.writer`: This interface method now takes a `scope size_t delegate (*scope* void[])`;

As those are interface methods, the changes have propagated to other classes,
such as `Conduit` and `{Input,Output}Filter`.
