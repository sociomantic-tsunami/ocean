## The `-p` option for the unittest runner can't be used as a wildcard any more

`core.UnitTestRunner`

There is a minor breaking bug fix in the `--package` / `-p` option; now it can't be used as some sort of wildcard.

The `PKG` argument will only match fully qualified names that start with `PKG.` or the exact module `PKG`. Before using `PKG` as argument would have matched `PKG*`, so `PKGfoo` was also a match.

As a transitional step, `PKG.` will also be accepted as a package specification, although it will match both `PKG` (exact match) and `PKG.*`.
