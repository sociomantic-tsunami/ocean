/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: April 2004

        Authors: Kris

*******************************************************************************/

module ocean.net.http.HttpParams;

import ocean.transition;

import ocean.time.Time;

import ocean.io.model.IConduit;

import ocean.net.http.HttpTokens;

import ocean.io.stream.Delimiters;

public  import ocean.net.http.model.HttpParamsView;

/******************************************************************************

        Maintains a set of query parameters, parsed from an HTTP request.
        Use HttpParams instead for output parameters.

        Note that these input params may have been encoded by the user-
        agent. Unfortunately there has been little consensus on what that
        encoding should be (especially regarding GET query-params). With
        luck, that will change to a consistent usage of UTF-8 within the
        near future.

******************************************************************************/

class HttpParams : HttpTokens, HttpParamsView
{
        // tell compiler to expose super.parse() also
        alias HttpTokens.parse parse;

        private Delimiters!(char) amp;

        /**********************************************************************

                Construct parameters by telling the HttpStack that
                name/value pairs are seperated by a '=' character.

        **********************************************************************/

        this ()
        {
                super ('=');

                // construct a line tokenizer for later usage
                amp = new Delimiters!(char) ("&");
        }

        /**********************************************************************

                Return the number of headers

        **********************************************************************/

        uint size ()
        {
                return super.stack.size;
        }

        /**********************************************************************

                Read all query parameters. Everything is mapped rather
                than being allocated & copied

        **********************************************************************/

        override void parse (InputBuffer input)
        {
                setParsed (true);
                amp.set (input);

                while (amp.next || amp.get.length)
                       stack.push (amp.get);
        }

        /**********************************************************************

                Add a name/value pair to the query list

        **********************************************************************/

        override void add (cstring name, cstring value)
        {
                super.add (name, value);
        }

        /**********************************************************************

                Add a name/integer pair to the query list

        **********************************************************************/

        override void addInt (cstring name, int value)
        {
                super.addInt (name, value);
        }


        /**********************************************************************

                Add a name/date(long) pair to the query list

        **********************************************************************/

        override void addDate (cstring name, Time value)
        {
                super.addDate (name, value);
        }

        /**********************************************************************

                Return the value of the provided header, or null if the
                header does not exist

        **********************************************************************/

        override cstring get (cstring name, cstring ret = null)
        {
                return super.get (name, ret);
        }

        /**********************************************************************

                Return the integer value of the provided header, or the
                provided default-value if the header does not exist

        **********************************************************************/

        override int getInt (cstring name, int ret = -1)
        {
                return super.getInt (name, ret);
        }

        /**********************************************************************

                Return the date value of the provided header, or the
                provided default-value if the header does not exist

        **********************************************************************/

        override Time getDate (cstring name, Time ret = Time.epoch)
        {
                return super.getDate (name, ret);
        }


        /**********************************************************************

                Output the param list to the provided consumer

        **********************************************************************/

        override void produce (size_t delegate(Const!(void)[]) consume, cstring eol=null)
        {
                return super.produce (consume, eol);
        }
}
