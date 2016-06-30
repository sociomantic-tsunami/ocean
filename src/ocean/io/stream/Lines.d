/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: January 2006

        Authors: Kris

*******************************************************************************/

module ocean.io.stream.Lines;

import ocean.transition;

import ocean.io.stream.Iterator;

/*******************************************************************************

        Iterate across a set of text patterns.

        Each pattern is exposed to the client as a slice of the original
        content, where the slice is transient. If you need to retain the
        exposed content, then you should .dup it appropriately.

        The content exposed via an iterator is supposed to be entirely
        read-only. All current iterators abide by this rule, but it is
        possible a user could mutate the content through a get() slice.
        To enforce the desired read-only aspect, the code would have to
        introduce redundant copying or the compiler would have to support
        read-only arrays.

        See Delimiters, Patterns, Quotes.

*******************************************************************************/

class Lines(T) : Iterator!(T)
{
        /***********************************************************************

                Construct an uninitialized iterator. For example:
                ---
                auto lines = new Lines!(char);

                void somefunc (InputStream stream)
                {
                        foreach (line; lines.set(stream))
                                 Cout (line).newline;
                }
                ---

                Construct a streaming iterator upon a stream:
                ---
                void somefunc (InputStream stream)
                {
                        foreach (line; new Lines!(char) (stream))
                                 Cout (line).newline;
                }
                ---

                Construct a streaming iterator upon a conduit:
                ---
                foreach (line; new Lines!(char) (new File ("myfile")))
                         Cout (line).newline;
                ---

        ***********************************************************************/

        this (InputStream stream = null)
        {
                super (stream);
        }

        /***********************************************************************

                Read a line of text, and return false when there's no
                further content available.

        ***********************************************************************/

        final bool readln (ref Const!(T)[] content)
        {
                content = super.next;
                return content.ptr !is null;
        }

        /***********************************************************************

                Scanner implementation for this iterator. Find a '\n',
                and eat any immediately preceeding '\r'.

        ***********************************************************************/

        protected override size_t scan (Const!(void)[] data)
        {
                auto content = (cast(T*) data.ptr) [0 .. data.length / T.sizeof];

                foreach (int i, T c; content)
                         if (c is '\n')
                            {
                            int slice = i;
                            if (i && content[i-1] is '\r')
                                --slice;
                            set (content.ptr, 0, slice, i);
                            return found (i);
                            }

                return notFound;
        }
}



/*******************************************************************************

*******************************************************************************/

version (UnitTest)
{
    import ocean.io.device.Array;
}

unittest
{
    auto p = new Lines!(char) (new Array("blah".dup));
}

/*******************************************************************************

*******************************************************************************/

debug (Lines)
{
        import ocean.io.Console;
        import ocean.io.device.Array;

        void main()
        {
                auto lines = new Lines!(char)(new Array("one\ntwo\r\nthree"));
                foreach (i, line, delim; lines)
                         Cout (line) (delim);
        }
}
