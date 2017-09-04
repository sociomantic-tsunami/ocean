/*******************************************************************************

        Copyright:
            Copyright (c) 2007 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: Oct 2007

        Authors: Kris

*******************************************************************************/

module ocean.io.stream.Format;

import ocean.transition;

import ocean.core.Verify;

import ocean.io.device.Conduit;

import ocean.text.convert.Layout_tango;

version(DigitalMars)
{
    version(X86_64) version=DigitalMarsX64;

    import core.stdc.stdarg;
}

/*******************************************************************************

        A bridge between a Layout instance and a stream. This is used for
        the Stdout & Stderr globals, but can be used for general purpose
        buffer-formatting as desired. The Template type 'T' dictates the
        text arrangement within the target buffer ~ one of char, wchar or
        dchar (UTF8, UTF16, or UTF32).

        FormatOutput exposes this style of usage:
        ---
        auto print = new FormatOutput!(char) (...);

        print.format ("abc {}", 1);         // => abc 1
        print.format ("abc {}:{}", 1, 2);   // => abc 1:2
        print.format ("abc {1}:{0}", 1, 2); // => abc 2:1
        print.format ("abc ", 1);           // => abc
        ---

        Note that the last example does not throw an exception. There
        are several use-cases where dropping an argument is legitimate,
        so we're currently not enforcing any particular trap mechanism.

        Flushing the output is achieved through the flush() method:
        ---
        print.format ("hello {}", "world").flush;
        ---

        Special character sequences, such as "\n", are written directly to
        the output without any translation (though an output-filter could
        be inserted to perform translation as required). Platform-specific
        newlines are generated instead via the newline() method, which also
        flushes the output when configured to do so:
        ---
        print.format ("hello {}", "world").newline;
        print.formatln ("hello {}", "world");
        ---

        Note that FormatOutput is *not* intended to be thread-safe.

*******************************************************************************/

class FormatOutput(T) : OutputFilter
{
        public  alias OutputFilter.flush flush;

        private Const!(T)[]     eol;
        private Layout!(T)      convert;
        private bool            flushLines;

        public alias newline    nl;             /// nl -> newline

        protected const Eol = "\n";

        /**********************************************************************

                Construct a FormatOutput instance, tying the provided stream
                to a layout formatter.

        **********************************************************************/

        this (OutputStream output, Const!(T)[] eol = Eol)
        {
            this.convert = Layout!(T).instance;
            this.eol = eol;
            super (output);

        }

        /**********************************************************************

                Layout using the provided formatting specification.

        **********************************************************************/

        final FormatOutput format (Const!(T)[] fmt, ...)
        {
            this.convert(&this.emit, _arguments, _argptr, fmt);
            return this;
        }

        /**********************************************************************

                Layout using the provided formatting specification.

        **********************************************************************/

        final FormatOutput formatln (Const!(T)[] fmt, ...)
        {
            this.convert(&this.emit, _arguments, _argptr, fmt);
            return this.newline;
        }

        /***********************************************************************

                Output a newline and optionally flush.

        ***********************************************************************/

        final FormatOutput newline ()
        {
                sink.write (eol);
                if (flushLines)
                    sink.flush;
                return this;
        }

        /**********************************************************************

                Control implicit flushing of newline(), where true enables
                flushing. An explicit flush() will always flush the output.

        **********************************************************************/

        final FormatOutput flush (bool yes)
        {
                flushLines = yes;
                return this;
        }

        /**********************************************************************

                Return the associated output stream.

        **********************************************************************/

        final OutputStream stream ()
        {
                return sink;
        }

        /**********************************************************************

                Set the associated output stream.

        **********************************************************************/

        final FormatOutput stream (OutputStream output)
        {
                sink = output;
                return this;
        }

        /**********************************************************************

                Sink for passing to the formatter.

        **********************************************************************/

        private final size_t emit (Const!(T)[] s)
        {
                auto count = sink.write (s);
                if (count is Eof)
                    conduit.error ("FormatOutput :: unexpected Eof");
                return count;
        }

        /// Used by derived classes to avoid deprecations - deprecated, remove in v4.0.0
        protected final void _transitional_format (Const!(T)[] fmt, TypeInfo[] arguments, ArgList args)
        {
            this.convert(&this.emit, arguments, args, fmt);
        }
}
