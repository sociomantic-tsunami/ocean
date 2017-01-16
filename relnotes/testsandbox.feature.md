* `ocean.util.test.DirectorySandbox`

  The new module `DirectorySandbox` contains a class utility to create a
  temporary sandbox directory, cd into it, create directory structure inside it,
  remove it and cd back to the previous directory. This is very useful for
  writing tests that require specific directory structure to be run, like the
  tests running DaemonApp, for example.

