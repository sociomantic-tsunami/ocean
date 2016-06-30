/*******************************************************************************

    Module to display application information in the terminal. Does not keep
    track of any values, only puts the information to the terminal in two
    separate portions - a static portion in the bottom and a streaming portion
    on top.

    Generally, the static portion contains only a few lines used to display the
    progress/health of the application while the larger streaming portion is
    used to output logs or other application output. However, this is not a rule
    and applications are free to display whatever is needed in the static and
    streaming portions.

    Since almost all applications that use this module also use Tango's logging
    facility, a separate appender (ocean.util.log.InsertConsole) has been
    developed to allow for application logs to be correctly displayed in the
    streaming portion. The InsertConsole appender moves the cursor just above
    the static lines, creates space by scrolling-up previously displayed content
    in the streaming portion, and then "inserts" the given log message in the
    newly created space. The existing static lines are not touched during this
    process.

    The AppStatus + InsertConsole combination provides a convenient way to track
    the status of a long running command-line application in a friendly manner.
    However, there are few things that should be noted when using this module:

        1. Once content in the streaming portion scrolls past the top of the
           terminal, it cannot be retrieved by scrolling up using a mouse or the
           scrollbar.
        2. When redirecting to a file from the command-line using ">", only the
           contents of the streaming portion will be sent to the file, and not
           the contents of the static portion.
        3. Content sent to the top streaming portion should not have tab
           characters or embedded newline characters. These would cause the
           streaming portion to spill over into the static portion, thus messing
           up the display.
        4. Regular Stdout/Stderr calls should not be used as this would also
           cause the streaming portion to spill over into the static portion.

    Usage Example:

    ---

        const number_of_static_lines = 2;

        AppStatus app_status = new AppStatus("test", Version.revision,
            Version.build_date, Version.build_author, clock,
            number_of_static_lines);

        ulong c1, c2, c3, c4;

        app_status.formatStaticLine(0, "{} count1, {} count2", c1, c2);
        app_status.formatStaticLine(1, "{} count3, {} count4", c3, c4);

        app_status.displayStaticLines();

        app_status.displayStreamingLine("{} count5, {} count6", c5, c6);

    ---

    The colour and boldness of the static/streaming lines can be controlled in
    the following manner:

    ---

        app_status.bold.red
            .formatStaticLine(0, "this static line will be in red and bold");
        app_status.bold(false).green
            .formatStaticLine(1, "and this one will be in green and not bold");

        app_status.blue.displayStreamingLine("here's a blue streaming line");

    ---

    Tip: look for convenience aliases of other supported colours within the class
         body below

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.console.AppStatus;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.io.Terminal;

import ocean.time.model.IMicrosecondsClock;
import ocean.time.MicrosecondsClock;

import ocean.core.Array;

import ocean.core.TypeConvert;

import ocean.core.StructConverter;

import ocean.io.Stdout;

import ocean.text.convert.Layout;

import ocean.util.log.InsertConsole;

import ocean.util.log.layout.LayoutMessageOnly;

import ocean.stdc.math: lroundf;

import core.memory;

import ocean.stdc.stdarg;

import ocean.stdc.stdlib: div;

import ocean.stdc.time: clock_t, clock, tm, time_t, time;

import ocean.text.convert.Format;

import ocean.util.log.Log;

import ocean.io.Console;



/*******************************************************************************

    Module to display static and streaming lines in the terminal.

*******************************************************************************/

public class AppStatus
{
    /***************************************************************************

        Message buffer used for formatting streaming lines. The buffer is public
        so that, if more complex formatting is needed than is provided by the
        displayStreamingLine() methods, then it can be used externally to format
        any required messages. The version of displayStreamingLine() with no
        arguments can then be called to print the contents of the buffer.

    ***************************************************************************/

    public StringLayout!(char) msg;


    /***************************************************************************

        Alias for system clock function.

    ***************************************************************************/

    private alias .clock system_clock;


    /***************************************************************************

        Convenience aliases for derived classes.

    ***************************************************************************/

    protected alias .TerminalOutput!(char) TerminalOutput;


    /***************************************************************************

        One instance of the display properties of a line.

    ***************************************************************************/

    private struct DisplayProperties
    {
        /***********************************************************************

            String specifying the foreground colour (this is a string from the
            Terminal.Foreground struct in `ocean.io.Terminal` and not a string
            like "red").

        ***********************************************************************/

        char[] fg_colour;


        /***********************************************************************

            String specifying the background colour (this is a string from the
            Terminal.Background struct in `ocean.io.Terminal` and not a string
            like "red").

        ***********************************************************************/

        char[] bg_colour;


        /***********************************************************************

            Boolean value set to true if the line is in bold, false otherwise.

        ***********************************************************************/

        bool is_bold;
    }


    /***************************************************************************

        The currently configured display properties of a line. These properties
        will be used when displaying the next streaming line or when formatting
        the next static line.

    ***************************************************************************/

    private DisplayProperties current_display_props;


    /***************************************************************************

        start time of the program. saved when first started and compared with
        the current time to get the runtime of the program

    ***************************************************************************/

    private time_t start_time;


    /***************************************************************************

        Saved value of the total time used by this application. Used to
        calculate the cpu load of this program

    ***************************************************************************/

    private clock_t ticks = -1;


    /***************************************************************************

        Expected milliseconds between calls to getCpuUsage. Needed to calculate
        the cpu usage correctly. Defaults to 1000ms.

    ***************************************************************************/

    private ulong ms_between_calls;


    /***************************************************************************

        private buffer for storing and formatting the static lines to display

    ***************************************************************************/

    private char[][] static_lines;


    /***************************************************************************

        Buffer containing the display properties of each static line.

    ***************************************************************************/

    private DisplayProperties[] static_lines_display_props;


    /***************************************************************************

        the name of the current application

    ***************************************************************************/

    private char[] app_name;


    /***************************************************************************

        the version of the current application

    ***************************************************************************/

    private char[] app_version;


    /***************************************************************************

        the build date of the current application

    ***************************************************************************/

    private char[] app_build_date;


    /***************************************************************************

        who built the current application

    ***************************************************************************/

    private char[] app_build_author;


    /***************************************************************************

        buffer used for the header line

    ***************************************************************************/

    private char[] heading_line;


    /***************************************************************************

        buffer used for the footer

    ***************************************************************************/

    private char[] footer_line;


    /***************************************************************************

        insert console used to display the streaming lines

    ***************************************************************************/

    private InsertConsole insert_console;


    /***************************************************************************

        saved terminal size used to check if the terminal size has changed

    ***************************************************************************/

    private int old_terminal_size;


    /***************************************************************************

        Constructor. Saves the current time as the program start time.

        Params:
            app_name = name of the application
            app_version = version of the application
            app_build_date = date the application was built
            app_build_author = who built the current build
            size = number of loglines that are to be displayed below the
                    title line
            ms_between_calls = expected milliseconds between calls to
                               getCpuUsage (defaults to 1000ms)

    ***************************************************************************/

    public this ( cstring app_name, cstring app_version, cstring app_build_date,
        cstring app_build_author, uint size, ulong ms_between_calls = 1000 )
    {
        this.app_name.copy(app_name);
        this.app_version.copy(app_version);
        this.app_build_date.copy(app_build_date);
        this.app_build_author.copy(app_build_author);
        this.start_time = time(null);
        this.static_lines.length = size;
        this.static_lines_display_props.length = size;
        this.ms_between_calls = ms_between_calls;
        this.insert_console = new InsertConsole(Cout.stream, true,
            new LayoutMessageOnly);
        this.old_terminal_size = Terminal.rows;

        this.msg = new StringLayout!(char);
    }


    /***************************************************************************

        Clear all the bottom static lines from the console (including header and
        footer).

        This method is useful for erasing the bottom static lines when there is
        nothing meaningful to be shown there anymore. This generally happens
        close to the end of an application's run, and is thus expected to be
        called only a single time.

        Note that the caller needs to make sure that the static lines are
        already displayed before calling this method, otherwise unintended lines
        might be deleted.

    ***************************************************************************/

    public void eraseStaticLines ( )
    {
        // Add +2: One for header and one for footer
        for (size_t i = 0; i < this.static_lines.length + 2; i++)
        {
            Stdout.clearline.newline;
        }

        // Each iteration in the previous loop moves the cursor one line to
        // the bottom. We need to return it to the right position again.
        // We can't combine both loops or we will be clearing and overwriting
        // the same first line over and over.
        for (size_t i = 0; i < this.static_lines.length + 2; i++)
        {
            Stdout.up;
        }

        Stdout.flush;
    }


    /***************************************************************************

        Resizes the number of lines in the app status static display and clears
        the current content of the static lines. Also resets the cursor
        position so that the static lines are still at the bottom of the
        display.

        Note:
            A decrease in the number of static lines will result in one or more
            blank lines appearing in the upper streaming portion of the output.
            This is because on reducing the number of static lines, more space
            is created for the streaming portion, but without anything to be
            displayed there. The number of blank lines thus created will be
            equal to the amount by which the number of static lines are being
            reduced.

        Params:
            size = number of loglines that are to be displayed below the
                    title line

    ***************************************************************************/

    public void num_static_lines ( size_t size )
    {
        this.resetStaticLines();

        if ( Cout.redirected )
        {
            this.static_lines.length = size;

            this.static_lines_display_props.length = size;

            return;
        }

        if ( this.static_lines.length > size )
        {
            // The number of static lines are being reduced

            // First remove the already displayed static lines from the console
            this.resetCursorPosition();

            // ...and then remove the static lines header
            Stdout.clearline.cr.flush.up;
        }
        else if ( this.static_lines.length < size )
        {
            // The number of static lines are being increased

            // First remove the static lines header
            Stdout.clearline.cr.flush.up;

            // ...and then push up the streaming portion on the top by
            //        the new number of static lines
            //        + the static lines header
            //        + the static lines footer
            for ( auto i = 0; i < (size + 2); ++i )
            {
                Stdout.formatln("");
            }
        }

        this.static_lines.length = size;

        this.static_lines_display_props.length = size;

        this.resetCursorPosition();
    }


    /***************************************************************************

        Gets the current number of lines in the app status static display.

        Returns:
            The current number of lines in the static bottom portion of the
            split console.

    ***************************************************************************/

    public size_t num_static_lines ( )
    {
        return this.static_lines.length;
    }


    /***************************************************************************

        Print the current static lines set by the calling program to Stdout
        with a title line showing the current time, runtime, and memory and cpu
        usage and a footer line showing the version information.

        Check if the size of the terminal has changed and if it has move the
        cursor to the end of the terminal.

        Print a blank line for each logline and one for the footer. Then print
        the footer and move up. Then in reverse order print a line and move the
        cursor up. When all the lines have been printed, print the heading line.

        Note: This method doesn't do anything if the console output is being
              redirected from the command-line.

    ***************************************************************************/

    public void displayStaticLines ( )
    {
        if ( Cout.redirected )
        {
            return;
        }

        this.checkCursorPosition();

        foreach ( line; this.static_lines )
        {
            Stdout.formatln("");
        }
        Stdout.formatln("");

        this.printVersionInformation();
        Stdout.clearline.cr.flush.up;

        foreach_reverse ( index, line; this.static_lines )
        {
            if ( line.length )
            {
                this.applyDisplayProps(this.static_lines_display_props[index]);

                Stdout.format(this.truncateLength(line));
            }
            Stdout.clearline.cr.flush.up;
        }

        this.printHeadingLine();
    }


    /***************************************************************************

        Convenience aliases for setting the foreground colour.

    ***************************************************************************/

    public alias saveColour!(true,  Terminal.Foreground.DEFAULT) default_colour;
    public alias saveColour!(true,  Terminal.Foreground.BLACK)   black;
    public alias saveColour!(true,  Terminal.Foreground.RED)     red;
    public alias saveColour!(true,  Terminal.Foreground.GREEN)   green;
    public alias saveColour!(true,  Terminal.Foreground.YELLOW)  yellow;
    public alias saveColour!(true,  Terminal.Foreground.BLUE)    blue;
    public alias saveColour!(true,  Terminal.Foreground.MAGENTA) magenta;
    public alias saveColour!(true,  Terminal.Foreground.CYAN)    cyan;
    public alias saveColour!(true,  Terminal.Foreground.WHITE)   white;


    /***************************************************************************

        Convenience aliases for setting the background colour.

    ***************************************************************************/

    public alias saveColour!(false, Terminal.Background.DEFAULT) default_bg;
    public alias saveColour!(false, Terminal.Background.BLACK)   black_bg;
    public alias saveColour!(false, Terminal.Background.RED)     red_bg;
    public alias saveColour!(false, Terminal.Background.GREEN)   green_bg;
    public alias saveColour!(false, Terminal.Background.YELLOW)  yellow_bg;
    public alias saveColour!(false, Terminal.Background.BLUE)    blue_bg;
    public alias saveColour!(false, Terminal.Background.MAGENTA) magenta_bg;
    public alias saveColour!(false, Terminal.Background.CYAN)    cyan_bg;
    public alias saveColour!(false, Terminal.Background.WHITE)   white_bg;


    /***************************************************************************

        Sets / unsets the configured boldness. This setting will be used when
        displaying the next streaming line or when formatting the next static
        line.

        Params:
            is_bold = true if bold is desired, false otherwise

    ***************************************************************************/

    public typeof(this) bold ( bool is_bold = true )
    {
        this.current_display_props.is_bold = is_bold;

        return this;
    }


    /***************************************************************************

        Format one of the static lines. The application can set the number of
        static lines either when constructing this module or by calling the
        'num_static_lines' method.
        This method is then used to format the contents of the static lines.

        Params:
            index = the index of the static line to format
            format = format string of the message
            args = list of any extra arguments for the message

        Returns:
            this object for method chaining

    ***************************************************************************/

    public typeof(this) formatStaticLine ( uint index, cstring format, ... )
    {
        assert( index < this.static_lines.length, "adding too many static lines" );

        this.static_lines[index].length = 0;
        Format.vformat(this.static_lines[index], format, _arguments, _argptr);

        structConvert!(DisplayProperties)(
            this.current_display_props,
            this.static_lines_display_props[index]
        );

        return this;
    }


    /***************************************************************************

        Print a formatted streaming line above the static lines.

        Params:
            format = format string of the streaming line
            ... = list of any extra arguments for the streaming line

        Returns:
            this object for method chaining

    ***************************************************************************/

    public typeof(this) displayStreamingLine ( cstring format, ... )
    {
        return this.displayStreamingLine(format, _arguments, _argptr);
    }


    /***************************************************************************

        Print a formatted streaming line above the static lines.

        Params:
            format = format string of the streaming line
            arguments = typeinfos of any extra arguments for the streaming line
            argptr = pointer to list of extra arguments for the streaming line

        Returns:
            this object for method chaining

    ***************************************************************************/

    public typeof(this) displayStreamingLine ( cstring format,
        TypeInfo[] arguments, va_list argptr )
    {
        this.msg.length = 0;
        this.msg.vformat(format, arguments, argptr);

        return this.displayStreamingLine();
    }


    /***************************************************************************

        Print the contents of this.msg as streaming line above the static lines.

        Returns:
            this object for method chaining

    ***************************************************************************/

    public typeof(this) displayStreamingLine ( )
    {
        if ( Cout.redirected )
        {
            Cout.append(this.msg[]).newline.flush;

            return this;
        }

        Hierarchy host_;
        Level level_;
        LogEvent event;
        event.set(host_, level_, this.msg[], "");

        this.applyDisplayProps(this.current_display_props);

        this.insert_console.append(event);

        return this;
    }


    /***************************************************************************

        Print a list of arguments as a streaming line above the static lines.
        Each argument is printed using its default format.

        Params:
            ... = list of arguments for the streaming line

        Returns:
            this object for method chaining

    ***************************************************************************/

    public typeof(this) displayStreamingLineArgs ( ... )
    {
        return this.displayStreamingLineArgs(_arguments, _argptr);
    }


    /***************************************************************************

        Print a list of arguments as a streaming line above the static lines.
        Each argument is printed using its default format.

        Params:
            arguments = typeinfos of arguments for the streaming line
            argptr = pointer to list of arguments for the streaming line

        Returns:
            this object for method chaining

    ***************************************************************************/

    public typeof(this) displayStreamingLineArgs ( TypeInfo[] arguments,
        va_list argptr )
    {
        this.msg.length = 0;
        this.msg.vwrite(arguments, argptr);

        return this.displayStreamingLine();
    }


    /***************************************************************************

        Get the current uptime for the program using the start time and current
        time. Then divide the uptime in to weeks, days, hours, minutes, and
        seconds.

        Params:
            weeks = weeks of runtime
            days = days of runtime
            hours = hours of runtime
            mins = minutes of runtime
            secs = seconds of runtime

    ***************************************************************************/

    public void getUptime ( out uint weeks, out uint days, out uint hours,
        out uint mins, out uint secs )
    {
        time_t _uptime = time(null) - this.start_time;
        assert (_uptime < int.max && _uptime > int.min);
        uint uptime = castFrom!(long).to!(int)(_uptime);

        uint uptimeFract ( uint denom )
        {
            with ( div(uptime, denom) )
            {
                uptime = quot;
                return rem;
            }
        }

        secs = uptimeFract(60);
        mins = uptimeFract(60);
        hours = uptimeFract(24);
        days = uptimeFract(7);
        weeks = uptime;
    }


    /***************************************************************************

        Calculate the current memory usage of this program using the GC stats

        Params:
            mem_allocated = the amount of memory currently allocated
            mem_free = the amount of allocated memory that is currently free

        Returns:
            true if the memory usage was properly gathered, false if is not
            available.

    ***************************************************************************/

    public bool getMemoryUsage ( out float mem_allocated, out float mem_free )
    {
        const float Mb = 1024 * 1024;
        size_t used, free;
        ocean.transition.gc_usage(used, free);

        if (used == 0 && free == 0)
            return false;

        mem_allocated = cast(float)(used + free) / Mb;
        mem_free = cast(float)free / Mb;

        return true;
    }


    /***************************************************************************

        Get the current cpu usage of this program. Uses the clock() method
        that returns the total current time used by this program. This is then
        used to compute the current cpu load of this program.

        Params:
            usage = the current CPU usage of this program as a percentage

    ***************************************************************************/

    public void getCpuUsage ( out long usage )
    {
        clock_t ticks = system_clock();
        if ( this.ticks >= 0 )
        {
            usage =
                lroundf((ticks - this.ticks) / (this.ms_between_calls * 10.0f));
        }
        this.ticks = ticks;
    }


    /***************************************************************************

        Print the heading line. Includes the current time, runtime, and memory
        and cpu usage of this application (prints in bold).

    ***************************************************************************/

    private void printHeadingLine ( )
    {
        ulong us; // unused
        auto dt = MicrosecondsClock.toDateTime(MicrosecondsClock.now(), us);

        this.heading_line.length = 0;

        Format.format(this.heading_line, "[{:d2}/{:d2}/{:d2} "
            "{:d2}:{:d2}:{:d2}] {}", dt.date.day, dt.date.month, dt.date.year,
            dt.time.hours, dt.time.minutes, dt.time.seconds, this.app_name);

        this.formatUptime();
        this.formatMemoryUsage();
        this.formatCpuUsage();

        Stdout.default_colour.default_bg.bold(true)
            .format(this.truncateLength(this.heading_line)).bold(false)
            .clearline.cr.flush;
    }


    /***************************************************************************

        Format the memory usage for the current program to using the
        GC stats to calculate current usage (if available).

    ***************************************************************************/

    private void formatMemoryUsage ( )
    {
        float mem_allocated, mem_free;

        bool stats_available = this.getMemoryUsage(mem_allocated, mem_free);

        if (stats_available)
        {
            Format.format(this.heading_line,
                " Memory: Used {}Mb/Free {}Mb", mem_allocated, mem_free);
        }
        else
        {
            Format.format(this.heading_line, " Memory: n/a");
        }
    }


    /***************************************************************************

        Format the current uptime for the current program.

    ***************************************************************************/

    private void formatUptime ( )
    {
        uint weeks, days, hours, mins, secs;
        this.getUptime(weeks, days, hours, mins, secs);
        Format.format(this.heading_line, " Uptime: {}w{:d1}d{:d2}:"
            "{:d2}:{:d2}", weeks, days, hours, mins, secs);
    }


    /***************************************************************************

        Format the current cpu usage of this program.

    ***************************************************************************/

    private void formatCpuUsage ( )
    {
        long usage = 0;
        this.getCpuUsage(usage);
        Format.format(this.heading_line, " CPU: {}%", usage);
    }


    /***************************************************************************

        Print the version and build information for this application (prints in
        bold).

        Additional text may be printed at this point by sub-classes which
        override the protected printExtraVersionInformation(). This method is
        only called if there are > 0 character remaining on the terminal line
        after the standard version info has been displayed. Note that the sub-
        class is responsible for making sure that any extra text printed does
        not exceed the specified number of characters (presumably by calling
        truncateLength()).

    ***************************************************************************/

    private void printVersionInformation ( )
    {
        this.footer_line.length = 0;

        Format.format(this.footer_line, "Version {} built on {} by {}",
            this.app_version, this.app_build_date, this.app_build_author);

        Stdout.default_colour.default_bg.bold(true)
            .format(this.truncateLength(this.footer_line)).bold(false);

        auto remaining = Terminal.columns - this.footer_line.length;
        if ( remaining )
        {
            this.footer_line.length = 0;
            this.printExtraVersionInformation(Stdout, this.footer_line,
                remaining);
        }
    }


    /***************************************************************************

        Prints additional text after the standard version info. The default
        implementation prints nothing, but sub-classes may override this method
        to provide specialised version information.

        Params:
            output = terminal output to use
            buffer = buffer which may be used for formatting (initially empty)
            max_length = the maximum number of characters remaining in the
                terminal line. It is the sub-class' responsiblity to check that
                printed text does not exceed this length, presumably by calling
                truncateLength()

    ***************************************************************************/

    protected void printExtraVersionInformation ( TerminalOutput output,
        ref char[] buffer, size_t max_length )
    {
    }


    /***************************************************************************

        Check the length of the buffer against the number of columns in the
        terminal. If the buffer is too long, set it to the terminal width.

        Params:
            buffer = buffer to check the length of

        Returns:
            the truncated buffer

    ***************************************************************************/

    protected char[] truncateLength ( ref char[] buffer )
    {
        return this.truncateLength(buffer, Terminal.columns);
    }


    /***************************************************************************

        Check the length of the buffer against the specified maximum length. If
        the buffer is too long, set it to maximum.

        Params:
            buffer = buffer to check the length of
            max = maximum number of characters in buffer

        Returns:
            the truncated buffer

    ***************************************************************************/

    protected char[] truncateLength ( ref char[] buffer, size_t max )
    {
        if ( buffer.length > max )
        {
            buffer.length = max;
        }
        return buffer;
    }


    /***************************************************************************

        Check the height of the terminal. If the height has changed, reset the
        cursor position.

    ***************************************************************************/

    private void checkCursorPosition ( )
    {
        if ( this.old_terminal_size != Terminal.rows )
        {
            this.resetCursorPosition();
        }
    }


    /***************************************************************************

        Reset the cursor position to the end of the terminal and then move the
        cursor up by the number of static lines that are being printed.

    ***************************************************************************/

    private void resetCursorPosition ( )
    {
        Stdout.endrow;
        this.old_terminal_size = Terminal.rows;

        foreach ( line; this.static_lines )
        {
            Stdout.clearline.cr.flush.up;
        }
        Stdout.clearline.cr.flush.up;
    }


    /***************************************************************************

        Reset the content of all the static lines by setting the length to 0.

    ***************************************************************************/

    private void resetStaticLines ( )
    {
        foreach ( ref line; this.static_lines )
        {
            line.length = 0;
        }
    }


    /***************************************************************************

        Save the given foreground or background colour. This colour will be used
        when displaying the next streaming line or when formatting the next
        static line.

        Template_Params:
            is_foreground = true if the given colour is for the foreground,
                            false if it is for the background
            colour = the colour to be saved (this is a string from the
                     Terminal.Foreground or Terminal.Background struct in
                     `ocean.io.Terminal` and not a string like "red")

        Returns:
            this object for method chaining

    ***************************************************************************/

    private typeof(this) saveColour ( bool is_foreground, istring colour ) ( )
    {
        static if ( is_foreground )
        {
            this.current_display_props.fg_colour.copy(colour);
        }
        else
        {
            this.current_display_props.bg_colour.copy(colour);
        }

        return this;
    }


    /***************************************************************************

        Apply the given foreground colour.

        Params:
            fg_colour = the foreground colour to be applied (this is a string
                        from the Terminal.Foreground struct in
                        `ocean.io.Terminal` and not a string like "red")

    ***************************************************************************/

    private void applyFgColour ( char[] fg_colour )
    {
        switch ( fg_colour )
        {
            case Terminal.Foreground.BLACK:
            {
                Stdout.black();
                break;
            }

            case Terminal.Foreground.RED:
            {
                Stdout.red();
                break;
            }

            case Terminal.Foreground.GREEN:
            {
                Stdout.green();
                break;
            }

            case Terminal.Foreground.YELLOW:
            {
                Stdout.yellow();
                break;
            }

            case Terminal.Foreground.BLUE:
            {
                Stdout.blue();
                break;
            }

            case Terminal.Foreground.MAGENTA:
            {
                Stdout.magenta();
                break;
            }

            case Terminal.Foreground.CYAN:
            {
                Stdout.cyan();
                break;
            }

            case Terminal.Foreground.WHITE:
            {
                Stdout.white();
                break;
            }

            case Terminal.Foreground.DEFAULT:
            default:
            {
                Stdout.default_colour();
                break;
            }
        }
    }


    /***************************************************************************

        Apply the given background colour.

        Params:
            bg_colour = the background colour to be applied (this is a string
                        from the Terminal.Background struct in
                        `ocean.io.Terminal` and not a string like "red")

    ***************************************************************************/

    private void applyBgColour ( char[] bg_colour )
    {
        switch ( bg_colour )
        {
            case Terminal.Background.BLACK:
            {
                Stdout.black_bg();
                break;
            }

            case Terminal.Background.RED:
            {
                Stdout.red_bg();
                break;
            }

            case Terminal.Background.GREEN:
            {
                Stdout.green_bg();
                break;
            }

            case Terminal.Background.YELLOW:
            {
                Stdout.yellow_bg();
                break;
            }

            case Terminal.Background.BLUE:
            {
                Stdout.blue_bg();
                break;
            }

            case Terminal.Background.MAGENTA:
            {
                Stdout.magenta_bg();
                break;
            }

            case Terminal.Background.CYAN:
            {
                Stdout.cyan_bg();
                break;
            }

            case Terminal.Background.WHITE:
            {
                Stdout.white_bg();
                break;
            }

            case Terminal.Background.DEFAULT:
            default:
            {
                Stdout.default_bg();
                break;
            }
        }
    }


    /***************************************************************************

        Apply the currently configured display properties to standard output.

        Params:
            display_props = struct instance containing the display properties to
                            be applied

    ***************************************************************************/

    private void applyDisplayProps ( DisplayProperties display_props )
    {
        this.applyFgColour(display_props.fg_colour);

        this.applyBgColour(display_props.bg_colour);

        Stdout.bold(display_props.is_bold);
    }
}

