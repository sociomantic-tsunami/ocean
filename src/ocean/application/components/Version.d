/*******************************************************************************

    App version and build information.

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.application.components.Version;

import ocean.transition;
import ocean.core.Array: startsWith, map;
import ocean.core.array.Mutation /* : moveToEnd, sort */;
import ocean.text.Util;

/*******************************************************************************

    Associative array which contains version information.

    Typically this array should contain the keys:
     * build_author
     * build_date
     * dmd
     * gc
     * lib_*

    Where lib_* are considered to be libraries used by this program.

    This is usually generated automatically, this is why this kind of *duck
    typing* is used (to avoid a dependency between the generator and this
    library).

*******************************************************************************/

public alias istring[istring] VersionInfo;

/*******************************************************************************

    Get the program's name and basic version information as a string.

    Params:
        app_name = program's name
        ver = description of the application's version / revision

    Returns:
        String with the version information

*******************************************************************************/

public istring getVersionString ( istring app_name, VersionInfo ver )
{
    auto v = "version" in ver;
    if (v !is null)
        return app_name ~ " version " ~ *v;
    else
        return app_name ~ " unkown version";
}

/*******************************************************************************

    Get the program's name and extended build information as a string.

    Params:
        app_name = program's name
        ver = description of the application's version / revision
        single_line = if set to `true`, puts key-value pairs on the same
            line

    Returns:
        String with the version information

*******************************************************************************/

public istring getBuildInfoString ( istring app_name, VersionInfo ver,
    bool single_line = false )
{
    istring s = getVersionString(app_name, ver);

    istring separator;
    if (single_line)
        separator = ", ";
    else
        separator = "\n";

    if (ver.length)
    {
        auto sorted_names = ver.keys;
        sorted_names.length = moveToEnd(sorted_names, "version");
        sorted_names.sort();

        scope formatter = (istring n)
        {
            return n ~ "=" ~ ver[n];
        };

        s ~= separator;
        s ~= sorted_names
            .map(formatter)
            .join(separator);
    }

    return s;
}

version ( UnitTest )
{
    import ocean.core.Test;
}

/*******************************************************************************

    Test the built version string

*******************************************************************************/

unittest
{
    VersionInfo info;
    info["version"] = "v1.0";
    info["build_author"] = "me";
    info["build_date"] = "today";
    info["compiler"] = "dmd3";
    info["lib_awesome"] = "v10.0";
    info["lib_sucks"] = "v0.5";
    info["extra"] = "useful";
    info["more"] = "info";
    test!("==")(
        getVersionString("test", info),
        "test version v1.0"
    );
    test!("==")(
        getBuildInfoString("test", info),
        "test version v1.0
build_author=me
build_date=today
compiler=dmd3
extra=useful
lib_awesome=v10.0
lib_sucks=v0.5
more=info"
    );
    test!("==")(
        getBuildInfoString("test", info, true),
        "test version v1.0, " ~
            "build_author=me, build_date=today, compiler=dmd3, extra=useful, " ~
            "lib_awesome=v10.0, lib_sucks=v0.5, more=info"
    );
}
