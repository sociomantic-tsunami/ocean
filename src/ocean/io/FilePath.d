/*******************************************************************************

    Subclass of ocean.io.FilePath to provide some extra functionality

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.FilePath;



/*******************************************************************************

    Imports.

*******************************************************************************/

import ocean.transition;

import ocean.io.FilePath_tango;

import ocean.io.Path : FS;

import ocean.stdc.posix.unistd : link;



/*******************************************************************************

    Models a file path.

    See ocean.io.FilePath module for more details. The purpose of this class is
    only to provide missing functionality.

*******************************************************************************/

public class FilePath : ocean.io.FilePath_tango.FilePath
{

    /***********************************************************************

        Create a FilePath from a copy of the provided string.

        See ocean.io.FilePath.FilePath constructor for details.

    ***********************************************************************/

    public this (cstring filepath = null)
    {
        super (filepath);
    }

    /***********************************************************************

        Create a new name for a file (also known as -hard-linking)

        Params:
            dst = FilePath with the new file name

        Returns:
            this.path set to the new destination location if it was moved,
            null otherwise.

        See_Also:
            man 2 link

    ***********************************************************************/

    public final FilePath link ( FilePath dst )
    {
        if (.link(this.cString().ptr, dst.cString().ptr) is -1)
        {
            FS.exception(this.toString());
        }

        return this;
    }

}

