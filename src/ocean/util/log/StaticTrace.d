/*******************************************************************************

    Static console tracer

    Static console tracer - moves the cursor back to its original position after
    printing the required text.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.log.StaticTrace;

import ocean.core.TypeConvert;
import ocean.io.Console;
import ocean.io.model.IConduit;
import ocean.io.Terminal;
import ocean.text.convert.Formatter;
import ocean.text.Search;
import ocean.meta.types.Qualifiers;


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
            Args = Tuple of arguments to format
            fmt = format string (same format as tanog.util.log.Trace)
            args = variadic list of values referenced in format string

        Returns:
            this instance for method chaining

    ***************************************************************************/

    public typeof(this) format (Args...) ( cstring fmt, Args args )
    {
        formatted.length = 0;
        assumeSafeAppend(this.formatted);

        sformat(formatted, fmt, args);

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
            assumeSafeAppend(this.formatted);
            sformat(formatted, "{}", lines - 1);

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

unittest
{
    class FakeStream : OutputStream
    {
            override size_t write (const(void)[] src) { return src.length; }
            override OutputStream copy (InputStream src, size_t max = -1) { return this; }
            override OutputStream output () { return this; }
            override long seek (long offset, Anchor anchor = Anchor.Begin) { return offset; }
            override IConduit conduit () { return null; }
            override IOStream flush () { return this; }
            override void close () {}
    }

    auto trace = new StaticSyncPrint(new FakeStream);
    trace.format("static trace says hello {}", 1);
}
