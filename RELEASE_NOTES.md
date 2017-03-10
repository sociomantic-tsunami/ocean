Dependencies
============

Dependency                   | Version
-----------------------------|-----------
makd                         | v1.3.x
libtangort-dmd-dev (for D1)  | v1.6.0
dmd-transitional   (for D2)  | 2.070.2.s10 or 2.071.2.s1

New Release Notes Procedure (from v2.6.0)
=========================================

Instead of each change being noted in this file (and the subsequent conflict
hell), in release v2.6.0, we're trying a new approach:

* Release notes will be added to individual files, one (or more) per pull
  request.

* Release notes files will be collected in the `relnotes` folder of this repo.

* The files should be named as follows: `<name>.<change-type>.md`:
  - `<name>` can be whatever you want, but should indicate the change made.
  - `<change-type>` is one of `migration`, `feature`, `deprecation`.
  - e.g. `add-suspendable-throttler.feature.md`,
    `change-epoll-selector.migration.md`.

* If a subsequent commit needs to modify previously added release notes, the PR
  can simply edit the corresponding release notes file.

* When the release is ready, the notes from all the files will be collated into
  the final release notes document and the release notes folder cleared.

* In order to make the process of collating all the notes of a release easier,
  everyone is expected to add their notes in the same format. This format is
  exactly like before, shown below for convenience:
  ```
  * `name.of.affected.module` [, `name.of.another.affected.module`]

    One or more lines describing the changes made. Each of these description
    lines should be at most 80 characters long and should be indented to the
    level of the bullet above.
  ```
