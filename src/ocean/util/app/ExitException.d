/*******************************************************************************

    Exception to raise to safely exit the program.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.ExitException;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;


/*******************************************************************************

    Exception to raise to safely exit the program.

    Should usually be used via Application.exit().

*******************************************************************************/

public class ExitException : Exception
{

    /***************************************************************************

        Exit status to return to the OS at exit.

    ***************************************************************************/

    int status;


    /***************************************************************************

        Exit exception constructor.

        Params:
            status = exit status to return to the OS at exit
            msg = optional message to show just before exiting

    ***************************************************************************/

    this ( int status, istring msg = null )
    {
        super(msg);
        this.status = status;
    }

}
