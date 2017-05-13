* `ocean.meta`

  New package is intended to eventually replace `ocean.core.Traits` and
  `ocean.core.Tango_traits` modules. It defines similar utilities but in a
  modular way with clear separation in 3 categories - traits, type manipulation
  and code generation helpers. Documentation and tests are improved as part of
  the process too.

  Old `ocean.core` modules are NOT being deprecated for now - it will only
  happen once `ocean.meta` is finished as a full replacement and rest of `ocean`
  is updated to use it.

* `ocean.meta.types.ReduceType`

  New template utility intended to help with defining complex type traits that
  require recursively processing type definition. Its purpose is to avoid
  writing same reflection boilerplate over and over again which has proved to be
  a source of many subtle bugs.

  NB: currently `ReduceType` does not work with types which have recursive
  definition, for example `struct S { S* ptr; }`, crashing compiler at CTFE
  stage. This will be improved in the future.
