/*******************************************************************************

    Log appender which writes to syslog

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.log.AppendSysLog;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.log.Log;
import ocean.transition;

/*******************************************************************************

    syslog C functions

    FIXME: use runtime bindings

*******************************************************************************/

extern ( C )
{
    void openlog ( in char* ident, int option, int facility );
    void syslog ( int priority, in char* format, ... );
}

/*******************************************************************************

    syslog priority levels

*******************************************************************************/

private enum Priority
{
    LOG_EMERG   = 0, /* system is unusable */
    LOG_ALERT   = 1, /* action must be taken immediately */
    LOG_CRIT    = 2, /* critical conditions */
    LOG_ERR     = 3, /* error conditions */
    LOG_WARNING = 4, /* warning conditions */
    LOG_NOTICE  = 5, /* normal but significant condition */
    LOG_INFO    = 6, /* informational */
    LOG_DEBUG   = 7, /* debug-level messages */
}

/*******************************************************************************

    syslog appender class

*******************************************************************************/

public class AppendSysLog : Appender
{
    import ocean.core.Array : concat;
    import ocean.core.TypeConvert : castFrom;

    /***************************************************************************

        Layout class for syslog output. Outputs the logger name followed by the
        log message.

    ***************************************************************************/

    private static class SysLogLayout : Layout
    {
        override public void format ( LogEvent event,
            size_t delegate(Const!(void)[]) dg )
        {
            dg("[");
            dg(event.name);
            dg("] - ");
            dg(event.toString);
        }
    }

    /***************************************************************************

        Alias for this type.

    ***************************************************************************/

    private alias typeof(this) This;

    /***************************************************************************

        Static instance of SysLogLayout, shared by all AppendSysLog instances.

    ***************************************************************************/

    static private SysLogLayout syslog_layout;

    /***************************************************************************

        Static constructor. Initialises the shared SysLogLayout instance.

    ***************************************************************************/

    static this ( )
    {
        This.syslog_layout = new SysLogLayout;
    }

    /***************************************************************************

        Internal formatting buffer.

    ***************************************************************************/

    private mstring buf;

    /***************************************************************************

        Mask used to identify this Appender. The mask is used to figure out
        whether an appender has already been invoked for a particular logger.

    ***************************************************************************/

    private Mask mask_;

    /***************************************************************************

        Global ID string used by syslog to identify this program's log messages.
        Set by setId().

    ***************************************************************************/

    static private mstring id;

    /***************************************************************************

        Sets the global syslog ID string for this program. Calling this function
        is optional; if it is not called, the program's name is used as the ID.

        Params:
            id = ID string to set (copied internally)

    ***************************************************************************/

    static public void setId ( cstring id )
    {
        This.id.concat(id, "\0");
        int option = 0; // no options
        int facility = 0; // default facility
        openlog(This.id.ptr, option, facility);
    }

    /***************************************************************************

        Constructor. Sets the layout to the static SysLogLayout instance.

    ***************************************************************************/

    public this ( )
    {
        this.layout = This.syslog_layout;
    }

    /***************************************************************************

        Return:
            the fingerprint for this class

    ***************************************************************************/

    override public Mask mask ( )
    {
        return this.mask_;
    }

    /***************************************************************************

        Returns:
            the name of this class

    ***************************************************************************/

    override public istring name ( )
    {
        return this.classinfo.name;
    }

    /***************************************************************************

        Append an event to the output.

        Params:
            event = log event to be appended

    ***************************************************************************/

    override public void append ( LogEvent event )
    {
        if ( event.level != event.level.None )
            syslog(this.priority(event), "%s".ptr, this.format(event));
    }

    /***************************************************************************

        Gets the syslog priority for the specified log event.

        Params:
            event = log event to get the priority for

        Returns:
            syslog priority of the log event

        In:
            as level None is a non-value, events of this level are not valid
            input to the function

    ***************************************************************************/

    private int priority ( LogEvent event )
    in
    {
        assert(event.level != event.level.None);
    }
    body
    {
        with ( Level ) switch ( event.level )
        {
            case Trace:
                return Priority.LOG_DEBUG;
            case Info:
                return Priority.LOG_INFO;
            case Warn:
                return Priority.LOG_WARNING;
            case Error:
                return Priority.LOG_ERR;
            case Fatal:
                return Priority.LOG_CRIT;
            default:
                assert(false);
            // Note that there is no mapping to LOG_NOTICE, LOG_ALERT, LOG_EMERG
        }
    }

    /***************************************************************************

        Gets a pointer to the formatted, null-terminated string for the
        specified log event.

        Params:
            event = log event to get the formatted string for

        Returns:
            pointer to the formatted string for the log event

    ***************************************************************************/

    private char* format ( LogEvent event )
    {
        size_t layoutSink ( Const!(void)[] data )
        {
            this.buf ~= castFrom!(Const!(void)[]).to!(cstring)(data);
            return data.length;
        }

        this.buf.length = 0;
        enableStomping(this.buf);
        this.layout.format(event, &layoutSink);
        this.buf ~= '\0';

        return this.buf.ptr;
    }
}
