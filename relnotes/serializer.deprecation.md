### Deprecation of contiguous serializer mixins

`ocean.util.serialize.contiguous.model.LoadCopyMixin`
`ocean.util.serialize.model.VersionDecoratorMixins`

Both module are not used as part of serializer/decorator implementation as of
ocean v4.0.0 and now are completely deprecated. All symbols defined there (like
`VersionHandlingException`) can also be found in other serializer/decorator
modules.
