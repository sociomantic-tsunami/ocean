/*******************************************************************************

    Common struct to store `ocean.util.log` event internally

    Contains all information about a logging event, and is passed around
    between methods once it has been determined that the invoking logger
    is enabled for output.

    Note that Event instances are maintained in a freelist rather than
    being allocated each time, and they include a scratchpad area for
    EventLayout formatters to use.

    Copyright:
        Copyright (c) 2004 Kris Bell.
        Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

*******************************************************************************/

module ocean.util.log.Event;

import ocean.meta.types.Qualifiers;
import ocean.core.Verify;
import ocean.time.Clock;
import ocean.util.log.ILogger;

///
public struct LogEvent
{
    private cstring         msg_, name_;
    private Time            time_;
    private ILogger.Level   level_;
    private ILogger.Context host_;

    /// Set the various attributes of this event.
    void set (ILogger.Context host, ILogger.Level level, cstring msg, cstring name)
    {
        time_ = Clock.now;
        level_ = level;
        host_ = host;
        name_ = name;
        msg_ = msg;
    }

    /// Return the message attached to this event.
    cstring toString ()
    {
        return msg_;
    }

    /// Return the name of the logger which produced this event
    cstring name ()
    {
        return name_;
    }

    /// Return the logger level of this event.
    ILogger.Level level ()
    {
        return level_;
    }

    /// Return the hierarchy where the event was produced from
    ILogger.Context host ()
    {
        return host_;
    }

    /// Return the time this event was produced,
    /// relative to the start of this executable
    TimeSpan span ()
    {
        return time_ - Clock.startTime();
    }

    /// Return the time this event was produced relative to Epoch
    Time time ()
    {
        return time_;
    }

    /// Return the logger level name of this event.
    cstring levelName ()
    {
        return ILogger.convert(this.level_);
    }
}
