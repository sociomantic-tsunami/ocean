### Register version.log with the ReopenableFilesExt

* `ocean.util.app.ext.VersionArgsExt`

  The `version.log` is now registered with the `ReopenableFilesExt` to avoid
  extra logic in the logrotate when rotating the `version.log` file.
