/*******************************************************************************

    HTTP Cookie Generator

    Reference:      RFC 2109

                    @see http://www.w3.org/Protocols/rfc2109/rfc2109.txt
                    @see http://www.servlets.com/rfcs/rfc2109.html

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.net.http.cookie.HttpCookieGenerator;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.transition;

import ocean.net.util.ParamSet;

import ocean.net.http.consts.CookieAttributeNames;

import ocean.net.http.time.HttpTimeFormatter;

import core.stdc.time: time_t;

/******************************************************************************/

class HttpCookieGenerator : ParamSet
{
    /**************************************************************************

        Cookie ID

     **************************************************************************/

    public istring id;

    /**************************************************************************

        Cookie domain and path

     **************************************************************************/

    public cstring domain, path;

    /**************************************************************************

        Expiration time manager

     **************************************************************************/

    private static class ExpirationTime
    {
        /**********************************************************************

            Expiration time if set.

         **********************************************************************/

        private time_t t;

        /**********************************************************************

            true if the expiration time is currently defined or false otherwise.

         **********************************************************************/

        private bool is_set_ = false;

        /**********************************************************************

            Sets the expiration time.

            Params:
                t = expiration time

            Returns:
                t

            In:
                t must be at least 0.

         **********************************************************************/

        public time_t opAssign ( time_t t )
        in
        {
            assert (t >= 0, "negative time value");
        }
        body
        {
            this.is_set_ = true;
            return this.t = t;
        }

        /**********************************************************************

            Marks the expiration time as "not set".

         **********************************************************************/

        public void clear ( )
        {
            this.is_set_ = false;
        }

        /**********************************************************************

            Returns:
                true if the expiration time is currently defined or false
                otherwise.

         **********************************************************************/

        public bool is_set ( )
        {
            return this.is_set_;
        }

        /**********************************************************************

            Obtains the expiration time.

            Params:
                t = destination variable, will be set to the expiration time if
                    and only if an expiration time is currently defined.

            Returns:
                true if an expiration time is currently defined and t has been
                set to it or false otherwise.

         **********************************************************************/

        public bool get ( ref time_t t )
        {
            if (this.is_set_)
            {
                t = this.t;
            }

            return this.is_set_;
        }
    }

    /**************************************************************************

        Expiration time manager with string formatter

     **************************************************************************/

    private static class FormatExpirationTime : ExpirationTime
    {
        /**********************************************************************

            String formatter

         **********************************************************************/

        private HttpTimeFormatter formatter;

        /**********************************************************************

            Returns:
                current expiration time as HTTP time string or null if currently
                no expiration time is defined.

         **********************************************************************/

        public mstring format ( )
        {
            return super.is_set_? this.formatter.format(super.t) : null;
        }
    }

    /**************************************************************************

        Expiration time manager instance

     **************************************************************************/

    public  ExpirationTime       expiration_time;

    /**************************************************************************

        Expiration time manager/formatter instance

     **************************************************************************/

    private FormatExpirationTime fmt_expiration_time;

    /**************************************************************************

        Constructor

        Params:
            id              = cookie ID
            attribute_names = cookie attribute names

        Note:
            This constructor takes a reference to id and use it internally,
            hence 'id' must remain valid for the lifetime of this object.

     **************************************************************************/

    this ( istring id, istring[] attribute_names ... )
    {
        super.addKeys(this.id = id);

        super.addKeys(attribute_names);

        super.rehash();

        this.expiration_time = this.fmt_expiration_time = new FormatExpirationTime;
    }


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Called immediately when this instance is deleted.
            (Must be protected to prevent an invariant from failing.)

        ***********************************************************************/

        protected override void dispose ( )
        {
            delete this.fmt_expiration_time;
        }
    }

    /**************************************************************************

        Sets the cookie value.

        Params:
            val = cookie value string

        Returns:
            cookie value

     **************************************************************************/

    cstring value ( cstring val )
    {
        return super[this.id] = val;
    }

    /**************************************************************************

        Returns:
            the current cookie value

     **************************************************************************/

    cstring value ( )
    {
        return super[this.id];
    }

    /**************************************************************************

        Renders the HTTP response Cookie header line field value.

        Params:
            appendContent = callback delegate that will be invoked repeatedly
            to concatenate the Cookie header line field value.

     **************************************************************************/

    void render ( void delegate ( cstring str ) appendContent )
    {
        uint i = 0;

        void append ( cstring key, cstring val )
        {
            if (val)
            {
                if (i++)
                {
                    appendContent("; ");
                }

                appendContent(key);
                appendContent("=");
                appendContent(val);
            }
        }

        foreach (key, val; super)
        {
            append(key, val);
        }

        append(CookieAttributeNames.Names.Domain,  this.domain);
        append(CookieAttributeNames.Names.Path,    this.path);
        append(CookieAttributeNames.Names.Expires, this.fmt_expiration_time.format());
    }

    /**************************************************************************

        Clears the expiration time.

     **************************************************************************/

    public override void reset ( )
    {
        super.reset();

        this.expiration_time.clear();
    }
}
