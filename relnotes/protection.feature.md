* `ocean.io.device.Device`

  `Device.reopen` was marked as `protected` but used from other modules/classes
  too. Corrected to `public`, though direct usage outside of ocean is
  discouraged.

* `ocean.util.serialize.model.VersionDecoratorMixins`

  `convert` method of matching mixin was marked as private but used from other
  modules. Corrected to `public`, though direct usage outside of ocean is
  discouraged.

* `ocean.text.Util`

  `PatternFruct` struct was marked as `private` but used from other modules.
  Corrected to `public`.

* `ocean.util.container.map.model.BucketSet`

  `Bucket` alias was marked as `protected` but used from other modules/classes
  too. Corrected to `public`.

* `ocean.util.container.cache.model.Value`

  `Value` and `ValueRef` aliases were marked as `private` but used from from
  other modules. Corrected to `public`.

* `ocean.sys.SignalFD`

  `SignalErrnoException` definition is now `public` so that it can be caught or
  extended in any other module.
