/*******************************************************************************

    This package contains various template utilities that deduce types or values
    by reflecting on supplied type arguments and doing some compile-time
    manipulations on them.

    NB: because this module is often used as purely compile-time dependency it
        used built-in asserts instead of `ocean.core.Test` to reduce amount of
        cyclic imports. `ocean.meta` modules in general are not supposed to
        import anything outside of `ocean.meta`.

    Copyright:
        Copyright (c) 2017 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).


*******************************************************************************/

module ocean.meta.types;

public import ocean.meta.types.Arrays;
public import ocean.meta.types.Enum;
public import ocean.meta.types.Function;
public import ocean.meta.types.Qualifiers;
public import ocean.meta.types.ReduceType;
public import ocean.meta.types.Templates;
public import ocean.meta.types.Typedef;
