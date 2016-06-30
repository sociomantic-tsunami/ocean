/*******************************************************************************

    Extension for the LogExt ConfigExt extension.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.ext.model.ILogExtExtension;



/*******************************************************************************

    Imports

*******************************************************************************/

public import ocean.util.app.model.IApplication;
public import ocean.util.config.ConfigParser : ConfigParser;

import ocean.util.app.model.IExtension;



/*******************************************************************************

    Interface for extensions for the LogExt extension.

*******************************************************************************/

interface ILogExtExtension : IExtension
{

    /***************************************************************************

        Function executed before the loggers are configured.

        Params:
            app = application instance
            config = configuration parser
            loose_config_parsing = true if errors shouldn't be triggered on
                                   unknown configuration options
            use_insert_appender = true if the InsertConsole appender should be
                                  used (needed when using the AppStatus module)

    ***************************************************************************/

    void preConfigureLoggers ( IApplication app, ConfigParser config,
            bool loose_config_parsing, bool use_insert_appender );


    /***************************************************************************

        Function executed after the loggers are configured.

        Params:
            app = application instance
            config = configuration parser
            loose_config_parsing = true if errors shouldn't be triggered on
                                   unknown configuration options
            use_insert_appender = true if the InsertConsole appender should be
                                  used (needed when using the AppStatus module)

    ***************************************************************************/

    void postConfigureLoggers ( IApplication app, ConfigParser config,
            bool loose_config_parsing, bool use_insert_appender );

}

