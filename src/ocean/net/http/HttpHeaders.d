/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: April 2004

        Authors: Kris

*******************************************************************************/

module ocean.net.http.HttpHeaders;

import ocean.transition;

import ocean.time.Time;

import ocean.io.stream.Lines;

import ocean.io.model.IConduit;

public  import ocean.net.http.HttpConst;

import ocean.net.http.HttpTokens;

/******************************************************************************

        Exposes reachable HttpHeader instances

******************************************************************************/

struct HeaderElement
{
        HttpHeaderName  name;
        cstring         value;
}

/******************************************************************************

        Maintains a set of input headers. These are placed into an input
        buffer and indexed via a HttpStack.

******************************************************************************/

class HttpHeadersView : HttpTokens
{
        // tell compiler to used super.parse() also
        alias HttpTokens.parse parse;

        private Lines        line;
        private bool         preserve;

        /**********************************************************************

                Construct this set of headers, using a HttpStack based
                upon a ':' delimiter

        **********************************************************************/

        this ()
        {
                // separator is a ':', and specify we want it included as
                // part of the name whilst iterating
                super (':', true);

                // construct a line tokenizer for later usage
                line = new Lines;
        }

        /**********************************************************************

                Clone a source set of HttpHeaders

        **********************************************************************/

        this (HttpHeadersView source)
        {
                super (source);
                this.preserve = source.preserve;
        }

        /**********************************************************************

                Clone this set of HttpHeadersView

        **********************************************************************/

        HttpHeadersView clone ()
        {
                return new HttpHeadersView (this);
        }

        /***********************************************************************

                Control whether headers are duplicated or not. Default
                behaviour is aliasing instead of copying, avoiding any
                allocation overhead. However, the default won't preserve
                those headers once additional content has been read.

                To retain headers across arbitrary buffering, you should
                set this option to true

        ***********************************************************************/

        HttpHeadersView retain (bool yes = true)
        {
                preserve = yes;
                return this;
        }

        /**********************************************************************

                Read all header lines. Everything is mapped rather
                than being allocated & copied

        **********************************************************************/

        override void parse (InputBuffer input)
        {
                setParsed (true);
                line.set (input);

                while (line.next && line.get.length)
                       stack.push (preserve ? line.get.dup : line.get);
        }

        /**********************************************************************

                Return the value of the provided header, or null if the
                header does not exist

        **********************************************************************/

        cstring get (HttpHeaderName name, cstring def = null)
        {
                return super.get (name.value, def);
        }

        /**********************************************************************

                Return the integer value of the provided header, or -1
                if the header does not exist

        **********************************************************************/

        int getInt (HttpHeaderName name, int def = -1)
        {
                return super.getInt (name.value, def);
        }

        /**********************************************************************

                Return the date value of the provided header, or Time.epoch
                if the header does not exist

        **********************************************************************/

        Time getDate (HttpHeaderName name, Time def = Time.epoch)
        {
                return super.getDate (name.value, def);
        }

        /**********************************************************************

                Iterate over the set of headers. This is a shell around
                the superclass, where we can convert the HttpToken into
                a HeaderElement instead.

        **********************************************************************/

        int opApply (int delegate(ref HeaderElement) dg)
        {
                HeaderElement   element;
                int             result = 0;

                foreach (HttpToken token; super)
                        {
                        element.name.value = token.name;
                        element.value = token.value;
                        result = dg (element);
                        if (result)
                            break;
                        }
                return result;
        }

        /**********************************************************************

                Create a filter for iterating of a set of named headers.
                We have to create a filter since we can't pass additional
                arguments directly to an opApply() method.

        **********************************************************************/

        FilteredHeaders createFilter (HttpHeaderName header)
        {
                return new FilteredHeaders (this, header);
        }

        /**********************************************************************

                Filter class for isolating a set of named headers.

        **********************************************************************/

        private static class FilteredHeaders : FilteredTokens
        {
                /**************************************************************

                        Construct a filter upon the specified headers, for
                        the given header name.

                **************************************************************/

                this (HttpHeadersView headers, HttpHeaderName header)
                {
                        super (headers, header.value);
                }

                /**************************************************************

                        Iterate over all headers matching the given name.
                        This wraps the HttpToken iterator to convert the
                        output into a HeaderElement instead.

                **************************************************************/

                int opApply (int delegate(ref HeaderElement) dg)
                {
                        HeaderElement   element;
                        int             result = 0;

                        foreach (HttpToken token; super)
                                {
                                element.name.value = token.name;
                                element.value = token.value;
                                result = dg (element);
                                if (result)
                                    break;
                                }
                        return result;
                }

        }
}


/******************************************************************************

        Maintains a set of output headers. These are held in an output
        buffer, and indexed via a HttpStack. Deleting a header could be
        supported by setting the HttpStack entry to null, and ignoring
        such values when it's time to write the headers.

******************************************************************************/

class HttpHeaders : HttpHeadersView
{
        /**********************************************************************

                Construct output headers

        **********************************************************************/

        this ()
        {
        }

        /**********************************************************************

                Clone a source set of HttpHeaders

        **********************************************************************/

        this (HttpHeaders source)
        {
                super (source);
        }

        /**********************************************************************

                Clone this set of HttpHeaders

        **********************************************************************/

        override HttpHeaders clone ()
        {
                return new HttpHeaders (this);
        }

        /**********************************************************************

                Add the specified header, and use a callback to provide
                the content.

        **********************************************************************/

        void add (HttpHeaderName name, void delegate(OutputBuffer) dg)
        {
                super.add (name.value, dg);
        }

        /**********************************************************************

                Add the specified header and text

        **********************************************************************/

        void add (HttpHeaderName name, cstring value)
        {
                super.add (name.value, value);
        }

        /**********************************************************************

                Add the specified header and integer value

        **********************************************************************/

        void addInt (HttpHeaderName name, int value)
        {
                super.addInt (name.value, value);
        }

        /**********************************************************************

                Add the specified header and long/date value

        **********************************************************************/

        void addDate (HttpHeaderName name, Time value)
        {
                super.addDate (name.value, value);
        }

        /**********************************************************************

                Remove the specified header header. Returns false if not
                found.

        **********************************************************************/

        bool remove (HttpHeaderName name)
        {
                return super.remove (name.value);
        }
}
