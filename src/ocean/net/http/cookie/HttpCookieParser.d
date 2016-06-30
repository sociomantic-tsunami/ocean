/*******************************************************************************

    Http Session "Cookie" Structure

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

module ocean.net.http.cookie.HttpCookieParser;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.transition;
import ocean.net.util.QueryParams: QueryParamSet;

/******************************************************************************/

class HttpCookieParser : QueryParamSet
{
    this ( in istring[] cookie_names ... )
    {
        super(';', '=', cookie_names);
    }
}

/******************************************************************************/

unittest
{
    const istring cookie_header_value = "test=2649113645; test-value=1383922851";

    const istring[] cookie_names =
    [
        "test",
        "test-value"
    ];

    scope cookie = new HttpCookieParser(cookie_names);

    cookie.parse(cookie_header_value);

    assert (cookie["test"] == "2649113645");
    assert (cookie["test-value"] == "1383922851");
}
