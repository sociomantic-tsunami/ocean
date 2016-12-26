/*******************************************************************************

    Static console tracer

    Static console tracer - moves the cursor back to its original position after
    printing the required text.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.log.StaticTrace;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.TypeConvert;

import ocean.io.Terminal;

import ocean.text.convert.Layout_tango;

import ocean.text.Search;

import ocean.io.model.IConduit;

import ocean.io.Console;

/*******************************************************************************

 Platform issues ...

*******************************************************************************/

version (GNU)
{
    import ocean.core.Vararg;

    alias void* Arg;
    alias va_list ArgList;
}
else version (LDC)
{
    import ocean.core.Vararg;

    alias void* Arg;
    alias va_list ArgList;
}
else version (DigitalMars)
{
    import ocean.core.Vararg;

    alias void* Arg;
    alias va_list ArgList;

    version (X86_64) version = DigitalMarsX64;
}
else
{
    alias void* Arg;
    alias void* ArgList;
}

/*******************************************************************************

    Construct StaticTrace when this module is loaded

*******************************************************************************/

/// global static trace instance
public static StaticSyncPrint StaticTrace;

static this()
{
    StaticTrace = new StaticSyncPrint(Cerr.stream);
}



/*******************************************************************************

    Static trace class - internal only

*******************************************************************************/

public class StaticSyncPrint
{
    /***************************************************************************

        Buffer used for string formatting.

    ***************************************************************************/

    private mstring formatted;

    /***************************************************************************

        Find Fruct to find the \n's

    ***************************************************************************/

    private typeof(find(cstring.init)) finder; 

    /***************************************************************************

        Outputstream to use.

    ***************************************************************************/

    private OutputStream output;

    /***************************************************************************

        C'tor

        Params:
            output = Outputstream to use.

    ***************************************************************************/

    public this ( OutputStream output )
    {
        this.finder = find(cast(cstring) "\n");
        this.output = output;
    }

    /***************************************************************************

        Outputs a string to the console.

        Params:
            fmt = format string (same format as tanog.util.log.Trace)
            ... = variadic list of values referenced in format string

        Returns:
            this instance for method chaining

    ***************************************************************************/

    public typeof(this) format ( cstring fmt, ... )
    {
        formatted.length = 0;
        size_t sink ( cstring s )
        {
            formatted ~= s;
            return s.length;
        }

        Layout!(char).instance()(&sink, _arguments, _argptr, fmt);

        size_t lines = 0;
        istring nl = "";

        foreach ( token; this.finder.tokens(this.formatted) )
        {
            with ( this.output )
            {
                write(nl);
                write(token);
                write(Terminal.CSI);
                write(Terminal.ERASE_REST_OF_LINE);
                flush();
            }

            nl = "\n";

            lines++;
        }

        with (Terminal) if ( lines == 1 )
        {
            with ( this.output )
            {
                write(CSI);
                write("0");
                write(HORIZONTAL_MOVE_CURSOR);
                flush();
            }
        }
        else with ( this.output )
        {
            formatted.length = 0;
            Layout!(char).instance()(&sink, "{}", lines - 1);

            write(CSI);
            write(formatted);
            write(LINE_UP);
            flush();
        }

        return this;
    }


    /***************************************************************************

        Flushes the output to the console.

        Returns:
            this instance for method chaining

    ***************************************************************************/

    public typeof(this) flush ( )
    {
        this.output.flush();
        return this;
    }
}

