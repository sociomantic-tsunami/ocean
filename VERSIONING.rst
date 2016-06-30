================
Ocean Versioning
================

This is a versioning guide based on SemVer_ that Ocean uses. The goal is to
improve stability and the convenience of the users of this library.

.. _SemVer: http://semver.org

.. contents::

Goals
-----

1. To separate feature additions from bug fixes. To separate both from breaking
   changes and major refactorings.
2. To give a reasonable adaptation time span for projects using the library to
   perform "risky" upgrades.
3. To enable a flexible, on-demand release model.

Versioning
----------

Follows the standard **X.Y.Z** pattern, where:

- **X** (major release) is incremented for: removal of deprecated symbols,
  refactorings that affect API, any major semantic changes in general.
- **Y** (minor release) is incremented for: new features, deprecations,
  minor internal refactorings that don't affect the API.
- **Z** (point release) is incremented only for: non-intrusive bug fixes
  that are always 100% safe to upgrade to.

A major release will be made as needed, at most every 6 months. Minor releases
come out roughly each month. Point releases come out as soon as possible to
fix critical bugs. A major version keeps being developed for 1 to 3 months after
the following major version has been released, allowing for a smooth upgrade
period for users of the old version. The guaranteed support period for old major
versions is specified in ``README.rst``.

Compatibility is defined as "keeps compiling with ``-di`` with no semantical
changes to existing code". Minor releases ensure backwards compatibility but
not forward compatibility - thus discipline is required in the usage of new
Ocean features in libraries that depend on Ocean, to avoid indirectly forcing
users to upgrade.

The main goal of this versioning scheme is to ensure that developers can upgrade
to any new minor version without being ever forced to change anything in their
code. At the same time, to provide a source of bug fixes for those who are
concerned about accidental changes/bugs from new features too.

Terminology
~~~~~~~~~~~

**A (major) version in development** means that it gets new features by default,
even if there is a newer major version released.

**A (minor) version in support** means it gets new bug fixes by default. For
example, at any time at least the last minor release of any developed major
version should be supported.

Branching, tagging and milestones
---------------------------------

At any given point of time there must be at least these branches in the git
repo:

* One that matches the last released major (e.g. v3.x.x) which is used for all
  feature development and is configured to be the default branch in GitHub. When
  a feature release is made, a new minor version branch is forked from its
  ``HEAD`` (e.g. v3.2.x).

* One that matches the next planned major (e.g. v4.x.x) where all long term
  cleanups and breaking changes go. The current major (e.g. v3.x.x) is merged
  into it upon minor releases.

* One that matches the last feature release (e.g. v3.1.x). All bug fixes go here
  by default and are cherry-picked into older minor release branches on demand.
  After a point release is created, the matching tag (e.g. v3.1.2) gets merged
  into the current major version branch (e.g. v3.x.x).

All branches referring to a version being maintained or developed should have
at least one *.x* in their names. All tags should consist of only concrete
numbers. Milestones should be named the same as the tag that will be created
when the milestone is completed.

Example:

* Current major/minor branch being developed: v3.x.x
* Current major/minor branch being maintained: v3.1.x
* Last released version: v3.1.1
* Milestone for the next point release: v3.1.2
* Milestone for the next minor release: v3.2.0
* Next unreleased major: v4.x.x
* Milestone for next major release: v4.0.0

Supporting multiple major versions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Once the next planned major reaches release (e.g. v4.0.0) it doesn't replace the
current major immediately. For the sake of stability and developer convenience,
new features should still go to the previous major (v3.x.x) by default and be
merged to the new major (v4.x.x) after.

After the support cycle for v3.x.x expires (usually around 3 months after the
next major was released, v4.0.0 in the example), the v4.x.x branch becomes the
new stable version and v3.x.x stops receiving changes apart from critical,
on-demand bug fixes.

Lack of master branch
~~~~~~~~~~~~~~~~~~~~~

In GitHub it is impossible to change the base branch for a pull request once it
has been created. The "default" base branch can be configured in the GitHub web
interface. As the most common type of pull request is adding a new feature, it
makes the most sense to always configure a repository to have the oldest
supported major version branch as the default one - to avoid a lot of pull
request noise when contributors choose the wrong branch by mistake. Because of
this, Ocean doesn't have a ``master`` branch, but instead changes the default
branch to the current in-development minor.

Example branch graph
--------------------

Lines define branches and their relations:

- ``-``: commit history for a branch (right == older)
- ``/`` or ``\``: merging (always happens from lower version to higher one)
- ``|``: tagging or forking a branch

Letters within a dashed line highlight different types of commits:

- ``B``: commit with a bug-fix
- ``F``: commit with a backwards-compatible feature
- ``D``: commit which deprecates symbols
- ``X``: commit with a breaking change
- ``M``: merge commit

.. code::

                                     .---X--X--X--M--F--X--F----F----M--> v4.x.x
                                    /            /       \          /
                                   /            /         +-B--M---B----> v4.0.x
                                  /       .----´          |   /    |
                                 /       /            v4.0.0 /  v4.0.1
                                /       /     .-------------´
                               /       /     /
     --F--F-----M--F--M--F-D--D--F-F--M-----M--------------------F------> v3.x.x
           \   /     /         \     /     /                     |\
            +-B--B--B--.        +---B--B--B--.                   | `----> v3.2.x
            | |     |   \       |   |     |   \               v3.2.0
       v3.0.0 |  v3.0.2  \   v3.1.0 |  v3.1.2  `------------------------> v3.1.x
           v3.0.1         \      v3.1.1
                           `--------------------------------------------> v3.0.x


Points worth additional attention:

1. v4.x.x gets branched from one of the v3.x.x releases at an arbitrary moment
   when the necessity of the first breaking change is identified - but it
   doesn't get its own release immediately. Once v4.0.0 is tagged, you can't put
   any new breaking changes there because v4.1.0 must comply to the minor
   release rules. That means it is a good idea to wait some time before tagging
   the first release of the new major branch in case more breaking changes will
   be needed.
2. There is one feature commit in v4.x.x which doesn't exist in v3.x.x. This
   normally shouldn't happen as all features should be implemented against the
   oldest supported major first. However, sometimes implementation only becomes
   feasible after big refactorings and can't be reasonably done against an older
   base. In such cases, saying it is a v4.x.x-only feature is OK.
3. The tag v3.1.2 gets merged twice - to the v3.x.x branch and to the v4.0.x
   branch. This is done so that v4.0.1 with the same bug fixes can be released
   without also merging new features from v3.x.x itself. Such a pattern has
   confused earlier versions of git resulting in "fake" conflicts but all
   up-to-date ones seem to figure it out decently.
4. For simplicity, this graph assumes that only the latest minor release gets
   bug fixes. In practice this may not be true for more mature libraries and bug
   fixes will be based on v3.0.x even if v3.1.0 has already been released. In
   such a case, v3.0.3 would first be merged to v3.1.x and only later would
   v3.1.3 be merged to v3.x.x.

