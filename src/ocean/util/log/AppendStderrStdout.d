/*******************************************************************************

    Implementation of logging appender which writes to both stdout and stderr
    based on logging level.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.log.AppendStderrStdout;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;
import ocean.util.log.Appender;
import ocean.util.log.Event;
import ocean.util.log.model.ILogger;

/*******************************************************************************

    Appender class.

    Important properties:
        - always flushes after logging
        - warnings/errors/fatals go to stderr
        - info/traces/debug goes to stdout

    Exact log level to be treated as first "stderr" level can be configured
    via constructor.

*******************************************************************************/

public class AppendStderrStdout : Appender
{
    import ocean.io.device.Device;
    import ocean.io.Console;

    /***********************************************************************

        Cached mask value used by logger internals

    ***********************************************************************/

    private Mask mask_;

    /***********************************************************************

        Defines which logging Level will be used as first "error" level.

    ***********************************************************************/

    private ILogger.Level first_stderr_level;

    /***********************************************************************

        Constructor

        Params:
            first_stderr_level = LogEvent with this level and higher will
                be written to stderr. Defaults to Level.Warn
            how = optional custom layout object

    ************************************************************************/

    public this (ILogger.Level first_stderr_level = ILogger.Level.Warn,
                 Appender.Layout how = null)
    {
        mask_ = register(name);
        this.first_stderr_level = first_stderr_level;
        layout(how);
    }

    /***********************************************************************

        Returns:
            the fingerprint for this class

    ************************************************************************/

    final override public Mask mask ()
    {
        return mask_;
    }

    /***********************************************************************

        Returns:
            the name of this class

    ************************************************************************/

    override public istring name ()
    {
        return this.classinfo.name;
    }

    /***********************************************************************

        Writes log event to target stream

        Params:
            event = log message + metadata

    ************************************************************************/

    final override public void append (LogEvent event)
    {
        OutputStream stream;
        if (event.level >= this.first_stderr_level)
            stream = Cerr.stream();
        else
            stream = Cout.stream();

        layout.format(
            event,
            (Const!(void)[] content) {
                return stream.write(content);
            }
        );
        stream.write(Console.Eol);
        stream.flush;
    }
}
