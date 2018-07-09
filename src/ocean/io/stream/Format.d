/*******************************************************************************

        Copyright:
            Copyright (c) 2007 Kris Bell.
            Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
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

        deprecated("Use the 'format' method instead, or 'flush'")
        public alias print      opCall;         /// opCall -> print
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

                Construct a FormatOutput instance, tying the provided stream
                to a layout formatter.

        **********************************************************************/

        deprecated("Using Layout with this class is deprecated - Remove the first argument at call site")
        this (Layout!(T) convert, OutputStream output, Const!(T)[] eol = Eol)
        {
                verify(convert !is null);
                verify(output !is null);

                this.convert = convert;
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

        /// Used by derived classes to avoid deprecations - deprecated, remove in v4.0.0
        protected final void _transitional_format (Const!(T)[] fmt, TypeInfo[] arguments, ArgList args)
        {
            this.convert(&this.emit, arguments, args, fmt);
        }

        /**********************************************************************

                Layout using the provided formatting specification. Varargs
                pass-through version.

        **********************************************************************/

        deprecated("RTTI-specific function is deprecated, use a Formatter-compatible API")
        final FormatOutput format (Const!(T)[] fmt, TypeInfo[] arguments, ArgList args)
        {
            convert (&emit, arguments, args, fmt);

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

        /**********************************************************************

                Layout using the provided formatting specification. Varargs
                pass-through version.

        **********************************************************************/
        deprecated("RTTI-specific function is deprecated, use a Formatter-compatible API")
        final FormatOutput formatln (Const!(T)[] fmt, TypeInfo[] arguments, ArgList args)
        {
            convert (&emit, arguments, args, fmt);

            return newline;
        }

        /**********************************************************************

                Unformatted layout, with commas inserted between args.
                Currently supports a maximum of 24 arguments.

        **********************************************************************/

        deprecated("Use the 'format' method instead, or 'flush'")
        final FormatOutput print ( ... )
        {
                static slice =  "{}, {}, {}, {}, {}, {}, {}, {}, " ~
                                          "{}, {}, {}, {}, {}, {}, {}, {}, " ~
                                          "{}, {}, {}, {}, {}, {}, {}, {}, ";

                verify(_arguments.length <= slice.length/4,
                        "FormatOutput :: too many arguments");

                if (_arguments.length == 0)
                    sink.flush;
                else
                {
                    convert (&emit, _arguments, _argptr, slice[0 .. _arguments.length * 4 - 2]);
                }
                return this;
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

                Return the associated Layout.

        **********************************************************************/

        deprecated("FormatOutput will stop using Layout and switch to Formatter in v4.0.0")
        final Layout!(T) layout ()
        {
                return convert;
        }

        /**********************************************************************

                Set the associated Layout.

        **********************************************************************/
        deprecated("FormatOutput will stop using Layout and switch to Formatter in v4.0.0")
        final FormatOutput layout (Layout!(T) layout)
        {
                convert = layout;
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
}
