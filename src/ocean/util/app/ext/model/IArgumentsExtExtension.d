/*******************************************************************************

    Extension for the ArgumentsExt Application extension.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.ext.model.IArgumentsExtExtension;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

public import ocean.util.app.model.IApplication;
public import ocean.text.Arguments : Arguments;

import ocean.util.app.model.IExtension;



/*******************************************************************************

    Interface for extensions for the ArgumentsExt Application extension.

*******************************************************************************/

interface IArgumentsExtExtension : IExtension
{

    /***************************************************************************

        Function executed when command line arguments are set up (before
        parsing).

        Params:
            app = application instance
            args = command line arguments instance

    ***************************************************************************/

    void setupArgs ( IApplication app, Arguments args );


    /***************************************************************************

        Function executed after parsing of command line args (whether the basic
        parsing failed or succeeded) but before the call to validateArgs().

        Params:
            app = application instance
            args = command line arguments instance

    ***************************************************************************/

    void preValidateArgs ( IApplication app, Arguments args );


    /***************************************************************************

        Function executed after parsing the command line arguments.

        This function is only called if the arguments are valid so far.

        Params:
            app = application instance
            args = command line arguments instance

        Returns:
            string with an error message if validation failed, null otherwise

    ***************************************************************************/

    cstring validateArgs ( IApplication app, Arguments args );


    /***************************************************************************

        Function executed after (successfully) validating the command line
        arguments.

        Params:
            app = application instance
            args = command line arguments instance

    ***************************************************************************/

    void processArgs ( IApplication app, Arguments args );

}
