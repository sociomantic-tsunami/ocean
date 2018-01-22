## Deprecation of `AppendBuffer.deleteContent`

`ocean.util.container.AppendBuffer`

`deleteContent` method does nothing but force-deleting memory owned by GC and
thus is both unnecessary and potentially dangerous.
