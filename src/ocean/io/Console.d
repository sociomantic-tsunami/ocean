/*******************************************************************************

    Copyright:
        Copyright (c) 2004 Kris Bell.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

    Version:
        Feb 2005: Initial release
        Nov 2005: Heavily revised for unicode
        Dec 2006: Outback release

    Authors: Kris

*******************************************************************************/

module ocean.io.Console;

import ocean.transition;

import ocean.sys.Common;

import ocean.io.device.Device,
       ocean.io.stream.Buffered;

version (Posix)
{
    import ocean.stdc.posix.unistd: isatty;
}

/*******************************************************************************

  Low-level console IO support.

  Note that for a while this was templated for each of char, wchar,
  and dchar. It became clear after some usage that the console is
  more useful if it sticks to UTF8 only. See Console.Conduit below
  for details.

  Redirecting the standard IO handles (via a shell) operates as one
  would expect, though the redirected content should likely restrict
  itself to UTF8.

*******************************************************************************/

struct Console
{
    const istring Eol = "\n";

    /**********************************************************************

      Model console input as a buffer. Note that we read UTF8
      only.

     **********************************************************************/

    class Input
    {
        private Bin     buffer;
        private bool    redirect;

        public alias    copyln get;

        /**************************************************************

          Attach console input to the provided device.

         **************************************************************/

        private this (Conduit conduit, bool redirected)
        {
            redirect = redirected;
            buffer = new Bin (conduit);
        }

        /**************************************************************

          Return the next line available from the console,
          or null when there is nothing available. The value
          returned is a duplicate of the buffer content (it
          has .dup applied).

          Each line ending is removed unless parameter raw is
          set to true.

         **************************************************************/

        final mstring copyln (bool raw = false)
        {
            cstring line;

            return readln (line, raw) ? line.dup : null;
        }

        /**************************************************************

          Retreive a line of text from the console and map
          it to the given argument. The input is sliced,
          not copied, so use .dup appropriately. Each line
          ending is removed unless parameter raw is set to
          true.

          Returns false when there is no more input.

         **************************************************************/

        final bool readln (out cstring content, bool raw=false)
        {
            size_t line (Const!(void)[] input)
            {
                auto text = cast(cstring) input;
                foreach (i, c; text)
                    if (c is '\n')
                    {
                        auto j = i;
                        if (raw)
                            ++j;
                        else
                            if (j && (text[j-1] is '\r'))
                                --j;
                        content = text [0 .. j];
                        return i+1;
                    }
                return IConduit.Eof;
            }

            // get next line, return true
            if (buffer.next (&line))
                return true;

            // assign trailing content and return false
            content = cast(cstring) buffer.slice (buffer.readable);
            return false;
        }

        /**************************************************************

          Return the associated stream.

         **************************************************************/

        final InputStream stream ()
        {
            return buffer;
        }

        /**************************************************************

          Is this device redirected?

          Returns:
          True if redirected, false otherwise.

          Remarks:
          Reflects the console redirection status from when
          this module was instantiated.

         **************************************************************/

        final bool redirected ()
        {
            return redirect;
        }

        /**************************************************************

          Set redirection state to the provided boolean.

          Remarks:
            Configure the console redirection status, where
            a redirected console is more efficient (dictates
            whether newline() performs automatic flushing or
            not.)

         **************************************************************/

        final Input redirected (bool yes)
        {
            redirect = yes;
            return this;
        }

        /**************************************************************

          Returns the configured source

          Remarks:
            Provides access to the underlying mechanism for
            console input. Use this to retain prior state
            when temporarily switching inputs.

         **************************************************************/

        final InputStream input ()
        {
            return buffer.input;
        }

        /**************************************************************

          Divert input to an alternate source.

         **************************************************************/

        final Input input (InputStream source)
        {
            buffer.input = source;
            return this;
        }
    }


    /**********************************************************************

      Console output accepts UTF8 only.

     **********************************************************************/

    class Output
    {
        private Bout    buffer;
        private bool    redirect;

        public  alias   append opCall;
        public  alias   flush  opCall;

        /**************************************************************

          Attach console output to the provided device.

         **************************************************************/

        private this (Conduit conduit, bool redirected)
        {
            redirect = redirected;
            buffer = new Bout (conduit);
        }

        /**************************************************************

          Append to the console. We accept UTF8 only, so
          all other encodings should be handled via some
          higher level API.

         **************************************************************/

        final Output append (cstring x)
        {
            buffer.append (x.ptr, x.length);
            return this;
        }

        /**************************************************************

          Append content.

          Params:
            other = An object with a useful toString() method.

          Returns:
            Returns a chaining reference if all content was
            written. Throws an IOException indicating Eof or
            Eob if not.

          Remarks:
            Append the result of other.toString() to the console.

         **************************************************************/

        final Output append (Object other)
        {
            return append (other.toString);
        }

        /**************************************************************

          Append a newline and flush the console buffer. If
          the output is redirected, flushing does not occur
          automatically.

          Returns:
            Returns a chaining reference if content was written.
            Throws an IOException indicating Eof or Eob if not.

          Remarks:
            Emit a newline into the buffer, and autoflush the
            current buffer content for an interactive console.
            Redirected consoles do not flush automatically on
            a newline.

         **************************************************************/

        final Output newline ()
        {
            buffer.append (Eol);
            if (redirect is false)
                buffer.flush;

            return this;
        }

        /**************************************************************

          Explicitly flush console output.

          Returns:
            Returns a chaining reference if content was written.
            Throws an IOException indicating Eof or Eob if not.

          Remarks:
            Flushes the console buffer to attached conduit.

         **************************************************************/

        final Output flush ()
        {
            buffer.flush;
            return this;
        }

        /**************************************************************

          Return the associated stream.

         **************************************************************/

        final OutputStream stream ()
        {
            return buffer;
        }

        /**************************************************************

          Is this device redirected?

          Returns:
            True if redirected, false otherwise.

          Remarks:
            Reflects the console redirection status.

         **************************************************************/

        final bool redirected ()
        {
            return redirect;
        }

        /**************************************************************

          Set redirection state to the provided boolean.

          Remarks:
            Configure the console redirection status, where
            a redirected console is more efficient (dictates
            whether newline() performs automatic flushing or
            not.)

         **************************************************************/

        final Output redirected (bool yes)
        {
            redirect = yes;
            return this;
        }

        /**************************************************************

          Returns the configured output sink.

          Remarks:
            Provides access to the underlying mechanism for
            console output. Use this to retain prior state
            when temporarily switching outputs.

         **************************************************************/

        final OutputStream output ()
        {
            return buffer.output;
        }

        /**************************************************************

          Divert output to an alternate sink.

         **************************************************************/

        final Output output (OutputStream sink)
        {
            buffer.output = sink;
            return this;
        }
    }


    /***********************************************************************

      Conduit for specifically handling the console devices. It used to have
      special implementation for Win32 but it was removed as unmaintained
      during D2 transition.

     ***********************************************************************/

    class Conduit : Device
    {
        private bool redirected = false;

        /***********************************************************************

          Return the name of this conduit.

         ***********************************************************************/

        override istring toString()
        {
            return "<console>";
        }

        /*******************************************************

          Associate this device with a given handle.

          This is strictly for adapting existing
          devices such as Stdout and friends.

         *******************************************************/

        private this (int handle)
        {
            this.handle = cast(Handle) handle;
            redirected = (isatty(handle) is 0);
        }
    }
}


/******************************************************************************

  Globals representing Console IO.

 ******************************************************************************/

mixin (global("Console.Input  Cin"));  /// The standard input stream.
mixin (global("Console.Output Cout")); /// The standard output stream.
mixin (global("Console.Output Cerr")); /// The standard error stream.


/******************************************************************************

  Instantiate Console access.

 ******************************************************************************/

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

void constructor()
{
    auto conduit = new Console.Conduit (0);
    Cin  = new Console.Input (conduit, conduit.redirected);

    conduit = new Console.Conduit (1);
    Cout = new Console.Output (conduit, conduit.redirected);

    conduit = new Console.Conduit (2);
    Cerr = new Console.Output (conduit, conduit.redirected);
}

/******************************************************************************

  Flush outputs before we exit.

  (Good idea from Frits Van Bommel.)

 ******************************************************************************/

static ~this()
{
    Cout.flush;
    Cerr.flush;
}


/******************************************************************************

 ******************************************************************************/

debug (Console)
{
    void main()
    {
        Cout ("hello world").newline;
    }
}
