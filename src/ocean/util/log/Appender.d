/*******************************************************************************

    Define the base classes for all Appenders

    Appenders are objects that are responsible for emitting messages sent
    to a particular logger. There may be more than one appender attached
    to any logger.
    The actual message is constructed by another class known as an EventLayout.

    Copyright:
        Copyright (c) 2004 Kris Bell.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

*******************************************************************************/

module ocean.util.log.Appender;

import ocean.transition;
import ocean.core.Exception_tango;
import ocean.io.model.IConduit;
import ocean.util.log.Event;
import ocean.util.log.model.ILogger;


/// Base class for all Appenders
public class Appender
{
    mixin(Typedef!(int, "Mask"));

    private Appender        next_;
    private ILogger.Level   level_;
    private Layout          layout_;
    private static Layout   generic;

    /***************************************************************************

                Interface for all logging layout instances

                Implement this method to perform the formatting of
                message content.

    ***************************************************************************/

    interface Layout
    {
        void format (LogEvent event, size_t delegate(Const!(void)[]) dg);
    }

    /***************************************************************************

        Return the mask used to identify this Appender.

        The mask is used to figure out whether an appender has already been
        invoked for a particular logger.

    ***************************************************************************/

    abstract Mask mask ();

    /// Return the name of this Appender.
    abstract cstring name ();

    /// Append a message to the output.
    abstract void append (LogEvent event);

    /// Create an Appender and default its layout to LayoutTimer.
    this ()
    {
        if (generic is null)
            generic = new LayoutTimer;
        layout_ = generic;
    }

    /// Return the current Level setting
    final ILogger.Level level ()
    {
        return level_;
    }

    /// Return the current Level setting
    final Appender level (ILogger.Level l)
    {
        level_ = l;
        return this;
    }

    /***************************************************************************

        Static method to return a mask for identifying the Appender.

        Each Appender class should have a unique fingerprint so that we can
        figure out which ones have been invoked for a given event.
        A bitmask is a simple an efficient way to do that.

    ***************************************************************************/

    protected Mask register (cstring tag)
    {
        static Mask mask = 1;
        static Mask[istring] registry;

        Mask* p = tag in registry;
        if (p)
            return *p;
        else
        {
            auto ret = mask;
            registry [tag] = mask;

            if (mask < 0)
                throw new IllegalArgumentException ("too many unique registrations");

            mask <<= 1;
            return ret;
        }
    }

    /***************************************************************************

        Set the current layout to be that of the argument, or the generic layout
        where the argument is null

    ***************************************************************************/

    void layout (Layout how)
    {
        assert(generic !is null);
        layout_ = how ? how : generic;
    }

    /// Return the current Layout
    Layout layout ()
    {
        return layout_;
    }

    /// Attach another appender to this one
    void next (Appender appender)
    {
        next_ = appender;
    }

    /// Return the next appender in the list
    Appender next ()
    {
        return next_;
    }

    /// Close this appender. This would be used for file, sockets, and the like
    void close ()
    {
    }
}


/*******************************************************************************

    An appender that does nothing.

    This is useful for cutting and pasting, and for benchmarking the ocean.log
    environment.

*******************************************************************************/

public class AppendNull : Appender
{
    private Mask mask_;

    /// Create with the given Layout
    this (Layout how = null)
    {
        mask_ = register (name);
        layout (how);
    }

    /// Return the fingerprint for this class
    final override Mask mask ()
    {
        return mask_;
    }

    /// Return the name of this class
    final override cstring name ()
    {
        return this.classinfo.name;
    }

    /// Append an event to the output
    final override void append (LogEvent event)
    {
        layout.format (event, (Const!(void)[]){return cast(size_t) 0;});
    }
}


/// Append to a configured OutputStream
public class AppendStream : Appender
{
    private Mask            mask_;
    private bool            flush_;
    private OutputStream    stream_;

    ///Create with the given stream and layout
    this (OutputStream stream, bool flush = false, Appender.Layout how = null)
    {
        assert (stream);

        mask_ = register (name);
        stream_ = stream;
        flush_ = flush;
        layout (how);
    }

    /// Return the fingerprint for this class
    final override Mask mask ()
    {
        return mask_;
    }

    /// Return the name of this class
    override istring name ()
    {
        return this.classinfo.name;
    }

    /// Append an event to the output.
    final override void append (LogEvent event)
    {
        const istring Eol = "\n";

        layout.format (event, (Const!(void)[] content){return stream_.write(content);});
        stream_.write (Eol);
        if (flush_)
            stream_.flush;
    }
}


/*******************************************************************************

    A simple layout comprised only of time(ms), level, name, and message

*******************************************************************************/

public class LayoutTimer : Appender.Layout
{
    /***************************************************************************

        Subclasses should implement this method to perform the formatting
         of the actual message content.

    ***************************************************************************/

    void format (LogEvent event, size_t delegate(Const!(void)[]) dg)
    {
        char[20] tmp = void;

        dg (event.toMilli (tmp, event.span));
        dg (" ");
        dg (event.levelName);
        dg (" [");
        dg (event.name);
        dg ("] ");
        dg (event.host.label);
        dg ("- ");
        dg (event.toString);
    }
}
