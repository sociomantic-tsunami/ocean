* `ocean.util.log.Config`

  This module will no longer clear all appenders of `Log.root` on module construction.
  User code needing to do so can manually call `Log.root.clear()` where needed.
