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

import ocean.stdc.string;
import ocean.transition;

version (UnitTest)
{
    import ocean.core.Test;
}


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

    /// Internal struct to associate a `Level` with its name
    private struct Pair
    {
        /// The name associated with `value`
        istring name;
        /// An `ILogger.Level` value
        Level value;
    }

    /***************************************************************************

        Poor man's SmartEnum: We don't use SmartEnum directly because
        it would change the public interface, and we accept any case anyway.

        This can be fixed when we drop D1 support.

    ***************************************************************************/

    private static immutable Pair[Level.max + 1] Pairs =
    [
        { "Trace",  Level.Trace },
        { "Info",   Level.Info },
        { "Warn",   Level.Warn },
        { "Error",  Level.Error },
        { "Fatal",  Level.Fatal },
        { "None",   Level.None }
    ];

    /***************************************************************************

        Return the enum value associated with `name`, or a default value

        Params:
            name = Case-independent string representation of an `ILogger.Level`
                   If the name is not one of the logger, `def` is returned.
            def  = Default value to return if no match is found for `name`

        Returns:
            The `Level` value for `name`, or `def`

    ***************************************************************************/

    public static Level convert (cstring name, Level def = Level.Trace)
    {
        foreach (field; ILogger.Pairs)
        {
            if (field.name.length == name.length
                && !strncasecmp(name.ptr, field.name.ptr, name.length))
                return field.value;
        }
        return def;
    }

    /***************************************************************************

        Return the name associated with level

        Params:
            level = The `Level` to get the name for

        Returns:
            The name associated with `level`.

    ***************************************************************************/

    public static istring convert (Level level)
    {
        return ILogger.Pairs[level].name;
    }


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

unittest
{
    test!("==")(ILogger.convert(ILogger.Level.Trace), "Trace");
    test!("==")(ILogger.convert(ILogger.Level.Info), "Info");
    test!("==")(ILogger.convert(ILogger.Level.Warn), "Warn");
    test!("==")(ILogger.convert(ILogger.Level.Error), "Error");
    test!("==")(ILogger.convert(ILogger.Level.Fatal), "Fatal");
    test!("==")(ILogger.convert(ILogger.Level.None), "None");
}

unittest
{
    test!("==")(ILogger.convert("info"), ILogger.Level.Info);
    test!("==")(ILogger.convert("Info"), ILogger.Level.Info);
    test!("==")(ILogger.convert("INFO"), ILogger.Level.Info);
    test!("==")(ILogger.convert("FATAL"), ILogger.Level.Fatal);
    // Use the default value
    test!("==")(ILogger.convert("Info!"), ILogger.Level.Trace);
    test!("==")(ILogger.convert("Baguette", ILogger.Level.Warn),
                ILogger.Level.Warn);
    // The first entry in the array
    test!("==")(ILogger.convert("trace", ILogger.Level.Error),
                ILogger.Level.Trace);
}
