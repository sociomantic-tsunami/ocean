# Removed legacy template arguments in Logger's configuration module

* `ocean.util.log.Config : setupLoggerLevel, configureLogger`

Those functions used to take a `LoggerT` template parameter to signify which logger to configure.
As the old logger implementation is now removed, this parameter is now gone.
No disturbance is expected in user's code, as it's unlikely that those parameter were provided explicitly,
since the template parameter was tied to one of the runtime parameter.
