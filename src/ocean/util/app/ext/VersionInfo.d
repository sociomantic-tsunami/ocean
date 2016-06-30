/*******************************************************************************

    Helper class to store version information.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.ext.VersionInfo;


import ocean.transition;


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

alias istring[istring] VersionInfo;

