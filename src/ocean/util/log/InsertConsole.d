/*******************************************************************************

    InsertConsole

    An appender for the tango logger which writes the output _above_ the
    current cursor position, breaking the line automatically.

    This appender was developed in order to allow applications using
    ocean.io.console.AppStatus to split the output console to send logs to the
    top streaming portion without affecting the bottom static portion. For more
    details, please refer to the documentation in the AppStatus module.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.log.InsertConsole;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.io.Terminal;

import ocean.io.Console;

import Integer = ocean.text.convert.Integer_tango;

import ocean.io.model.IConduit;
import ocean.util.log.Appender;
import ocean.util.log.Event;

import ocean.stdc.posix.signal;


/*******************************************************************************

    An appender for the tango logger which writes the output _above_ the
    current cursor position, breaking the line automatically

    This was copied from ocean.util.log.AppendConsole and modified

*******************************************************************************/

public class InsertConsole: Appender
{
    private Mask mask_;
    private bool flush_;
    private OutputStream stream_;

    private char[] buffer;

    /***********************************************************************

     Create with the given layout

     ***********************************************************************/

    this ( Appender.Layout how = null )
    {
        this(Cerr.stream, true, how);
    }

    /***********************************************************************

     Create with the given stream and layout

     ***********************************************************************/

    this ( OutputStream stream, bool flush = false, Appender.Layout how = null )
    {
        assert (stream);

        mask_ = register(name ~ stream.classinfo.name);
        stream_ = stream;
        flush_ = flush;
        layout(how);

        this.buffer = new char[Terminal.columns];
        this.buffer[] = '\0';
    }

    /***********************************************************************

     Return the fingerprint for this class

     ***********************************************************************/

    final override Mask mask ( )
    {
        return mask_;
    }

    /***********************************************************************

     Return the name of this class

     ***********************************************************************/

    override cstring name ( )
    {
        return this.classinfo.name;
    }

    /***********************************************************************

     Append an event to the output.

     ***********************************************************************/

    final override void append ( LogEvent event )
    {
        // attempt to format output for non-existing terminal will cause
        // an infinite loop
        if (!Terminal.columns)
            return;

        if (this.buffer.length != Terminal.columns)
        {
            this.buffer.length = Terminal.columns;
            buffer[] = '\0';
        }

        ushort pos = 0;

        const istring Eol = "\n";

        with ( Terminal )
        {
            layout.format(
              event,
              ( Const!(void)[] content )
              {
                  size_t written;
                  while (pos + content.length > buffer.length)
                  {
                      buffer[pos .. $] = cast(char[]) content[0 .. buffer.length - pos];

                      written += stream_.write(CSI);
                      written += stream_.write(LINE_UP);

                      written += stream_.write(CSI);
                      written += stream_.write(SCROLL_UP);

                      written += stream_.write(CSI);
                      written += stream_.write(INSERT_LINE);

                      written += stream_.write(buffer);

                      stream_.write(Eol);
                      stream_.flush;
                      buffer[] = '\0';
                      content = content[buffer.length - pos .. $];

                      pos = 0;
                  }

                  if (content.length > 0)
                  {
                      buffer[pos .. pos + content.length] = cast(char[]) content[];
                      pos += content.length;
                  }

                  return written;
              } );

            stream_.write(CSI);
            stream_.write(LINE_UP);

            stream_.write(CSI);
            stream_.write(SCROLL_UP);

            stream_.write(CSI);
            stream_.write(INSERT_LINE);

            stream_.write(buffer);
            stream_.flush;

            pos = 0;
            buffer[] = '\0';

            stream_.write(Eol);

            if (flush_) stream_.flush;
        }
    }
}
