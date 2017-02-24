/*******************************************************************************

    Arguments extension to refuse startup of the process if run as root.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.ext.RefuseRootExt;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;
import ocean.util.app.ext.model.IArgumentsExtExtension;
import core.sys.posix.unistd;


/*******************************************************************************

    Arguments extension that refuses to start if the program is run as root.
    Behavior can be overridden by specifying --asroot

*******************************************************************************/

class RefuseRootExt : IArgumentsExtExtension
{
    /***************************************************************************

        Order doesn't matter, so return default -> 0

        Returns:
            the extension order

    ***************************************************************************/

    override int order ()
    {
        return 0;
    }

    /***************************************************************************

        Function executed when command line arguments are set up (before
        parsing).

        Params:
            app = application instance
            args = command line arguments instance

    ***************************************************************************/

    override void setupArgs ( IApplication app, Arguments args )
    {
        args("asroot").params(0).help("Run as root");
    }


    /***************************************************************************

        Function executed after parsing the command line arguments.

        This function is only called if the arguments are valid so far.

        Params:
            app = application instance
            args = command line arguments instance

        Returns:
            string with an error message if validation failed, null otherwise

    ***************************************************************************/

    override cstring validateArgs ( IApplication app, Arguments args )
    {
        if ( getuid() == 0 && !args.exists("asroot"))
        {
            return "Won't run as root! (use --asroot if you really need to do this)";
        }
        else
        {
            return null;
        }
    }


    /***************************************************************************

        Unused IArgumentsExtExtension methods.

        We just need to provide an "empty" implementation to satisfy the
        interface.

    ***************************************************************************/

    override void processArgs ( IApplication app, Arguments args )
    {
        // Unused
    }

    override void preValidateArgs ( IApplication app, Arguments args )
    {
        // Unused
    }
}
