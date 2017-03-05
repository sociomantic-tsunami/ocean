/*******************************************************************************

        FilePath provides a means to efficiently edit path components and
        to access the underlying file system.

        Use module Path.d instead when you need pedestrian access to the
        file system, and are not mutating the path components themselves

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version:
            Oct 2004: Initial version
            Nov 2006: Australian version
            Feb 2007: Mutating version
            Mar 2007: Folded FileProxy in
            Nov 2007: VFS dictates '/' always be used
            Feb 2008: Split file system calls into a struct

        Authors: Kris

*******************************************************************************/

deprecated module ocean.io.FilePath_tango;

pragma(msg, "Module ocean.io.FilePath_tango is deprecated, use ocean.io.FilePath instead");

public import ocean.io.FilePath;
