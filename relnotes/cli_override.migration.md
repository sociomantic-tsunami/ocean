### Trying to override non-existent config value will error

`ocean.util.app.ext.ConfigExt`

Previously ocean application framework would allow to specify config override
via command-line flag even for non-existent config values. This was reported
as confusing as there is nothing to "override" in such case.

Starting with this ocean release such attempt will result in an error and any
scripts doing it by accident should be adjusted.
