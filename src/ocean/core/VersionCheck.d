/*******************************************************************************

    Helper utility for reflection on `LibFeatures` modules provided by
    libraries. If a library provides a module named `libname.LibFeatures` which
    defines constants of form `const has_features_x_y = true` where `x` is major
    version number and `y` is minor version number, helper defined in this
    module allows to query supported features with a standard API.

    Copyright:
        Copyright (c) 2017 sociomantic labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.VersionCheck;

import ocean.transition;
import ocean.core.Traits;

/// ditto
public template hasFeaturesFrom ( istring libname, ulong major, ulong minor )
{
    static immutable hasFeaturesFrom = hasFeaturesFromFunc!(libname, major, minor)();
}

///
unittest
{
    static assert ( hasFeaturesFrom!("ocean", 2, 0));
    static assert ( hasFeaturesFrom!("ocean", 2, 6));
    static assert (!hasFeaturesFrom!("ocean", 100, 0)); // will have to be
                                                        // updated one day
}

private bool hasFeaturesFromFunc ( istring libname, ulong major, ulong minor ) ()
{
    // D1 does not support plain nested imports, D2 prohibits aggregate import
    // exposure, thus two different approaches:

    version (D_Version2)
    {
        mixin("import Library = " ~ libname ~ ".LibFeatures;");
    }
    else
    {
        struct Library
        {
            mixin("import " ~ libname ~ ".LibFeatures;");
        }
    }

    mixin("return is(typeof(Library.has_features_"
        ~ ctfe_i2a(major) ~ "_" ~ ctfe_i2a(minor) ~ "));");
}
