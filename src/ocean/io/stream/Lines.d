/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: January 2006

        Authors: Kris

*******************************************************************************/

module ocean.io.stream.Lines;

import ocean.meta.types.Qualifiers;

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

class Lines : Iterator
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

        final bool readln (ref cstring content)
        {
                content = super.next;
                return content.ptr !is null;
        }

        /***********************************************************************

                Scanner implementation for this iterator. Find a '\n',
                and eat any immediately preceeding '\r'.

        ***********************************************************************/

        protected override size_t scan (const(void)[] data)
        {
                auto content = (cast(const(char)*) data.ptr) [0 .. data.length];

                foreach (i, c; content)
                         if (c is '\n')
                            {
                            size_t slice = i;
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

version (unittest)
{
    import ocean.io.device.Array;
}

unittest
{
    auto p = new Lines(new Array("blah".dup));
}
