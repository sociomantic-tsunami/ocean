* `ocean.util.log.Logger`

  This new module features a `Logger` implementation, similar to the one in `ocean.util.log.Log`,
  the main advantage being its usage of `ocean.text.convert.Formatter` over `ocean.text.convert.Format`.
  This means this `Logger` will be able to log `Typedef` in D2, to log `struct` and all types
  supported by the `Formatter`.

  The difference between the `Logger` and `Log` modules should be minimal, mostly related
  to the formatting primitive (`Logger.{trace,info,warn,error,fatal}`) being templated functions
  in the new implementation vs functions with variadic arguments in the old.

  In order to make the migration as painless as possible, the `Logger` module reuses the same names
  as the `Log` module, which means most code will only need to change their import to switch to
  the new implementation, by e.g. running :
  > find src -name "*.d" -print0 | xargs -0 -n50 sed -i 's/ocean\.\util\.log\.Log/ocean.util.log.Logger/g'

  from a project's top level directory.

  The app framework will automatically configure the new logger as it configures the old logger.
  See release notes for `ocean.util.log.Config` for more details.
