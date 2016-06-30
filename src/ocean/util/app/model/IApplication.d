/*******************************************************************************

    Application interface passed to methods of IApplicationExtension and others.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.model.IApplication;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.util.app.model.IApplicationExtension;



public interface IApplication : IApplicationExtension
{
    /***************************************************************************

        Returns:
            the name of the application

    ***************************************************************************/

    istring name ( );


    /***************************************************************************

        Exit cleanly from the application.

        Calling exit() will properly unwind the stack and all the destructors
        will be called. Should be used only from the main application thread
        though.

        Params:
            status = status code to return to the OS
            msg = optional message to show just before exiting

    ***************************************************************************/

    void exit ( int status, istring msg = null );
}
