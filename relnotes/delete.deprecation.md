# Deprecation of `AppenBuffer.deleteContent`

`ocean.util.container.AppenBuffer`

`deleteContent` method does nothing but force-deleting memory owned by GC and
thus is both unnecessary and potentially dangerous.
