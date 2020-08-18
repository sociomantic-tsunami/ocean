Description |TravisCI|_
=======================

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


D2 Compatibility
================

Since v5.0.0_, Ocean is a D2-only library.


Build / Use
===========

Dependencies
------------

This library has quite a number of dependencies, but it depends on which
modules you want to use. Usually the easiest way to find out is just using it
and see which libraries the linker fails to find and then install by demand.

If you want to install everything, then the list is as follows (for an
absolutely up to date list you can take a look at the ``Build.mak`` file, in
the ``$O/%unittests`` target):

* ``-lglib-2.0``
* ``-lpcre``
* ``-lxml2``
* ``-lxslt``
* ``-lebtree``
* ``-lreadline``
* ``-lhistory``
* ``-llzo2``
* ``-lbz2``
* ``-lz``
* ``-ldl``
* ``-lgcrypt``
* ``-lgpg-error``
* ``-lrt``

To install those dependencies on Ubuntu refer to the `apt-get install` command in `docker/build <docker/build#L5>`_.

Please note that ``ebtree`` is not the vanilla upstream version. We created our
own fork of it to be able to write D bindings more easily. You can find the
needed ebtree library in https://github.com/sociomantic-tsunami/ebtree/releases
(look only for the ``v6.0.socioX`` releases, some pre-built Ubuntu packages are
provided).

If you plan to use the provided ``Makefile`` (you need it to convert code to
D2, or to run the tests), you need to also checkout the submodules with ``git
submodule update --init``. This will fetch the `Makd
<https://github.com/sociomantic-tsunami/makd>`_ project in ``submodules/makd``.

Versioning
==========

ocean's versioning follows `Neptune
<https://github.com/sociomantic-tsunami/neptune/blob/v0.x.x/doc/library-user.rst>`_.

This means that the major version is increased for breaking changes, the minor
version is increased for feature releases, and the patch version is increased
for bug fixes that don't cause breaking changes.

Support Guarantees
------------------

* Major branch development period: 6 months
* Maintained minor versions: 2 most recent


Maintained Major Branches
-------------------------

====== ==================== ===============
Major  Initial release date Supported until
====== ==================== ===============
v5.x.x v5.0.0_: 04/04/2019  TBD
====== ==================== ===============
.. _v5.0.0: https://github.com/sociomantic-tsunami/ocean/releases/tag/v5.0.0

Releases
========

`Latest release notes
<https://github.com/sociomantic-tsunami/ocean/releases/latest>`_ | `All
releases <https://github.com/sociomantic-tsunami/ocean/releases>`_

Releases are handled using GitHub releases. The notes associated with a
major or minor github release are designed to help developers to migrate from
one version to another. The changes listed are the steps you need to take to
move from the previous version to the one listed.

The release notes are structured in 3 sections, a **Migration Instructions**,
which are the mandatory steps that users have to do to update to a new version,
**Deprecated** which contains deprecated functions that are recommended not to
use but will not break any old code, and the **New Features** which are optional
new features available in the new version that users might find interesting.
Using them is optional, but encouraged.

Contributing
============

See the guide for `contributing to Neptune-versioned libraries
<https://github.com/sociomantic-tsunami/neptune/blob/v0.x.x/doc/library-contributor.rst>`_.

.. |TravisCI| image:: https://travis-ci.com/sociomantic-tsunami/ocean.svg?branch=v5.x.x
.. _TravisCI: https://travis-ci.com/github/sociomantic-tsunami/ocean
