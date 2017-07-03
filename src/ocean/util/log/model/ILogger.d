/*******************************************************************************

    Base interface for Loggers implementation

    Note:
        The formatting primitives (error, info, warn...) are not part of the
        interface anymore, as they can be templated functions.

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


/// Ditto
interface ILogger
{
    /// Defines the level at which a message can be logged
    public enum Level
    {
        ///
        Trace = 0,
        ///
        Info,
        ///
        Warn,
        ///
        Error,
        ///
        Fatal,
        ///
        None
    };


    /***************************************************************************

        Context for a hierarchy, used for customizing behaviour of log
        hierarchies. You can use this to implement dynamic log-levels,
        based upon filtering or some other mechanism

    ***************************************************************************/

    public interface Context
    {
        /// return a label for this context
        public istring label ();

        /// first arg is the setting of the logger itself, and
        /// the second arg is what kind of message we're being
        /// asked to produce
        public bool enabled (Level setting, Level target);
    }


    /***************************************************************************

        Returns:
            `true` if this logger is enabed for the specified `Level`

        Params:
            `Level` to test for, defaults to `Level.Fatal`.

    ***************************************************************************/

    public bool enabled (Level level = Level.Fatal);

    /***************************************************************************

        Returns:
            The name of this `ILogger` (without the appended dot).

    ***************************************************************************/

    public cstring name ();

        /***********************************************************************

                Append a trace message

        ***********************************************************************/

        void trace (cstring fmt, ...);

        /***********************************************************************

                Append an info message

        ***********************************************************************/

        void info (cstring fmt, ...);

        /***********************************************************************

                Append a warning message

        ***********************************************************************/

        void warn (cstring fmt, ...);

        /***********************************************************************

                Append an error message

        ***********************************************************************/

        void error (cstring fmt, ...);

        /***********************************************************************

                Append a fatal message

        ***********************************************************************/

        void fatal (cstring fmt, ...);

    /***************************************************************************

        Returns:
            The `Level` this `ILogger` is set to

    ***************************************************************************/

    public Level level ();

    /***************************************************************************

        Set the current `Level` for this logger (and only this logger).

        Params:
            l = New `Level` value to set this logger to.

        Returns:
            `this` for easy chaining

    ***************************************************************************/

    public ILogger level (Level l);

    /***************************************************************************

        Returns:
            `true` if the logger is additive.
            Additive loggers walk through ancestors looking for more appenders

    ***************************************************************************/

    public bool additive ();

    /***************************************************************************

        Set the additive status of this logger

        Additive loggers walk through ancestors looking for more appenders

        Params:
            enabled = Whereas this logger is additive.

        Returns:
            `this` for easy chaining

    ***************************************************************************/

    public ILogger additive (bool enabled);

    /***************************************************************************

        Send a message to this logger.

        Params:
            level = Level at which to log the message
            exp   = Lazily evaluated message string
                    If the `level` is not enabled for this logger, it won't
                    be evaluated.

        Returns:
            `this` for easy chaining

    ***************************************************************************/

    public ILogger append (Level level, lazy cstring exp);
}
