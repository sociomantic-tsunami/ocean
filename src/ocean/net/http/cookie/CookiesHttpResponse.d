/******************************************************************************

    HTTP response message generator with support for cookies

    Takes a list of HttpCookieGenerator instances in the constructor. When
    rendering the response by CookiesHttpResponse.render(), a Set-Cookie header
    line will be added for each HttpCookieGenerator instance a cookie value is
    assigned to.
    CookiesHttpResponse.reset() calls reset() on all cookies.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.net.http.cookie.CookiesHttpResponse;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.net.http.HttpResponse;
import ocean.net.http.cookie.HttpCookieGenerator;
import ocean.net.http.consts.HeaderFieldNames;

/******************************************************************************/

class CookiesHttpResponse : HttpResponse
{
    /**************************************************************************

        List of cookies. render() adds a Set-Cookie header line will for each
        cookie to which a value was assigned to after the last reset().

     **************************************************************************/

    public HttpCookieGenerator[] cookies;

    /**************************************************************************

        Constructor

        Params:
            cookies = cookies to use

     **************************************************************************/

    public this ( HttpCookieGenerator[] cookies ... )
    out
    {
        foreach (cookie; this.cookies)
        {
            assert (cookie !is null, "null cookie instance");
        }
    }
    body
    {
        this.cookies = cookies.dup; // No .dup caused segfaults, apparently the
                                    // array is then sliced.
        super.addKey(HeaderFieldNames.ResponseNames.SetCookie);
    }

    version (D_Version2) {}
    else
    {
        /**********************************************************************

            Called immediately when this instance is deleted.
            (Must be protected to prevent an invariant from failing.)

        ***********************************************************************/

        protected override void dispose ( )
        {
            super.dispose();

            foreach (ref cookie; this.cookies)
            {
                delete cookie;

                cookie = null;
            }

            delete this.cookies;
        }
    }


    /**************************************************************************

        Called by render() when the Set-Cookie header lines should be appended.

        Params:
            append = header line appender

     **************************************************************************/

    protected override void addHeaders ( AppendHeaderLines append )
    {
        foreach (cookie; this.cookies) if (cookie.value)
        {
            scope append_line = append.new IncrementalValue("Set-Cookie");

            cookie.render(&append_line.appendToValue);
        }
    }

    /**************************************************************************

        Called by reset(), resets the cookies.

     **************************************************************************/

    public override void reset ( )
    {
        super.reset();

        foreach (cookie; this.cookies)
        {
            cookie.reset();
        }
    }
}
