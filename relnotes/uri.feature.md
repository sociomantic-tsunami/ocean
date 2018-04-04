### Buffer support in Uri and better usage example

`ocean.net.Uri`

Previously only usage example was in tests which only promoted usage of `encode` method
which is low-level primitive used to encode individual parts of URI. Most applications
will want to use `produce` instead which encodes full URI with appropriate rules per each
internal part. That method now also supports `Buffer` argument:

```D
auto s_uri = "http://example.net/magic?arg&arg#id";
auto uri = new Uri(s_uri);

test!("==")(uri.scheme, "http");
test!("==")(uri.host, "example.net");
test!("==")(uri.port, Uri.InvalidPort);

Buffer!(char) buffer;
uri.produce(buffer);
test!("==") (buffer[], s_uri);
```
