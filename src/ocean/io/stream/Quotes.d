/*******************************************************************************

        Copyright:
            Copyright (c) 2006 Tango contributors.
            Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Jan 2006: initial release

        Authors: Kris, Nthalk

*******************************************************************************/

module ocean.io.stream.Quotes;

import ocean.meta.types.Qualifiers;

import ocean.io.stream.Iterator;

version (unittest) import ocean.core.Test;

/*******************************************************************************

        Iterate over a set of delimited, optionally-quoted, text fields.

        Each field is exposed to the client as a slice of the original
        content, where the slice is transient. If you need to retain the
        exposed content, then you should .dup it appropriately.

        The content exposed via an iterator is supposed to be entirely
        read-only. All current iterators abide by this rule, but it is
        possible a user could mutate the content through a get() slice.
        To enforce the desired read-only aspect, the code would have to
        introduce redundant copying or the compiler would have to support
        read-only arrays.

        Usage:
        ---
        auto f = new File ("my.csv");
        auto l = new Lines (f);
        auto b = new Array (0);
        auto q = new Quotes(",", b);

        foreach (line; l)
                {
                b.assign (line);
                foreach (field, index; q)
                         Stdout (index, field);
                Stdout.newline;
                }
        ---

        See Iterator, Lines, Patterns, Delimiters.

*******************************************************************************/

class Quotes : Iterator
{
        private cstring delim;

        /***********************************************************************

                This splits on delimiters only. If there is a quote, it
                suspends delimiter splitting until the quote is finished.

        ***********************************************************************/

        this (cstring delim, InputStream stream = null)
        {
                super (stream);
                this.delim = delim;
        }

        /***********************************************************************

                This splits on delimiters only. If there is a quote, it
                suspends delimiter splitting until the quote is finished.

        ***********************************************************************/

        protected override
        size_t scan (const(void)[] data)
        {
                char quote = 0;
                int  escape = 0;
                auto content = (cast(const(char)*) data.ptr) [0 .. data.length];

                foreach (i, c; content)
                         // within a quote block?
                         if (quote)
                            {
                            if (c is '\\')
                                ++escape;
                            else
                               {
                               // matched the initial quote char?
                               if (c is quote && escape % 2 is 0)
                                   quote = 0;
                               escape = 0;
                               }
                            }
                         else
                            // begin a quote block?
                            if (c is '"' || c is '\'')
                                quote = c;
                            else
                               if (has (delim, c))
                                   return found (set (content.ptr, 0, i));
                return notFound;
        }
}


/*******************************************************************************

    Unittests

*******************************************************************************/

version (unittest)
{
    import ocean.io.device.Array;
    import ocean.text.Util;
}

unittest
{
    istring[] expected = [
        `0`
        ,``
        ,``
        ,`"3"`
        ,`""`
        ,`5`
        ,`",6"`
        ,`"7,"`
        ,`8`
        ,`"9,\\\","`
        ,`10`
        ,`',11",'`
        ,`"12"`
    ];

    auto b = new Array (expected.join (",").dup);
    foreach (i, f; new Quotes(",", b))
    {
        test (i < expected.length, "uhoh: unexpected match");
        test (f == expected[i], "uhoh: bad match)");
    }
}
