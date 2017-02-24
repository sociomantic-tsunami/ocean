/*******************************************************************************

    Provides the current size of the terminal. Updates the values when
    the size changes.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.Terminal;

/*******************************************************************************

    C functions and structures to get terminal information

******************************************************************************/

import ocean.transition;

import core.sys.posix.signal;

debug(Term) import ocean.io.Stdout_tango;


private
{
    const TIOCGWINSZ = 0x5413;
    const SIGWINCH = 28;

    /***************************************************************************

        Function to get information about the terminal, taken from the C header

    ***************************************************************************/

    extern (C) int ioctl ( int d, int request, ... );

    struct winsize
    {
        ushort ws_row;
        ushort ws_col;
        ushort ws_xpixel;
        ushort ws_ypixel;
    }
}

/*******************************************************************************

    Struct containing information and helpers to handle terminals

    Most of the control sequences can be prefixed with a ASCII digit string
    (referred to by 'n' from now on) representing usually how often the
    command should be executed.

    Cases where this is not the case are documented.

    Example:
    -----
    // Move the cursor four lines up
    Stdout.formatln("{}4{}", Terminal.CSI, Terminal.CURSOR_UP);
    -----

******************************************************************************/

struct Terminal
{
    /***************************************************************************

        Amount of columns available in the terminal

    ***************************************************************************/

    public static ushort columns;

    /***************************************************************************

        Amount of rows (lines) available in the terminal

    ***************************************************************************/

    public static ushort rows;

    /***************************************************************************

        Start Sequence

    ***************************************************************************/

    public const istring CSI        = "\x1B[";

    /***************************************************************************

        Colours

    ***************************************************************************/

    public struct Foreground
    {
        public const istring BLACK              = "30m";
        public const istring RED                = "31m";
        public const istring GREEN              = "32m";
        public const istring YELLOW             = "33m";
        public const istring BLUE               = "34m";
        public const istring MAGENTA            = "35m";
        public const istring CYAN               = "36m";
        public const istring WHITE              = "37m";
        public const istring DEFAULT_UNDERSCORE = "38m";
        public const istring DEFAULT            = "39m";
    }

    public struct Background
    {
        public const istring BLACK              = "40m";
        public const istring RED                = "41m";
        public const istring GREEN              = "42m";
        public const istring YELLOW             = "43m";
        public const istring BLUE               = "44m";
        public const istring MAGENTA            = "45m";
        public const istring CYAN               = "46m";
        public const istring WHITE              = "47m";
        public const istring DEFAULT            = "49m";
    }


    /***************************************************************************

        Colour arrays, one for foreground and one for background colours
        Each uses the Colour enum values as index

        The enum can be useful for passing to functions in order to specify
        one of the colours defined in this module with validation
        (as opposed to accepting a generic string).

    ***************************************************************************/

    public enum Colour
    {
        Black,
        Red,
        Green,
        Yellow,
        Blue,
        Magenta,
        Cyan,
        White,
        Default
    }

    public static Immut!(istring[]) fg_colour_codes = [
        Colour.Black: Foreground.BLACK,
        Colour.Red: Foreground.RED,
        Colour.Green: Foreground.GREEN,
        Colour.Yellow: Foreground.YELLOW,
        Colour.Blue: Foreground.BLUE,
        Colour.Magenta: Foreground.MAGENTA,
        Colour.Cyan: Foreground.CYAN,
        Colour.White: Foreground.WHITE,
        Colour.Default: Foreground.DEFAULT
    ];

    public static Immut!(istring[]) bg_colour_codes = [
        Colour.Black: Background.BLACK,
        Colour.Red: Background.RED,
        Colour.Green: Background.GREEN,
        Colour.Yellow: Background.YELLOW,
        Colour.Blue: Background.BLUE,
        Colour.Magenta: Background.MAGENTA,
        Colour.Cyan: Background.CYAN,
        Colour.White: Background.WHITE,
        Colour.Default: Background.DEFAULT
    ];


    /***************************************************************************

        Bold / non-bold text.

    ***************************************************************************/

    public const istring BOLD = "1m";

    public const istring NON_BOLD = "22m";

    /***************************************************************************

        Command for cursor up

    ***************************************************************************/

    public const istring CURSOR_UP = "A";

    /***************************************************************************

        Moves the cursor n lines up and places it at the beginning of the line

    ***************************************************************************/

    public const istring LINE_UP = "F";

    /***************************************************************************

        Command for scrolling up

    ***************************************************************************/

    public const istring SCROLL_UP = "S";

    /***************************************************************************

        Command for inserting a line

    ***************************************************************************/

    public const istring INSERT_LINE = "L";

    /***************************************************************************

        Command for erasing the rest of the line

        Erases part of the line.
        If n is zero (or missing), clear from cursor to the end of the line.
        If n is one, clear from cursor to beginning of the line.
        If n is two, clear entire line. Cursor position does not change.

    ***************************************************************************/

    public const istring ERASE_REST_OF_LINE = "K";

    /***************************************************************************

        Command for erasing everything below and right of the cursor

        Clears part of the screen.
        If n is zero (or missing), clear from cursor to end of screen.
        If n is one, clear from cursor to beginning of the screen.
        If n is two, clear entire screen (and moves cursor to upper
        left on MS-DOS ANSI.SYS).

    ***************************************************************************/

    public const istring ERASE_REST_OF_SCREEN = "J";

    /***************************************************************************

        Command for hiding the cursor

    ***************************************************************************/

    public const istring HIDE_CURSOR = "?25l";

    /***************************************************************************

        Command for showing the cursor

    ***************************************************************************/

    public const istring SHOW_CURSOR = "?25h";

    /***************************************************************************

        Moves the cursor to column n.

    ***************************************************************************/

    public const istring HORIZONTAL_MOVE_CURSOR = "G";
}

/*******************************************************************************

    Static Constructor.

    Registers the signal handler for window size changes and gets the size
    the first time.

******************************************************************************/

static this ( )
{
    sigaction_t act;
    with (act)
    {
        sa_flags = SA_SIGINFO;
        sa_sigaction = &window_size_changed;
    }

    sigaction(SIGWINCH, &act, null);
    window_size_changed(0, null, null);

    debug(Term) Stdout.formatln("Termsize: {} {}", Terminal.rows, Terminal.columns);
}

/*******************************************************************************

    Signal handler.

    Updates TermInfo with the current terminal size

    Params:
        signal = the signal that caused the call (should always be SIGWINCH)(unused)
        info   = information about the signal (unused)
        data   = context information (unused)

*******************************************************************************/

extern (C) private void window_size_changed ( int signal, siginfo_t* info,
                                              void* data )
{
    winsize max;
    ioctl(0, TIOCGWINSZ, &max);

    Terminal.columns = max.ws_col;
    Terminal.rows    = max.ws_row;
}
