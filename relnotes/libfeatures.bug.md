### Missing versions added to `ocean.LibFeatures`

* `ocean.LibFeatures`

This module was supposed to provide means for library writers depending
on Ocean to conditionally support a feature. However the module hasn't been
updated for a long time, and versions `4.2` to `4.8` were missing in the `v4`
suite, while no `v5` version (so `5.0` - `5.3`) were present.
This release adds all the missing features as well as the current (`5.4`).
