/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version:
            Nov 2005: split from Configurator.d
            Feb 2007: removed default console configuration

        Authors: Kris

*******************************************************************************/

deprecated module ocean.util.log.ConfigProps;

import ocean.transition;

import ocean.util.log.Log;

import ocean.io.stream.Map,
       ocean.io.device.File;

/*******************************************************************************

        A utility class for initializing the basic behaviour of the
        default logging hierarchy.

        ConfigProps parses a much simplified version of the property file.
        Tango.log only supports the settings of Logger levels at this time,
        and setup of Appenders and Layouts are currently done "in the code"

*******************************************************************************/

deprecated struct ConfigProps
{
        /***********************************************************************

                Add a default StdioAppender, with a SimpleTimerLayout, to
                the root node. The activity levels of all nodes are set
                via a property file with name=value pairs specified in the
                following format:

                    name: the actual logger name, in dot notation
                          format. The name "root" is reserved to
                          match the root logger node.

                   value: one of TRACE, INFO, WARN, ERROR, FATAL
                          or NONE (or the lowercase equivalents).

                For example, the declaration

                ---
                ocean.unittest = INFO
                myApp.SocketActivity = TRACE
                ---

                sets the level of the loggers called ocean.unittest and
                myApp.SocketActivity

        ***********************************************************************/

        static void opCall (char[] path)
        {
                auto input = new MapInput!(Const!(char))(new File(path));
                scope (exit)
                       input.close;

                // read and parse properties from file
                foreach (name, value; input)
                        {
                        auto log = (name == "root") ? Log.root
                                                    : Log.lookup (name);
                        if (log)
                            log.level (Log.convert (value));
                        }
        }
}

