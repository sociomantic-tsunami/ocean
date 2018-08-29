### Separate lifetime for empty records of ExpiringCache

`ocean.util.container.cache.ExpiringCache`

Now supports extra optional constructor argument - lifetime used for empty
cached records. If not specified, regular lifetime value will be used, same as
before.

ExpiringCache considers a cached record with array length 0 as being "empty".

This feature is intended for applications caching failures as empty values so
that shorter expiration can be used for those.
