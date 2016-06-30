Description
===========

Ocean is a general purpose library, compatible with both D1 and D2, with a focus
on supporting the development of high-performance, real-time applications. This
focus has led to several noteworthy design choices:

* **Ocean is not cross-platform.** The only supported platform is Linux.
* **Ocean assumes a single-threaded environment.** Fiber-based multi-tasking is
  favoured, internally.
* **Ocean aims to minimise use of the D garbage collector.** GC collect cycles
  can be very disruptive to real-time applications, so Ocean favours a model of
  allocating resources once then reusing them, wherever possible.

Ocean began life as an extension of `Tango
<http://www.dsource.org/projects/tango>`_, some elements of which were
eventually merged into Ocean.

Releases
========

`Latest release notes
<https://github.com/sociomantic/ocean/releases/latest>`_ | `Current, in
development, release notes
<https://github.com/sociomantic/ocean/blob/master/RELEASE_NOTES.md>`_ | `All
releases <https://github.com/sociomantic/ocean/releases>`_

Ocean's release process is based on `SemVer
<https://github.com/sociomantic/ocean/blob/master/VERSIONING.rst>`_. This means
that the major version is increased for breaking changes, the minor version is
increased for feature releases, and the patch version is increased for bug fixes
that don't cause breaking changes.

Any major version branch is maintained for 6 months from the point when the
first release from the next major version branch happens. For example, the
*v2.x.x* branch will get new features and bug fixes for 3 months starting with
the release of *v3.0.0* and will then be dropped out of support.

