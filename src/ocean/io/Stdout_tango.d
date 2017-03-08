/*******************************************************************************

    Standard, global formatters for console output. If you don't need
    formatted output or unicode translation, consider using the module
    ocean.io.Console directly. If you need to format, but not output
    to console, consider ocean.text.convert.Format instead.

    Stdout &amp; Stderr expose this style of usage:
    ---
    Stdout ("hello");                    // => hello
    Stdout (1);                          // => 1
    Stdout (3.14);                       // => 3.14
    Stdout ('b');                        // => b
    Stdout (1, 2, 3);                    // => 1, 2, 3
    Stdout ("abc", 1, 2, 3);             // => abc, 1, 2, 3
    Stdout ("abc", 1, 2) ("foo");        // => abc, 1, 2foo
    Stdout ("abc") ("def") (3.14);       // => abcdef3.14

    Stdout.format ("abc {}", 1);         // => abc 1
    Stdout.format ("abc {}:{}", 1, 2);   // => abc 1:2
    Stdout.format ("abc {1}:{0}", 1, 2); // => abc 2:1
    Stdout.format ("abc ", 1);           // => abc
    ---

    Note that the last example does not throw an exception. There
    are several use-cases where dropping an argument is legitimate,
    so we're currently not enforcing any particular trap mechanism.

    Flushing the output is achieved through the flush() method, or
    via an empty pair of parens:
    ---
    Stdout ("hello world") ();
    Stdout ("hello world").flush;

    Stdout.format ("hello {}", "world") ();
    Stdout.format ("hello {}", "world").flush;
    ---

    Special character sequences, such as "\n", are written directly to
    the output without any translation (though an output-filter could
    be inserted to perform translation as required). Platform-specific
    newlines are generated instead via the newline() method, which also
    flushes the output when configured to do so:
    ---
    Stdout ("hello ") ("world").newline;
    Stdout.format ("hello {}", "world").newline;
    Stdout.formatln ("hello {}", "world");
    ---

    Stdout.layout can also be used for formatting without outputting
    to the console such as in the following example:
    ---
    char[] str = Stdout.layout.convert("{} and {}", 42, "abc");
    //str is "42 and abc"
    ---
    This can be useful if you already have Stdout imported.

    Note also that the output-stream in use is exposed by these
    global instances ~ this can be leveraged, for instance, to copy a
    file to the standard output:
    ---
    Stdout.copy (new File ("myfile"));
    ---

    Note that Stdout is *not* intended to be thread-safe. Use either
    ocean.util.log.Trace or the standard logging facilities in order
    to enable atomic console I/O.

    Copyright:
        Copyright (c) 2005 Kris Bell.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

    Version: Nov 2005: Initial release

    Authors: Kris Bell

*******************************************************************************/

deprecated module ocean.io.Stdout_tango;

import ocean.io.Console;

import ocean.io.stream.Format;

import ocean.text.convert.Layout_tango;

deprecated("Module ocean.io.Stdout_tango is deprecated, use ocean.io.Stdout instead"):

/*******************************************************************************

    Construct Stdout &amp; Stderr when this module is loaded

*******************************************************************************/

private alias FormatOutput!(char) Output;

public static Output Stdout; /// Global standard output.
public static Output Stderr; /// Global error output.
public alias Stdout  stdout; /// Alternative.
public alias Stderr  stderr; /// Alternative.

version (D_Version2)
{
    mixin(`
    shared static this ()
    {
        constructor();
    }
    `);
}
else
{
    static this ()
    {
        constructor();
    }
}

private void constructor ()
{
    // note that a static-ctor inside Layout fails
    // to be invoked before this is executed (bug)
    auto layout = Layout!(char).instance;

    Stdout = new Output (layout, Cout.stream);
    Stderr = new Output (layout, Cerr.stream);

    Stdout.flush = !Cout.redirected;
    Stderr.flush = !Cerr.redirected;
}


/******************************************************************************

 ******************************************************************************/

debug (Stdout)
{
    void main()
    {
        Stdout ("hello").newline;
        Stdout (1).newline;
        Stdout (3.14).newline;
        Stdout ('b').newline;
        Stdout ("abc") ("def") (3.14).newline;
        Stdout ("abc", 1, 2, 3).newline;
        Stdout (1, 2, 3).newline;
        Stdout (1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1).newline;

        Stdout ("abc {}{}{}", 1, 2, 3).newline;
        Stdout.format ("abc {}{}{}", 1, 2, 3).newline;
    }
}
