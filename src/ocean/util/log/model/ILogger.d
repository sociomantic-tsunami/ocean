/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: May 2004

        Authors: Kris

*******************************************************************************/

module ocean.util.log.model.ILogger;

import ocean.transition;

/*******************************************************************************

*******************************************************************************/

interface ILogger
{
        enum Level {Trace=0, Info, Warn, Error, Fatal, None};


        /***********************************************************************

                Context for a hierarchy, used for customizing behaviour
                of log hierarchies. You can use this to implement dynamic
                log-levels, based upon filtering or some other mechanism

        ***********************************************************************/

        interface Context
        {
                /// return a label for this context
                istring label ();

                /// first arg is the setting of the logger itself, and
                /// the second arg is what kind of message we're being
                /// asked to produce
                bool enabled (Level setting, Level target);
        }


        /***********************************************************************

                Is this logger enabed for the specified Level?

        ***********************************************************************/

        bool enabled (Level level = Level.Fatal);


        /***********************************************************************

                Return the name of this ILogger (sans the appended dot).

        ***********************************************************************/

        cstring name ();

        /***********************************************************************

                Return the Level this logger is set to

        ***********************************************************************/

        Level level ();

        /***********************************************************************

                Set the current level for this logger (and only this logger).

        ***********************************************************************/

        ILogger level (Level l);

        /***********************************************************************

                Is this logger additive? That is, should we walk ancestors
                looking for more appenders?

        ***********************************************************************/

        bool additive ();

        /***********************************************************************

                Set the additive status of this logger. See isAdditive().

        ***********************************************************************/

        ILogger additive (bool enabled);

        /***********************************************************************

                Send a message to this logger via its appender list.

        ***********************************************************************/

        ILogger append (Level level, lazy cstring exp);
}
