## Changes in --version flag handling and version log

`VersionArgsExt` used in both `CliApp` and `DaemonApp` now implements
`--version` flag to only print basic version information, without any detailed
build description.

Instead, new `--build-info` flag is introduced that prints all detailed
information that used to be present in old `--version` output. However, format
of that output was changed to use plain `key=value` pairs, one per each line. It
also doesn't treat any keys specially, printing all data found in the supplied
`VersionInfo`.

Old output:

```
$ ./app --version
app version v1.0 (compiled by 'author' on today with dmd1 using lib1:v10.0 lib2:v0.5)
```

New output:

```
$ ./app --version
app version v1.0
$ ./app --build-info
app version v1.0
build_author=author
build_date=today
compiler=dmd1
lib_lib1=v10.0
lib_lib2=v0.5
```

Information logged to `version.log` will match the one printed by `--build-info`
but will use comma-separated `key=value` pairs instead of multi-line.
