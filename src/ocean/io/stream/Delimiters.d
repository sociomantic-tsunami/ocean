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

module ocean.io.stream.Delimiters;

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

        See Lines, Patterns, Quotes.

*******************************************************************************/

class Delimiters(T) : Iterator!(T)
{
        private Const!(T)[] delim;

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

        this (Const!(T)[] delim, InputStream stream = null)
        {
                this.delim = delim;
                super (stream);
        }

        /***********************************************************************

        ***********************************************************************/

        protected override size_t scan (Const!(void)[] data)
        {
                auto content = (cast(T*) data.ptr) [0 .. data.length / T.sizeof];

                if (delim.length is 1)
                   {
                   foreach (int i, T c; content)
                            if (c is delim[0])
                                return found (set (content.ptr, 0, i, i));
                   }
                else
                   foreach (int i, T c; content)
                            if (has (delim, c))
                                return found (set (content.ptr, 0, i, i));

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
    auto p = new Delimiters!(char) (", ", new Array("blah".dup));
}
