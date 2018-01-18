## Old rotation-related fields removed from `StatsLog` and `StatsLog.Config`

`ocean.util.log.Stats`, `ocean.util.log.Config`

The `StatsLog.config` and `MetaConfig` fields `max_file_size`, `file_count`, and
`start_compress`, along with the corresponding `default_max_file_size`,
`default_file_count`, and `default_start_compress` (in `StatsLog`) have been
removed. These were remnants of the old internal log rotation support in ocean,
which is long gone. Applications should use the `logrotate` system facility
instead.

