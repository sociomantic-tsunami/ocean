/*******************************************************************************

    Console output

    Console output classes extending those in ocean.io.Stdout.

    Additional features are:
        * clearline() method which erases the rest of the line
        * bold() method which sets the text output to bold / bright mode
        * text colour setting methods

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.Stdout;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.io.Terminal;

import ocean.io.device.Conduit;

import ocean.io.stream.Format;

import ocean.io.Console;

import ocean.text.convert.Layout_tango;



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

    Static output instances

*******************************************************************************/

public static TerminalOutput!(char) Stdout; /// Global standard output.
public static TerminalOutput!(char) Stderr; /// Global error output.
public alias Stdout stdout; /// Alternative.
public alias Stderr stderr; /// Alternative.

static this ( )
{
    // note that a static-ctor inside Layout fails
    // to be invoked before this is executed (bug)
    auto layout = Layout!(char).instance;

    Stdout = new TerminalOutput!(char)(layout, Cout.stream);
    Stderr = new TerminalOutput!(char)(layout, Cerr.stream);

    Stdout.flush = !Cout.redirected;
    Stdout.redirect = Cout.redirected;
    Stderr.flush = !Cerr.redirected;
    Stderr.redirect = Cerr.redirected;
}



/*******************************************************************************

    Terminal output class.

    Derived from FormatOutput in ocean.io.stream.Format, and reimplements
    methods to return typeof(this), for easy method chaining. Note that not all
    methods are reimplemented in this way, only those which we commonly use.
    Others may be added if needed.

*******************************************************************************/

public class TerminalOutput ( T ) : FormatOutput!(T)
{
    /***************************************************************************

        Template method to output a CSI sequence

        Template_Params:
            seq = csi sequence to output

    ***************************************************************************/

    private typeof(this) csiSeq ( istring seq ) ( )
    {
        if ( !this.redirect )
        {
            this.sink.write(Terminal.CSI);
            this.sink.write(seq);
        }
        return this;
    }


    /***************************************************************************

        True if it's redirected.

    ***************************************************************************/

    protected bool redirect;


    /***************************************************************************

        Construct a FormatOutput instance, tying the provided stream to a layout
        formatter.

    ***************************************************************************/

    public this (OutputStream output, Immut!(T)[] eol = Eol)
    {
        this (Layout!(T).instance, output, eol);
    }


    /***************************************************************************

        Construct a FormatOutput instance, tying the provided stream to a layout
        formatter.

    ***************************************************************************/

    public this (Layout!(T) convert, OutputStream output, Immut!(T)[] eol = Eol)
    {
        super(convert, output, eol);
    }


    /***************************************************************************

        Layout using the provided formatting specification.

    ***************************************************************************/

    public typeof(this) format ( Const!(T)[] fmt, ... )
    {
        version (DigitalMarsX64)
        {
            va_list ap;

            va_start(ap, __va_argsave);

            scope(exit) va_end(ap);

            super.format(fmt, _arguments, ap);
        }
        else
            super.format(fmt, _arguments, _argptr);

        return this;
    }


    /***************************************************************************

        Layout using the provided formatting specification. Varargs pass-through
        version.

    ***************************************************************************/

    public typeof(this) format (Const!(T)[] fmt, TypeInfo[] arguments, ArgList args)
    {
        super.format(fmt, arguments, args);
        return this;
    }


    /***************************************************************************

        Layout using the provided formatting specification, and append a
        newline.

    ***************************************************************************/

    public typeof(this) formatln ( Const!(T)[] fmt, ... )
    {
        version (DigitalMarsX64)
        {
            va_list ap;

            va_start(ap, __va_argsave);

            scope(exit) va_end(ap);

            super.formatln(fmt, _arguments, ap);
        }
        else
            super.formatln(fmt, _arguments, _argptr);

        return this;
    }


    /***************************************************************************

        Layout using the provided formatting specification, and append a
        newline. Varargs pass-through version.

    ***************************************************************************/

    public typeof(this) formatln (Const!(T)[] fmt, TypeInfo[] arguments, ArgList args)
    {
        super.formatln(fmt, arguments, args);
        return this;
    }


    /***************************************************************************

        Output a newline and optionally flush.

    ***************************************************************************/

    public typeof(this) newline ( )
    {
        super.newline;
        return this;
    }


    /***************************************************************************

        Emit/purge buffered content.

    ***************************************************************************/

    public override typeof(this) flush ( )
    {
        super.flush;
        return this;
    }


    /***************************************************************************

        Control implicit flushing of newline(), where true enables flushing. An
        explicit flush() will always flush the output.

    ***************************************************************************/

    public typeof(this) flush ( bool yes )
    {
        super.flush(yes);
        return this;
    }


    /***************************************************************************

        Output terminal control characters to clear the rest of the line. Note:
        does not flush. (Flush explicitly if you need to.)

    ***************************************************************************/

    public typeof(this) clearline ( )
    {
        if ( this.redirect )
        {
            return this.newline;
        }
        return this.csiSeq!(Terminal.ERASE_REST_OF_LINE);
    }


    /***************************************************************************

        Sets / unsets bold text output.

        Params:
            on = bold on / off

    ***************************************************************************/

    public typeof(this) bold ( bool on = true )
    {
        return on ? this.csiSeq!(Terminal.BOLD) : this.csiSeq!(Terminal.NON_BOLD);
    }


    /***************************************************************************

        Move the current cursor position to the last row of the terminal. This
        method adapts to changes in the size of the terminal.

    ***************************************************************************/

    public typeof(this) endrow ( )
    {
        auto layout = Layout!(char).instance;
        this.sink.write(layout("{}{};1H", Terminal.CSI, Terminal.rows));
        return this;
    }


    /***************************************************************************

        Carriage return (sends cursor back to the start of the line).

    ***************************************************************************/

    public alias csiSeq!("0" ~ Terminal.HORIZONTAL_MOVE_CURSOR) cr;


    /***************************************************************************

        Move the cursor up a line

    ***************************************************************************/

    public alias csiSeq!("1" ~ Terminal.CURSOR_UP)      up;


    /***************************************************************************

        Foreground colour changing methods.

    ***************************************************************************/

    public alias csiSeq!(Terminal.Foreground.DEFAULT)   default_colour;
    public alias csiSeq!(Terminal.Foreground.BLACK)     black;
    public alias csiSeq!(Terminal.Foreground.RED)       red;
    public alias csiSeq!(Terminal.Foreground.GREEN)     green;
    public alias csiSeq!(Terminal.Foreground.YELLOW)    yellow;
    public alias csiSeq!(Terminal.Foreground.BLUE)      blue;
    public alias csiSeq!(Terminal.Foreground.MAGENTA)   magenta;
    public alias csiSeq!(Terminal.Foreground.CYAN)      cyan;
    public alias csiSeq!(Terminal.Foreground.WHITE)     white;


    /***************************************************************************

        Background colour changing methods.

    ***************************************************************************/

    public alias csiSeq!(Terminal.Background.DEFAULT)   default_bg;
    public alias csiSeq!(Terminal.Background.BLACK)     black_bg;
    public alias csiSeq!(Terminal.Background.RED)       red_bg;
    public alias csiSeq!(Terminal.Background.GREEN)     green_bg;
    public alias csiSeq!(Terminal.Background.YELLOW)    yellow_bg;
    public alias csiSeq!(Terminal.Background.BLUE)      blue_bg;
    public alias csiSeq!(Terminal.Background.MAGENTA)   magenta_bg;
    public alias csiSeq!(Terminal.Background.CYAN)      cyan_bg;
    public alias csiSeq!(Terminal.Background.WHITE)     white_bg;


    /***************************************************************************

        Foreground text colour scope class. Resets the default text colour, if
        it has been changed, when scope exits.

    ***************************************************************************/

    public scope class TextColour
    {
        /***********************************************************************

            Flag set to true when this instance has modified the text colour.

        ***********************************************************************/

        private bool colour_set;


        /***********************************************************************

            Flag set to true when this instance has modified the text boldness.

        ***********************************************************************/

        private bool bold_set;


        /***********************************************************************

            Destructor. Resets any modified text settings.

        ***********************************************************************/

        ~this ( )
        {
            if ( this.colour_set )
            {
                this.outer.default_colour;
            }

            if ( this.bold_set )
            {
                this.outer.bold(false);
            }
        }


        /***********************************************************************

            Sets the text colour and optionally boldness.

            Template_Params:
                method = name of outer class method to call to set the colour

            Params:
                bold = text boldness

        ***********************************************************************/

        private void setCol ( istring method ) ( bool bold = false )
        {
            this.colour_set = true;
            mixin("this.outer." ~ method ~ ";");

            if ( bold )
            {
                this.bold_set = true;
                this.outer.bold;
            }
        }


        /***********************************************************************

            Colour setting methods (all aliases of setCol(), above).

        ***********************************************************************/

        public alias setCol!("black") black;
        public alias setCol!("red") red;
        public alias setCol!("green") green;
        public alias setCol!("yellow") yellow;
        public alias setCol!("blue") blue;
        public alias setCol!("magenta") magenta;
        public alias setCol!("cyan") cyan;
        public alias setCol!("white") white;
    }


    /***************************************************************************

        Background colour scope class. Resets the default background colour, if
        it has been changed, when scope exits.

    ***************************************************************************/

    public scope class BackgroundColour
    {
        /***********************************************************************

            Flag set to true when this instance has modified the background
            colour.

        ***********************************************************************/

        private bool colour_set;


        /***********************************************************************

            Destructor. Resets any modified text settings.

        ***********************************************************************/

        ~this ( )
        {
            if ( this.colour_set )
            {
                this.outer.default_bg;
            }
        }


        /***********************************************************************

            Sets the background colour.

            Template_Params:
                method = name of outer class method to call to set the colour

        ***********************************************************************/

        private void setCol ( istring method ) ( )
        {
            this.colour_set = true;
            mixin("this.outer." ~ method ~ ";");
        }


        /***********************************************************************

            Colour setting methods (all aliases of setCol(), above).

        ***********************************************************************/

        public alias setCol!("black_bg") black;
        public alias setCol!("red_bg") red;
        public alias setCol!("green_bg") green;
        public alias setCol!("yellow_bg") yellow;
        public alias setCol!("blue_bg") blue;
        public alias setCol!("magenta_bg") magenta;
        public alias setCol!("cyan_bg") cyan;
        public alias setCol!("white_bg") white;
    }
}
