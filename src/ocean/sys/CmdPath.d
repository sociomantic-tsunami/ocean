/******************************************************************************

    Keeps the path of a running executable

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.sys.CmdPath;


import ocean.meta.types.Qualifiers;

import ocean.sys.Environment;

import ocean.io.FilePath;

import PathUtil = ocean.io.Path: normalize;

///
unittest
{
    void main ( string[] args )
    {
        CmdPath cmdpath;

        // set to path of running executable
        cmdpath.set(args[0]);

        // get absolute directory path of running executable
        auto exepath = cmdpath.get();

        // get absolute path of file "config.ini" located in subdirectory
        // "etc" of the running executable's directory
        auto cfgpath = cmdpath.prepend(["etc", "config.ini"]);
    }
}

/******************************************************************************

    MainExe structure

 ******************************************************************************/

struct CmdPath
{
    /**************************************************************************

         Directory of the executable

     **************************************************************************/

    private string dir;

    /**************************************************************************

         Sets the executable path.

         Params:
              exepath = executable path

         Returns:
              base directory

     **************************************************************************/

    public string set ( cstring exepath )
    {
        scope path = new FilePath(exepath);

        path.set(PathUtil.normalize(path.folder));

        this.dir = path.absolute(Environment.cwd()).toString();

        return this.get();
}

    /**************************************************************************

        Returns the base directory.

        Returns:
             base directory

     **************************************************************************/

    public string get ( )
    {
        return this.dir;
    }

    /**************************************************************************

        Prepends the absolute base directory to "path" and joins the path.

        Params:
             path = input path

        Returns:
             joined path with prepended absolute base directory

     **************************************************************************/

    public string prepend ( string[] path ... )
    {
        return FilePath.join(this.dir ~ path);
    }
}
