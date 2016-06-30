/*******************************************************************************

        Various low-level console oriented utilities

        Copyright:
            Copyright (c) 2009 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: rewritten: Nov 2009

*******************************************************************************/

module ocean.core._util.console;

// D1 has all this in runtime
version (D_Version2):

import ocean.transition;

import ocean.core._util.string;

/*******************************************************************************

        External functions

*******************************************************************************/

version (Posix)
         extern(C) ptrdiff_t write (int, in void*, size_t);


/*******************************************************************************

        Emit an integer to the console

*******************************************************************************/

extern(C) void consoleInteger (ulong i)
{
        char[25] tmp = void;

        consoleString (ulongToUtf8 (tmp, i));
}

/*******************************************************************************

        Emit a utf8 string to the console. Codepages are not supported

*******************************************************************************/

extern(C) void consoleString (cstring s)
{
        version (Posix)
                 write (2, s.ptr, s.length);
}

/*******************************************************************************

        Support for chained console (pseudo formatting) output

*******************************************************************************/

struct Console
{
        alias newline opCall;
        alias emit    opCall;

        /// emit a utf8 string to the console
        Console emit (cstring s)
        {
                consoleString (s);
                return *this;
        }

        /// emit an unsigned integer to the console
        Console emit (ulong i)
        {
                consoleInteger (i);
                return *this;
        }

        /// emit a newline to the console
        Console newline ()
        {
                version (Posix)
                         const eol = "\n";

                return emit (eol);
        }
}

public Console console;

/*******************************************************************************

*******************************************************************************/

debug (console)
{
        void main()
        {
                console ("hello world \u263a")();
        }
}
