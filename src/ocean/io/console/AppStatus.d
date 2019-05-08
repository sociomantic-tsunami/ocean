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

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.console.AppStatus;

import core.memory;
import core.stdc.math: lroundf;
import core.stdc.stdarg;
import core.stdc.stdlib: div;
import core.stdc.time: clock_t, clock, tm, time_t, time;

import ocean.core.Array;
import ocean.core.StructConverter;
import ocean.core.TypeConvert;
import ocean.core.Verify;
import ocean.io.device.File;
import ocean.io.device.IODevice;
import ocean.io.Console;
import ocean.io.Stdout;
import ocean.io.Terminal;
import ocean.io.model.IConduit;
import ocean.text.convert.Formatter;
import ocean.time.MicrosecondsClock;
import ocean.transition;
import ocean.util.container.AppendBuffer;
import ocean.text.convert.Integer;

import ocean.util.log.Event;
import ocean.util.log.InsertConsole;
import ocean.util.log.layout.LayoutMessageOnly;
import ocean.util.log.model.ILogger;


/// Ditto
public class AppStatus
{
    /// Simplifies AppendBuffer usage by providing the sink
    private final class StringBuffer : AppendBuffer!(char)
    {
        public void sink (cstring chunk)
        {
            this ~= chunk;
        }
    }

    /***************************************************************************

        Message buffer used for formatting streaming lines. The buffer is public
        so that, if more complex formatting is needed than is provided by the
        displayStreamingLine() methods, then it can be used externally to format
        any required messages. The version of displayStreamingLine() with no
        arguments can then be called to print the contents of the buffer.

    ***************************************************************************/

    public StringBuffer msg;


    /**************************************************************************

        Set of components to show on the heading line.

    **************************************************************************/

    public enum HeadingLineComponents
    {
        /// Don't show any components
        None = 0,

        /// Show uptime info
        Uptime = 1,

        /// Show CPU info
        CpuUsage = 2,

        /// Show memory usage
        MemoryUsage = 4,

        /// Convenience value to show All
        All = MemoryUsage * 2 - 1,
    }


    /***************************************************************************

        Alias for system clock function.

    ***************************************************************************/

    private alias .clock system_clock;


    /***************************************************************************

        Convenience aliases for derived classes.

    ***************************************************************************/

    protected alias .TerminalOutput TerminalOutput;


    /**************************************************************************

        Number of columns in Terminal

    ***************************************************************************/

    private int terminal_columns;


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

        Output stream to output the streaming lines to. Can be null, in which
        case output will be disabled.

    ***************************************************************************/

    private OutputStream stream;


    /***************************************************************************

        TerminalOutput stream to output the static lines to. Can be null, in
        which case output will be disabled.

    ***************************************************************************/

    private TerminalOutput terminal_output;


    /**************************************************************************

        Indicator if the output is redirected. If so, no control characters
        will be output.

    ***************************************************************************/

    private bool is_redirected;


    /**************************************************************************

        Set of flags to show on the heading line of AppStatus.

    ***************************************************************************/

    private HeadingLineComponents heading_line_components;


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
            stream = stream to write the streaming output into. Can be null
                if it's not yet available (the streaming output will then be
                disabled).
            terminal_output = terminal to write the static output into. Can be
                null if it's not yet available (the static output will then be
                disabled).
            heading_line_components = components to show on the heading line
            terminal_columns = width of the terminal to assume. If zero, main
                terminal will be queried. Passing 0 will take the width from the
                current terminal (which must be present, otherwise no output will
                happen).

    ***************************************************************************/

    public this ( cstring app_name, cstring app_version, cstring app_build_date,
        cstring app_build_author, uint size, ulong ms_between_calls = 1000,
            OutputStream stream = Cout.stream, TerminalOutput terminal_output = Stdout,
            HeadingLineComponents heading_line_components = HeadingLineComponents.All,
            int terminal_columns = 80)
    {
        this.app_name.copy(app_name);
        this.app_version.copy(app_version);
        this.app_build_date.copy(app_build_date);
        this.app_build_author.copy(app_build_author);
        this.start_time = time(null);
        this.static_lines.length = size;
        this.static_lines_display_props.length = size;
        this.ms_between_calls = ms_between_calls;
        this.stream = stream;
        this.terminal_output = terminal_output;
        this.heading_line_components = heading_line_components;
        this.old_terminal_size = Terminal.rows;

        if (terminal_columns > 0)
        {
            this.terminal_columns = terminal_columns;
        }
        else
        {
            this.terminal_columns = Terminal.columns;
        }

        if (this.stream)
        {
            this.insert_console = new InsertConsole(this.stream, true,
                new LayoutMessageOnly);
        }

        this.msg = new StringBuffer;

        // Care only about stdout redirection
        if (stream == Cout.stream)
        {
            this.is_redirected = Cout.redirected;
        }
    }


    /***************************************************************************

        Connects output for AppStatus to output. Useful if the output
        doesn't exist during entire lifetime of AppStatus.

        stream = stream to write into
        terminal_output = terminal to write into.

    ***************************************************************************/

    public void connectOutput ( OutputStream stream, TerminalOutput terminal_output )
    {
        verify(stream !is null);
        verify(terminal_output !is null);

        this.stream = stream;
        this.terminal_output = terminal_output;
        if (this.insert_console is null)
            this.insert_console = new InsertConsole(this.stream, true,
                    new LayoutMessageOnly);
        this.insert_console.connectOutput(stream);
    }


    /***************************************************************************

        Disconnects output from the AppStatus to output. All subsequent display*
        methods will be no-op.

    ***************************************************************************/

    public void disconnectOutput ()
    {
        this.stream = null;
        this.terminal_output = null;
    }


    /**************************************************************************


        UnixSocketExt's handler which connects the connected socket to the
        registered AppStatus instance, displays static lines and waits until
        user disconnects. The optional parameter is the wanted terminal width
        to assume.

        Params:
            command = command used to call this handler
            write_line = delegate to write data to the socket
            read_line = delegate to read data from the socket
            socket = IODevice instance of the connected socket.

    **************************************************************************/

    public void connectedSocketHandler ( cstring[] command,
            scope void delegate (cstring) write_line,
            scope void delegate (ref mstring) read_line, IODevice socket )
    {
        static File unix_socket_file;
        static TerminalOutput unix_terminal_output;

        if (unix_socket_file is null)
        {
            unix_socket_file = new File;
            unix_terminal_output = new TerminalOutput(unix_socket_file);
        }

        unix_socket_file.setFileHandle(socket.fileHandle());
        this.connectOutput(unix_socket_file,
            unix_terminal_output);

        if (command.length > 0)
        {
            toInteger(command[0], this.terminal_columns);
        }

        scope (exit)
            this.disconnectOutput();

        this.displayStaticLines();

        // just wait for the user to disconnect
        static mstring buffer;
        buffer.length = 100;
        while (true)
        {
            read_line(buffer);
            if (buffer.length == 0)
                break;
        }
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
        if (this.terminal_output is null)
        {
            return;
        }

        // Add +2: One for header and one for footer
        for (size_t i = 0; i < this.static_lines.length + 2; i++)
        {
            this.terminal_output.clearline.newline;
        }

        // Each iteration in the previous loop moves the cursor one line to
        // the bottom. We need to return it to the right position again.
        // We can't combine both loops or we will be clearing and overwriting
        // the same first line over and over.
        for (size_t i = 0; i < this.static_lines.length + 2; i++)
        {
            this.terminal_output.up;
        }

        this.terminal_output.flush;
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

        if ( this.is_redirected || this.terminal_output is null )
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
            this.terminal_output.clearline.cr.flush.up;
        }
        else if ( this.static_lines.length < size )
        {
            // The number of static lines are being increased

            // First remove the static lines header
            this.terminal_output.clearline.cr.flush.up;

            // ...and then push up the streaming portion on the top by
            //        the new number of static lines
            //        + the static lines header
            //        + the static lines footer
            for ( auto i = 0; i < (size + 2); ++i )
            {
                this.terminal_output.formatln("");
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

        Print the current static lines set by the calling program to this.terminal_output
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
        if ( this.is_redirected || this.terminal_output is null)
        {
            return;
        }

        this.checkCursorPosition();

        foreach ( line; this.static_lines )
        {
            this.terminal_output.formatln("");
        }
        this.terminal_output.formatln("");

        this.printVersionInformation();
        this.terminal_output.clearline.cr.flush.up;

        foreach_reverse ( index, line; this.static_lines )
        {
            if ( line.length )
            {
                this.applyDisplayProps(this.static_lines_display_props[index]);

                this.terminal_output.format(this.truncateLength(line));
            }
            this.terminal_output.clearline.cr.flush.up;
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

    public typeof(this) formatStaticLine (T...) ( uint index, cstring format,
        T args )
    {
        verify(index < this.static_lines.length, "adding too many static lines" );

        this.static_lines[index].length = 0;
        enableStomping(this.static_lines[index]);
        sformat(this.static_lines[index], format, args);

        structConvert!(DisplayProperties)(
            this.current_display_props,
            this.static_lines_display_props[index]
        );

        return this;
    }


    /***************************************************************************

        Print a formatted streaming line above the static lines.

        Params:
            Args = Tuple of arguments to format
            format = format string of the streaming line
            args = Arguments for the streaming line

        Returns:
            this object for method chaining

    ***************************************************************************/

    public typeof(this) displayStreamingLine (Args...) ( cstring format, Args args )
    {
        this.msg.length = 0;
        sformat(&this.msg.sink, format, args);

        return this.displayStreamingLine();
    }


    /***************************************************************************

        Print the contents of this.msg as streaming line above the static lines.

        Returns:
            this object for method chaining

    ***************************************************************************/

    public typeof(this) displayStreamingLine () ( )
    {
        if (this.stream is null)
        {
            return this;
        }

        if ( this.is_redirected )
        {
            this.terminal_output.formatln("{}", this.msg[]).newline.flush;

            return this;
        }

        LogEvent event;
        event.set(ILogger.Context.init, ILogger.Level.init, this.msg[], "");

        this.applyDisplayProps(this.current_display_props);

        this.insert_console.append(event);

        return this;
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
        verify(_uptime < int.max && _uptime > int.min);
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
        static immutable float Mb = 1024 * 1024;
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
        enableStomping(this.heading_line);

        sformat(this.heading_line, "[{:d2}/{:d2}/{:d2} "
          ~ "{:d2}:{:d2}:{:d2}] {}", dt.date.day, dt.date.month, dt.date.year,
            dt.time.hours, dt.time.minutes, dt.time.seconds, this.app_name);

        if (this.heading_line_components & HeadingLineComponents.Uptime)
        {
            this.formatUptime();
        }

        if (this.heading_line_components & HeadingLineComponents.MemoryUsage)
        {
            this.formatMemoryUsage();
        }

        if (this.heading_line_components & HeadingLineComponents.CpuUsage)
        {
            this.formatCpuUsage();
        }

        this.terminal_output.default_colour.default_bg.bold(true)
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
            sformat(this.heading_line,
                " Memory: Used {}Mb/Free {}Mb", mem_allocated, mem_free);
        }
        else
        {
            sformat(this.heading_line, " Memory: n/a");
        }
    }


    /***************************************************************************

        Format the current uptime for the current program.

    ***************************************************************************/

    private void formatUptime ( )
    {
        uint weeks, days, hours, mins, secs;
        this.getUptime(weeks, days, hours, mins, secs);
        sformat(this.heading_line, " Uptime: {}w{:d1}d{:d2}:"
            ~ "{:d2}:{:d2}", weeks, days, hours, mins, secs);
    }


    /***************************************************************************

        Format the current cpu usage of this program.

    ***************************************************************************/

    private void formatCpuUsage ( )
    {
        long usage = 0;
        this.getCpuUsage(usage);
        sformat(this.heading_line, " CPU: {}%", usage);
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
        enableStomping(this.footer_line);

        sformat(this.footer_line, "Version {} built on {} by {}",
            this.app_version, this.app_build_date, this.app_build_author);

        this.terminal_output.default_colour.default_bg.bold(true)
            .format(this.truncateLength(this.footer_line)).bold(false);

        auto remaining = Terminal.columns - this.footer_line.length;
        if ( remaining )
        {
            this.footer_line.length = 0;
            enableStomping(this.footer_line);
            this.printExtraVersionInformation(this.terminal_output, this.footer_line,
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
        return this.truncateLength(buffer, this.terminal_columns);
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
        this.terminal_output.endrow;
        this.old_terminal_size = Terminal.rows;

        foreach ( line; this.static_lines )
        {
            this.terminal_output.clearline.cr.flush.up;
        }
        this.terminal_output.clearline.cr.flush.up;
    }


    /***************************************************************************

        Reset the content of all the static lines by setting the length to 0.

    ***************************************************************************/

    private void resetStaticLines ( )
    {
        foreach ( ref line; this.static_lines )
        {
            line.length = 0;
            enableStomping(line);
        }
    }


    /***************************************************************************

        Save the given foreground or background colour. This colour will be used
        when displaying the next streaming line or when formatting the next
        static line.

        Params:
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
                this.terminal_output.black();
                break;
            }

            case Terminal.Foreground.RED:
            {
                this.terminal_output.red();
                break;
            }

            case Terminal.Foreground.GREEN:
            {
                this.terminal_output.green();
                break;
            }

            case Terminal.Foreground.YELLOW:
            {
                this.terminal_output.yellow();
                break;
            }

            case Terminal.Foreground.BLUE:
            {
                this.terminal_output.blue();
                break;
            }

            case Terminal.Foreground.MAGENTA:
            {
                this.terminal_output.magenta();
                break;
            }

            case Terminal.Foreground.CYAN:
            {
                this.terminal_output.cyan();
                break;
            }

            case Terminal.Foreground.WHITE:
            {
                this.terminal_output.white();
                break;
            }

            case Terminal.Foreground.DEFAULT:
            default:
            {
                this.terminal_output.default_colour();
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
                this.terminal_output.black_bg();
                break;
            }

            case Terminal.Background.RED:
            {
                this.terminal_output.red_bg();
                break;
            }

            case Terminal.Background.GREEN:
            {
                this.terminal_output.green_bg();
                break;
            }

            case Terminal.Background.YELLOW:
            {
                this.terminal_output.yellow_bg();
                break;
            }

            case Terminal.Background.BLUE:
            {
                this.terminal_output.blue_bg();
                break;
            }

            case Terminal.Background.MAGENTA:
            {
                this.terminal_output.magenta_bg();
                break;
            }

            case Terminal.Background.CYAN:
            {
                this.terminal_output.cyan_bg();
                break;
            }

            case Terminal.Background.WHITE:
            {
                this.terminal_output.white_bg();
                break;
            }

            case Terminal.Background.DEFAULT:
            default:
            {
                this.terminal_output.default_bg();
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

        this.terminal_output.bold(display_props.is_bold);
    }
}

///
unittest
{
    void example ()
    {
        static immutable number_of_static_lines = 2;
        static immutable ms_between_calls = 1000;

        AppStatus app_status = new AppStatus("test",
            "revision", "build_date", "build_author",
            number_of_static_lines, ms_between_calls);

        ulong c1, c2, c3, c4, c5, c6;

        app_status.formatStaticLine(0, "{} count1, {} count2", c1, c2);
        app_status.formatStaticLine(1, "{} count3, {} count4", c3, c4);

        app_status.displayStaticLines();

        app_status.displayStreamingLine("{} count5, {} count6", c5, c6);

        // The colour and boldness of the static/streaming lines can be
        // controlled in the following manner:

        app_status.bold.red
            .formatStaticLine(0, "this static line will be in red and bold");
        app_status.bold(false).green
            .formatStaticLine(1, "and this one will be in green and not bold");

        app_status.blue.displayStreamingLine("here's a blue streaming line");
    }
}

unittest
{
    // tests if array stomping assertion triggers during line formatting

    auto number_of_static_lines = 2;

    AppStatus app_status = new AppStatus("test", "version",
        "build_date", "build_author", number_of_static_lines);

    ulong c1, c2, c3, c4;

    app_status.formatStaticLine(0, "{} count1, {} count2", c1, c2);
    app_status.formatStaticLine(0, "{} count1, {} count2", c1, c2);
    app_status.formatStaticLine(1, "{} count3, {} count4", c3, c4);
    app_status.formatStaticLine(1, "{} count3, {} count4", c3, c4);
}
