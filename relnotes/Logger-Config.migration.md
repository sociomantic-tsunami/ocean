## Removed legacy template arguments in Logger's configuration module

`ocean.util.log.Config : setupLoggerLevel, configureLogger`

Those functions used to take a `LoggerT` template parameter to signify which logger to configure.
As the old logger implementation is now removed, this parameter is now gone.
No disturbance is expected in user's code, as it's unlikely that those parameter were provided explicitly,
since the template parameter was tied to one of the runtime parameter.

## Config-based default for console_layout and file_layout

`ocean.util.log.Config : Config.{console_layout,file_layout}, configureLoggers`

`configureLoggers` would previously use `LayoutDate` as the default `Layout` for the file appender,
and `LayoutSimple` for the default `Layout` for the console.
The default would be used whenever the Logger's `Config.{console_layout,file_layout}` were empty/null.
Instead of relying on this, those field now have a default value of "date" and "simple", respectively,
while will be used by "makeLayout" to instantiate the same default layout.
The only change to users is that setting a null / empty value for those fields is now an error.
