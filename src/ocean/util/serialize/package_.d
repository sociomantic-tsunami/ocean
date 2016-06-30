/******************************************************************************

    Terminology
    -----------

    *serializer* : collection of algorithms responsible for representing data
    structure in domain-specific format. Serializers are not supposed to deal with
    any kind of metadata, just raw data representation.

    *deserializer* : collection of algorithms responsible for converting serialized
    data to a D data structure. Similar to serializer, it is not supposed to deal
    with metadata.

    *decorator* : collection of algorithms that work on top of already defined
    (de)serializer and augment stored data in some way. It can be adding version
    information or gzip compressing of serialized data, any kind of higher
    level post-processing.

    Package Structure
    -----------------

    ``ocean.util.serialize.model.*``
      collection of generic parts of serializer/decorator implementations

    ``ocean.util.serialize.pkgname.Serializer``
    ``ocean.util.serialize.pkgname.Deserializer``
    ``ocean.util.serialize.pkgname.*Decorator``
      actual modules to be used by applications. ``pkgname`` here represents
      specific serialization format, one sub-package for each new format. There can
      be more modules exposed to applications depending on specific format but
      those are minimal ones you should expect. Decorator implementation count may
      vary from 0 to many depending on actual needs.

    ``ocean.util.serialize.pgkname.model.*``
      any internal modules used to implement ``pkgname`` serializer / decorators

    Usage
    -----

    Refer to documentation of any specific sub-package for further usage details.

    Contribution
    ------------

    If you are going to implement and new serialization format, more detailed
    knowledge of this package internal is needed. Most important module to become
    familiar with is ``ocean.util.model.Traits`` - it defines set of ``isSomething``
    templates that help to ensure that given serializer / decorators conforms the
    standard API. ``ocean.util.serialize`` uses duck typing approach so there does
    not need to be any common base. In fact, serializers are commonly implemented
    as static structs.

    New format package must have at minimum ``Serializer`` and ``Deserilaizer``
    modules. Put ``static assert (isSerializer!(This));`` and
    ``static assert (isDeserializer!(This))`` at the beginning of actual aggregate
    definition to ensure that API is conformant. However you may want to disable
    that asssertion during initial development stage because DMD1 tends to hide
    any compiler error messages showing assertion failure instead.

    ``Decorator`` implementation is allowed to be non-static (so that it can keep
    any intermediate data buffers). As decorator methods are typically templated,
    one can't use abstract class / override approach for common parts. Technique
    used in existing ``VersionDecorator`` is to define set of template mixins that
    implement common methods and inject those directly to implementation classes.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

******************************************************************************/

module ocean.util.serialize.package_;

public import ocean.util.serialize.model.Traits;
public import ocean.util.serialize.contiguous.package_;
