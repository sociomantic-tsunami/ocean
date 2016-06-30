/*******************************************************************************

    Extension for the ConfigExt Application and ArgumentsExt extension.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.ext.model.IConfigExtExtension;



/*******************************************************************************

    Imports

*******************************************************************************/

public import ocean.util.app.model.IApplication;
public import ocean.util.config.ConfigParser : ConfigParser;

import ocean.util.app.model.IExtension;

import ocean.transition;


/*******************************************************************************

    Interface for extensions for the ConfigExt extension.

*******************************************************************************/

interface IConfigExtExtension : IExtension
{

    /***************************************************************************

        Function executed before the configuration files are parsed.

        Params:
            app = application instance
            config = configuration parser

    ***************************************************************************/

    void preParseConfig ( IApplication app, ConfigParser config );


    /***************************************************************************

        Function to filter the list of configuration files to parse.

        Params:
            app = application instance
            config = configuration parser
            files = current list of configuration files to parse

        Returns:
            new list of configuration files to parse

    ***************************************************************************/

    istring[] filterConfigFiles ( IApplication app, ConfigParser config,
                                  istring[] files );


    /***************************************************************************

        Function executed after the configuration files are parsed.

        Params:
            app = application instance
            config = configuration parser

    ***************************************************************************/

    void processConfig ( IApplication app, ConfigParser config );

}
